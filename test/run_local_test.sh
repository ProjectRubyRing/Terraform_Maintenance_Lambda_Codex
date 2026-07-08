#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

"${PYTHON_BIN}" test/local_invoke.py \
  --event test/events/alb_html_request.json \
  --mode inline-css \
  --assert-status 503 \
  --assert-content-type "text/html"

"${PYTHON_BIN}" test/local_invoke.py \
  --event test/events/alb_api_request_by_path.json \
  --assert-status 503 \
  --assert-content-type "application/json"

"${PYTHON_BIN}" test/local_invoke.py \
  --event test/events/alb_css_request.json \
  --assert-status 503 \
  --assert-content-type "text/css"

if "${PYTHON_BIN}" -c "import pytest" >/dev/null 2>&1; then
  "${PYTHON_BIN}" -m pytest test/test_lambda_function.py
else
  echo "pytest is not installed; skipped pytest tests."
fi
