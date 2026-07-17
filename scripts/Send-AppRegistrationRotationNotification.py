import argparse
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone


def build_payload(args):
    run_url = ""
    if args.collection_uri and args.project_name and args.run_id:
        collection_uri = args.collection_uri.rstrip("/")
        run_url = (
            f"{collection_uri}/{args.project_name}"
            f"/_build/results?buildId={args.run_id}&view=results"
        )

    return {
        "eventType": "AppRegistrationSecretRotated",
        "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
        "application": {
            "name": args.app_registration,
            "keyVaultName": args.key_vault_name,
        },
        "pipeline": {
            "name": args.pipeline_name,
            "runId": args.run_id,
            "projectName": args.project_name,
            "runUrl": run_url,
        },
        "email": {
            "subject": f"Secret rotated for {args.app_registration}",
            "bodyText": (
                f"A new secret was generated for app registration "
                f"'{args.app_registration}' and stored in Azure Key Vault "
                f"'{args.key_vault_name}'."
            ),
            "bodyHtml": (
                "<p>A new secret was generated for app registration "
                f"<strong>{args.app_registration}</strong> and stored in Azure "
                f"Key Vault <strong>{args.key_vault_name}</strong>.</p>"
            ),
        },
    }


def normalize_logic_app_url(logic_app_url):
    if not logic_app_url:
        return ""

    candidate = logic_app_url.strip()
    if not candidate or candidate.startswith("$("):
        return ""

    return candidate


def post_payload(logic_app_url, payload):
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        logic_app_url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(request) as response:
        status_code = response.getcode()

    print(f"Notification payload sent to Logic App. Status code: {status_code}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-registration", required=True)
    parser.add_argument("--key-vault-name", required=True)
    parser.add_argument("--logic-app-url", default="")
    parser.add_argument("--pipeline-name", default="")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--collection-uri", default="")
    parser.add_argument("--project-name", default="")
    args = parser.parse_args()

    payload = build_payload(args)
    print("Generated notification payload:")
    print(json.dumps(payload, indent=2))

    logic_app_url = normalize_logic_app_url(args.logic_app_url)
    if not logic_app_url:
        print("Logic App URL is not configured. Skipping notification delivery.")
        return 0

    try:
        post_payload(logic_app_url, payload)
        return 0
    except urllib.error.HTTPError as exc:
        print(
            f"Logic App returned HTTP {exc.code}. Response body: "
            f"{exc.read().decode('utf-8', errors='replace')}",
            file=sys.stderr,
        )
        return 1
    except urllib.error.URLError as exc:
        print(f"Failed to reach Logic App endpoint: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())