#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Optional


ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "modules" / "alb_maintenance_lambda" / "src"


class LocalContext:
    aws_request_id = "local-context-request-id"


def _load_handler():
    sys.path.insert(0, str(SRC_DIR))
    import lambda_function

    return lambda_function.handler


def _load_event(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file_obj:
        return json.load(file_obj)


def _header_value(headers: dict[str, Any], name: str) -> Optional[str]:
    for key, value in headers.items():
        if key.lower() == name.lower():
            return str(value)
    return None


def _apply_mode(mode: str) -> None:
    if mode == "inline-css":
        os.environ["CSS_INLINE"] = "true"
    elif mode == "external-css":
        os.environ["CSS_INLINE"] = "false"


def _apply_env(values: list[str]) -> None:
    for value in values:
        if "=" not in value:
            raise ValueError(f"--env must be KEY=VALUE: {value}")
        key, env_value = value.split("=", 1)
        os.environ[key] = env_value


def _print_response(response: dict[str, Any]) -> None:
    print(f"statusCode: {response.get('statusCode')}")
    print(f"statusDescription: {response.get('statusDescription')}")
    print("headers:")
    print(json.dumps(response.get("headers", {}), indent=2, ensure_ascii=False, sort_keys=True))
    print("body:")
    print(response.get("body", ""))


def main() -> int:
    parser = argparse.ArgumentParser(description="Invoke the ALB maintenance Lambda handler locally.")
    parser.add_argument("--event", required=True, type=Path, help="Path to an ALB event JSON file.")
    parser.add_argument(
        "--mode",
        choices=["default", "inline-css", "external-css"],
        default="default",
        help="Local CSS rendering mode override.",
    )
    parser.add_argument("--assert-status", type=int, help="Expected statusCode.")
    parser.add_argument("--assert-content-type", help="Expected Content-Type prefix.")
    parser.add_argument("--env", action="append", default=[], help="Set a Lambda environment variable, KEY=VALUE.")
    args = parser.parse_args()

    _apply_mode(args.mode)
    _apply_env(args.env)

    handler = _load_handler()
    response = handler(_load_event(args.event), LocalContext())
    _print_response(response)

    if args.assert_status is not None and response.get("statusCode") != args.assert_status:
        print(f"expected statusCode {args.assert_status}, got {response.get('statusCode')}", file=sys.stderr)
        return 1

    if args.assert_content_type:
        content_type = _header_value(response.get("headers", {}), "Content-Type")
        if content_type is None or not content_type.startswith(args.assert_content_type):
            print(
                f"expected Content-Type starting with {args.assert_content_type}, got {content_type}",
                file=sys.stderr,
            )
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
