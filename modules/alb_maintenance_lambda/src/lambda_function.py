import json
import os
import uuid
from datetime import datetime, timezone
from html import escape
from http import HTTPStatus
from pathlib import Path
from typing import Any, Optional


BASE_DIR = Path(__file__).resolve().parent
HTML_FILE = "maintenance.html"
CSS_FILE = "maintenance.css"


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    request_id = _request_id(event, context)

    try:
        path = _request_path(event)
        headers = _normalized_headers(event)
        status_code = _status_code()

        if _is_css_request(path):
            _log("info", "maintenance_css_response", request_id=request_id, path=path)
            return _response(
                status_code=status_code,
                content_type="text/css; charset=utf-8",
                body=_read_asset(CSS_FILE),
            )

        if _is_api_request(path, headers):
            _log("info", "maintenance_api_response", request_id=request_id, path=path)
            return _json_response(status_code, request_id)

        _log("info", "maintenance_html_response", request_id=request_id, path=path)
        return _response(
            status_code=status_code,
            content_type="text/html; charset=utf-8",
            body=_render_html(),
        )
    except Exception as exc:
        _log("error", "maintenance_handler_error", request_id=request_id, error=str(exc))
        return _json_response(_status_code(), request_id, fallback_error=str(exc))


def _render_html() -> str:
    html = _read_asset(HTML_FILE)
    css = _read_asset(CSS_FILE)
    css_path = os.getenv("CSS_PATH", "/maintenance.css")

    if _env_bool("CSS_INLINE", True):
        css_markup = f"<style>\n{css}\n</style>"
    else:
        css_markup = f'<link rel="stylesheet" href="{escape(css_path, quote=True)}">'

    replacements = {
        "{{TITLE}}": escape(os.getenv("MAINTENANCE_TITLE", "Service Maintenance")),
        "{{MESSAGE}}": escape(os.getenv("MAINTENANCE_MESSAGE", "Service is temporarily unavailable due to maintenance.")),
        "{{DETAIL}}": escape(os.getenv("MAINTENANCE_DETAIL", "Please try again later.")),
        "{{CSS}}": css_markup,
    }

    for placeholder, value in replacements.items():
        html = html.replace(placeholder, value)

    return html


def _json_response(status_code: int, request_id: str, fallback_error: Optional[str] = None) -> dict[str, Any]:
    body = {
        "error": os.getenv("API_ERROR_CODE", "service_unavailable"),
        "message": os.getenv("API_ERROR_MESSAGE", "Service is temporarily unavailable due to maintenance."),
        "status": status_code,
        "request_id": request_id,
    }
    if fallback_error:
        body["internal_error"] = fallback_error

    return _response(
        status_code=status_code,
        content_type="application/json; charset=utf-8",
        body=json.dumps(body, ensure_ascii=False, separators=(",", ":")),
    )


def _response(status_code: int, content_type: str, body: str) -> dict[str, Any]:
    headers = _base_headers(content_type)

    # ALB Lambda targets require this flat response shape. API Gateway fields such
    # as cookies or nested response objects are not valid for ALB target groups.
    return {
        "statusCode": status_code,
        "statusDescription": f"{status_code} {_reason_phrase(status_code)}",
        "isBase64Encoded": False,
        "headers": headers,
        "body": body,
    }


def _base_headers(content_type: str) -> dict[str, str]:
    headers = {
        "Content-Type": content_type,
        "Cache-Control": os.getenv("CACHE_CONTROL", "no-store, no-cache, must-revalidate, max-age=0"),
    }

    retry_after = _int_env("RETRY_AFTER_SECONDS", 300)
    if retry_after > 0:
        headers["Retry-After"] = str(retry_after)

    if _env_bool("CORS_ENABLED", False):
        headers["Access-Control-Allow-Origin"] = os.getenv("CORS_ALLOW_ORIGIN", "*")
        headers["Access-Control-Allow-Methods"] = os.getenv("CORS_ALLOW_METHODS", "GET,HEAD,OPTIONS")
        headers["Access-Control-Allow-Headers"] = os.getenv(
            "CORS_ALLOW_HEADERS",
            "Content-Type,Accept,X-Requested-With,Authorization",
        )

    headers.update(_additional_headers())
    return headers


def _is_api_request(path: str, headers: dict[str, str]) -> bool:
    if any(path.startswith(prefix) for prefix in _api_path_prefixes()):
        return True

    if _env_bool("API_DETECT_ACCEPT_JSON", True) and "application/json" in headers.get("accept", "").lower():
        return True

    if _env_bool("API_DETECT_CONTENT_TYPE_JSON", True) and "application/json" in headers.get("content-type", "").lower():
        return True

    if _env_bool("API_DETECT_X_REQUESTED_WITH", True):
        requested_with = headers.get("x-requested-with", "")
        if requested_with.lower() == "xmlhttprequest":
            return True

    return False


def _is_css_request(path: str) -> bool:
    css_path = os.getenv("CSS_PATH", "/maintenance.css")
    return path == css_path


def _api_path_prefixes() -> list[str]:
    raw = os.getenv("API_PATH_PREFIXES", "/api")
    prefixes = [prefix.strip() for prefix in raw.split(",") if prefix.strip()]
    return prefixes or ["/api"]


def _request_path(event: dict[str, Any]) -> str:
    path = event.get("path") or "/"
    return str(path)


def _normalized_headers(event: dict[str, Any]) -> dict[str, str]:
    normalized: dict[str, str] = {}

    for key, value in (event.get("headers") or {}).items():
        if value is not None:
            normalized[str(key).lower()] = str(value)

    for key, values in (event.get("multiValueHeaders") or {}).items():
        if key is None or values is None:
            continue
        if isinstance(values, list):
            normalized.setdefault(str(key).lower(), ",".join(str(value) for value in values))
        else:
            normalized.setdefault(str(key).lower(), str(values))

    return normalized


def _request_id(event: dict[str, Any], context: Any) -> str:
    headers = _normalized_headers(event)
    for header_name in ("x-amzn-trace-id", "x-request-id", "x-correlation-id"):
        value = headers.get(header_name)
        if value:
            return value

    aws_request_id = getattr(context, "aws_request_id", None)
    if aws_request_id:
        return str(aws_request_id)

    return str(uuid.uuid4())


def _read_asset(file_name: str) -> str:
    return (BASE_DIR / file_name).read_text(encoding="utf-8")


def _status_code() -> int:
    status_code = _int_env("STATUS_CODE", 503)
    if 200 <= status_code <= 599:
        return status_code
    return 503


def _reason_phrase(status_code: int) -> str:
    try:
        return HTTPStatus(status_code).phrase
    except ValueError:
        return "Status"


def _int_env(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


def _env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _additional_headers() -> dict[str, str]:
    raw = os.getenv("ADDITIONAL_RESPONSE_HEADERS", "{}")
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {}

    if not isinstance(parsed, dict):
        return {}

    return {str(key): str(value) for key, value in parsed.items() if value is not None}


def _log(level: str, message: str, **fields: Any) -> None:
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "message": message,
    }
    entry.update(fields)
    print(json.dumps(entry, ensure_ascii=False, separators=(",", ":")))
