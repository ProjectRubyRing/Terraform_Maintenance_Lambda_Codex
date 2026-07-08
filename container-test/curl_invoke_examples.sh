#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${LAMBDA_TEST_PORT:-9000}"

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

curl -s \
  -XPOST "http://localhost:${PORT}/2015-03-31/functions/function/invocations" \
  -d @test/events/alb_html_request.json | "${PYTHON_BIN}" -m json.tool

curl -s \
  -XPOST "http://localhost:${PORT}/2015-03-31/functions/function/invocations" \
  -d @test/events/alb_api_request_by_path.json | "${PYTHON_BIN}" -m json.tool

curl -s \
  -XPOST "http://localhost:${PORT}/2015-03-31/functions/function/invocations" \
  -d @test/events/alb_css_request.json | "${PYTHON_BIN}" -m json.tool
