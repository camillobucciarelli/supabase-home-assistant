#!/usr/bin/env bash
set -Eeuo pipefail

OPTIONS_FILE="/data/options.json"
WORK_DIR="/data/supabase"
SOURCE_DIR="${WORK_DIR}/source"
PROJECT_DIR="${WORK_DIR}/project"
ENV_FILE="${PROJECT_DIR}/.env"
COMPOSE_PROJECT_NAME="ha-supabase"

log() {
  echo "[supabase-addon] $*"
}

option() {
  jq -r --arg key "$1" '.[$key] // empty' "${OPTIONS_FILE}"
}

env_value() {
  local key="${1}"

  if [[ ! -f "${ENV_FILE}" ]]; then
    return
  fi

  awk -F= -v key="${key}" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "${ENV_FILE}"
}

env_has_value() {
  local key="${1}"
  local value

  value="$(env_value "${key}")"
  [[ -n "${value}" ]]
}

random_alnum() {
  local length="${1}"
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${length}"
}

set_env() {
  local key="${1}"
  local value="${2}"
  local tmp_file
  tmp_file="$(mktemp)"

  awk -v key="${key}" -v value="${value}" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (done == 0) {
        print key "=" value
      }
    }
  ' "${ENV_FILE}" >"${tmp_file}"

  mv "${tmp_file}" "${ENV_FILE}"
}

