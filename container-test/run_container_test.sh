#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-alb-maintenance-lambda-test:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-alb-maintenance-lambda-test}"
PORT="${LAMBDA_TEST_PORT:-9000}"

if command -v docker >/dev/null 2>&1; then
  ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
  ENGINE="podman"
else
  echo "docker or podman is required." >&2
  exit 1
fi

find_python() {
  for candidate in python3.13 python3 python; do
    if command -v "${candidate}" >/dev/null 2>&1 && "${candidate}" --version >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  echo "python3.13, python3, or python is required." >&2
  return 1
}

PYTHON_BIN="$(find_python)"

cd "${ROOT_DIR}"

"${ENGINE}" build -f container-test/Dockerfile -t "${IMAGE_NAME}" .

cleanup() {
  "${ENGINE}" rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

"${ENGINE}" run \
  --name "${CONTAINER_NAME}" \
  -d \
  -p "${PORT}:8080" \
  -e CSS_INLINE=false \
  -e MAINTENANCE_TITLE="Container Test Maintenance" \
  "${IMAGE_NAME}" >/dev/null

sleep 2

invoke_and_assert() {
  local event_file="$1"
  local expected_status="$2"
  local expected_content_type="$3"
  local response_file
  response_file="$(mktemp)"

  local success="false"
  for _attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS \
      -XPOST "http://localhost:${PORT}/2015-03-31/functions/function/invocations" \
      -d @"${event_file}" >"${response_file}"; then
      success="true"
      break
    fi
    sleep 1
  done

  if [[ "${success}" != "true" ]]; then
    echo "failed to invoke Lambda container for ${event_file}" >&2
    return 1
  fi

  "${PYTHON_BIN}" - "${response_file}" "${event_file}" "${expected_status}" "${expected_content_type}" <<'PY'
import json
import sys

response_path, event_file, expected_status, expected_content_type = sys.argv[1:5]

with open(response_path, "r", encoding="utf-8") as file_obj:
    response = json.load(file_obj)

status_code = response.get("statusCode")
headers = {str(key).lower(): str(value) for key, value in (response.get("headers") or {}).items()}
content_type = headers.get("content-type", "")

if status_code != int(expected_status):
    raise SystemExit(f"{event_file}: expected statusCode {expected_status}, got {status_code}")

if not content_type.startswith(expected_content_type):
    raise SystemExit(f"{event_file}: expected Content-Type {expected_content_type}, got {content_type}")

print(f"{event_file}: statusCode={status_code} Content-Type={content_type}")
PY

  rm -f "${response_file}"
}

invoke_and_assert "test/events/alb_html_request.json" "503" "text/html"
invoke_and_assert "test/events/alb_api_request_by_path.json" "503" "application/json"
invoke_and_assert "test/events/alb_css_request.json" "503" "text/css"
