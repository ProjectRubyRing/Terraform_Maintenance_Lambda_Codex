import importlib
import json
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "modules" / "alb_maintenance_lambda" / "src"
EVENT_DIR = ROOT_DIR / "test" / "events"
sys.path.insert(0, str(SRC_DIR))

lambda_function = importlib.import_module("lambda_function")


class Context:
    aws_request_id = "pytest-context-request-id"


def load_event(name: str) -> dict:
    with (EVENT_DIR / name).open("r", encoding="utf-8") as file_obj:
        return json.load(file_obj)


def content_type(response: dict) -> str:
    return response["headers"]["Content-Type"]


def test_html_response(monkeypatch):
    monkeypatch.setenv("MAINTENANCE_TITLE", "Pytest Maintenance")
    monkeypatch.setenv("MAINTENANCE_MESSAGE", "Pytest maintenance message.")
    monkeypatch.setenv("MAINTENANCE_DETAIL", "Pytest detail.")
    monkeypatch.setenv("CSS_INLINE", "true")

    response = lambda_function.handler(load_event("alb_html_request.json"), Context())

    assert response["statusCode"] == 503
    assert response["statusDescription"] == "503 Service Unavailable"
    assert content_type(response).startswith("text/html")
    assert "Pytest Maintenance" in response["body"]
    assert "<style>" in response["body"]


def test_api_response_by_path(monkeypatch):
    monkeypatch.setenv("API_PATH_PREFIXES", "/api")

    response = lambda_function.handler(load_event("alb_api_request_by_path.json"), Context())
    body = json.loads(response["body"])

    assert response["statusCode"] == 503
    assert content_type(response).startswith("application/json")
    assert body["error"] == "service_unavailable"
    assert body["status"] == 503
    assert body["request_id"] == "api-request-by-path"


def test_api_response_by_accept_header(monkeypatch):
    monkeypatch.setenv("API_DETECT_ACCEPT_JSON", "true")

    response = lambda_function.handler(load_event("alb_api_request_by_accept_header.json"), Context())
    body = json.loads(response["body"])

    assert response["statusCode"] == 503
    assert content_type(response).startswith("application/json")
    assert body["request_id"] == "api-request-by-accept"


def test_css_response(monkeypatch):
    monkeypatch.setenv("CSS_PATH", "/maintenance.css")

    response = lambda_function.handler(load_event("alb_css_request.json"), Context())

    assert response["statusCode"] == 503
    assert content_type(response).startswith("text/css")
    assert ".maintenance" in response["body"]


def test_exception_response_is_valid_alb_shape(monkeypatch):
    def raise_error(_file_name: str) -> str:
        raise RuntimeError("asset read failed")

    monkeypatch.setattr(lambda_function, "_read_asset", raise_error)

    response = lambda_function.handler(load_event("alb_html_request.json"), Context())
    body = json.loads(response["body"])

    assert response["statusCode"] == 503
    assert response["statusDescription"] == "503 Service Unavailable"
    assert response["isBase64Encoded"] is False
    assert content_type(response).startswith("application/json")
    assert body["internal_error"] == "asset read failed"