detect_docker_socket() {
  local docker_host_path

  if [[ "${DOCKER_HOST:-}" == unix://* ]]; then
    docker_host_path="${DOCKER_HOST#unix://}"
    if [[ -S "${docker_host_path}" ]]; then
      echo "${docker_host_path}"
      return
    fi
  fi

  for socket_path in /var/run/docker.sock /run/docker.sock; do
    if [[ -S "${socket_path}" ]]; then
      echo "${socket_path}"
      return
    fi
  done
}

configure_docker_client() {
  local docker_socket="${1}"

  export DOCKER_HOST="unix://${docker_socket}"
  docker info >/dev/null
}

current_container_id() {
  local container_id container_hostname container_name expected_name

  if docker inspect "${HOSTNAME}" >/dev/null 2>&1; then
    echo "${HOSTNAME}"
    return
  fi

  expected_name="addon_${HOSTNAME//-/_}"

  while IFS= read -r container_id; do
    [[ -n "${container_id}" ]] || continue

    container_hostname="$(docker inspect "${container_id}" --format '{{.Config.Hostname}}' 2>/dev/null || true)"
    container_name="$(docker inspect "${container_id}" --format '{{.Name}}' 2>/dev/null || true)"
    container_name="${container_name#/}"

    if [[ "${container_hostname}" == "${HOSTNAME}" ]] || [[ "${container_name}" == "${expected_name}" ]]; then
      echo "${container_id}"
      return
    fi
  done < <(docker ps -aq)
}

host_data_dir() {
  local container_id="${1}"

  docker inspect "${container_id}" \
    --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}'
}

host_mount_source() {
  local destination="${1}"
  local container_id="${2}"

  docker inspect "${container_id}" \
    --format "{{range .Mounts}}{{if eq .Destination \"${destination}\"}}{{.Source}}{{end}}{{end}}"
}

install_supabase_files() {
  local supabase_ref="${1}"

  mkdir -p "${WORK_DIR}"

  if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
    log "Supabase project already exists at ${PROJECT_DIR}"
    return
  fi

  log "Fetching Supabase docker configuration from ref '${supabase_ref}'"
  rm -rf "${SOURCE_DIR}" "${PROJECT_DIR}"
  mkdir -p "${SOURCE_DIR}" "${PROJECT_DIR}"

  git -C "${SOURCE_DIR}" init
  git -C "${SOURCE_DIR}" remote add origin https://github.com/supabase/supabase.git
  git -C "${SOURCE_DIR}" sparse-checkout init --cone
  git -C "${SOURCE_DIR}" sparse-checkout set docker
  git -C "${SOURCE_DIR}" fetch --depth 1 origin "${supabase_ref}"
  git -C "${SOURCE_DIR}" checkout --detach FETCH_HEAD

  cp -R "${SOURCE_DIR}/docker/." "${PROJECT_DIR}/"
  cp "${SOURCE_DIR}/docker/.env.example" "${ENV_FILE}"

  log "Generating Supabase secrets"
  (cd "${PROJECT_DIR}" && sh utils/generate-keys.sh)
  ensure_new_auth_keys
}

ensure_new_auth_keys() {
  local missing_keys=false

  for key in SUPABASE_PUBLISHABLE_KEY SUPABASE_SECRET_KEY ANON_KEY_ASYMMETRIC SERVICE_ROLE_KEY_ASYMMETRIC JWT_KEYS JWT_JWKS; do
    if ! env_has_value "${key}"; then
      missing_keys=true
      break
    fi
  done

  if [[ "${missing_keys}" != "true" ]]; then
    return
  fi

  if [[ ! -x "${PROJECT_DIR}/utils/add-new-auth-keys.sh" && ! -f "${PROJECT_DIR}/utils/add-new-auth-keys.sh" ]]; then
    log "New Supabase auth key helper not found at ${PROJECT_DIR}/utils/add-new-auth-keys.sh."
    log "Update supabase_ref or recreate the generated Supabase project to enable sb_publishable/sb_secret keys."
    return
  fi

  log "Generating new Supabase auth keys and enabling asymmetric JWT verification"
  (cd "${PROJECT_DIR}" && sh utils/add-new-auth-keys.sh --update-env)
}

configure_supabase() {
  local host_data="${1}"
  local host_docker_socket="${2}"
  local public_url="${3}"
  local public_port="${4}"
  local site_url="${5}"
  local dashboard_username="${6}"
  local dashboard_password="${7}"
  local postgres_password="${8}"

  local host_project_dir="${host_data}/supabase/project"

  [[ -n "${dashboard_password}" ]] || dashboard_password="$(random_alnum 32)"
  [[ -n "${postgres_password}" ]] || postgres_password="$(random_alnum 32)"

  set_env "COMPOSE_PROJECT_NAME" "${COMPOSE_PROJECT_NAME}"
  set_env "SUPABASE_PUBLIC_URL" "${public_url}"
  set_env "API_EXTERNAL_URL" "${public_url}"
  set_env "KONG_HTTP_PORT" "${public_port}"
  set_env "SITE_URL" "${site_url}"
  set_env "DASHBOARD_USERNAME" "${dashboard_username}"
  set_env "DASHBOARD_PASSWORD" "${dashboard_password}"
  set_env "POSTGRES_PASSWORD" "${postgres_password}"
  set_env "DOCKER_SOCKET_LOCATION" "${host_docker_socket}"

  find "${PROJECT_DIR}" -maxdepth 1 -name 'docker-compose*.yml' -print0 |
    xargs -0 sed -i "s#\\./volumes/#${host_project_dir}/volumes/#g"
}

compose() {
  (
    cd "${PROJECT_DIR}"
    docker compose \
      --env-file "${ENV_FILE}" \
      --project-directory "${PROJECT_DIR}" \
      "$@"
  )
}

stop_stack() {
  if [[ "$(option stop_stack_on_addon_stop)" == "true" ]] && [[ -f "${ENV_FILE}" ]]; then
    log "Stopping Supabase stack"
    compose stop || true
  fi
}

main() {
  local supabase_ref public_url public_host public_port site_url dashboard_username
  local dashboard_password postgres_password docker_socket container_id host_data host_docker_socket

  supabase_ref="$(option supabase_ref)"
  public_url="$(option public_url)"
  public_host="$(option public_host)"
  public_port="$(option public_port)"
  site_url="$(option site_url)"
  dashboard_username="$(option dashboard_username)"
  dashboard_password="$(option dashboard_password)"
  postgres_password="$(option postgres_password)"

  docker_socket="$(detect_docker_socket)"
  if [[ -z "${docker_socket}" ]]; then
    log "Docker socket not found in the add-on container."
    log "Disable Protection mode for this add-on and start it again."
    log "Expected one of: /var/run/docker.sock or /run/docker.sock."
    exit 1
  fi

  configure_docker_client "${docker_socket}"

  container_id="$(current_container_id)"
  if [[ -z "${container_id}" ]]; then
    log "Unable to identify the add-on container from Docker."
    log "Current hostname is '${HOSTNAME}', expected Docker name is 'addon_${HOSTNAME//-/_}'."
    exit 1
  fi

  host_data="$(host_data_dir "${container_id}")"
  if [[ -z "${host_data}" ]]; then
    log "Unable to detect the host path for /data. docker_api access is required."
    exit 1
  fi

  host_docker_socket="$(host_mount_source "${docker_socket}" "${container_id}")"
  [[ -n "${host_docker_socket}" ]] || host_docker_socket="${docker_socket}"

  install_supabase_files "${supabase_ref}"
  ensure_new_auth_keys
  configure_supabase "${host_data}" "${host_docker_socket}" "${public_url}" "${public_port}" "${site_url}" \
    "${dashboard_username}" "${dashboard_password}" "${postgres_password}"

  if [[ "$(option enable_analytics)" == "true" ]]; then
    (cd "${PROJECT_DIR}" && sh run.sh config add logs)
  else
    (cd "${PROJECT_DIR}" && sh run.sh config remove logs) || true
  fi

  trap stop_stack TERM INT

  log "Pulling Supabase images"
  compose pull

  if [[ "$(option recreate_on_start)" == "true" ]]; then
    log "Recreating Supabase stack"
    compose up -d --wait --force-recreate
  else
    log "Starting Supabase stack"
    compose up -d --wait
  fi

  log "Supabase public URL is ${public_url}"
  log "Local add-on port mapping is http://${public_host}:${public_port}"
  log "Studio uses dashboard username '${dashboard_username}' and the configured dashboard password."

  while true; do
    sleep 60 &
    wait $!
    compose ps
  done
}

main "$@"
