#!/usr/bin/env bash
set -euo pipefail

readonly repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo_root"

# Only synthetic example values are resolved; no daemon or production env is used.
docker compose --project-name petmagic-staging-check \
  --env-file deploy/vps/.env.vps.staging.example \
  -f docker-compose.yml -f deploy/vps/compose.staging.vps.yaml \
  --profile generation config --format json | python3 -c '
import json
import sys

services = json.load(sys.stdin)["services"]
expected = {
    "postgres": {
        "/var/lib/postgresql/data": "/opt/petmagic-staging/shared/postgres",
    },
    "backend": {
        "/var/petmagic/DataProtection-Keys": "/opt/petmagic-staging/shared/api-data/DataProtection-Keys",
        "/var/petmagic/wwwroot": "/opt/petmagic-staging/shared/api-data/wwwroot",
    },
    "generation-worker": {
        "/var/petmagic/wwwroot/templates-media": "/opt/petmagic-staging/shared/api-data/wwwroot/templates-media",
    },
}
for name, mounts in expected.items():
    actual = {item["target"]: item["source"] for item in services[name].get("volumes", [])
              if item["type"] == "bind"}
    if actual != mounts:
        raise SystemExit(f"{name}: staging persistent mounts were lost or changed")

for name in ("postgres", "mailpit"):
    if services[name].get("ports"):
        raise SystemExit(f"{name}: staging must not publish ports")
ports = services["backend"].get("ports", [])
if len(ports) != 1 or ports[0].get("host_ip") != "127.0.0.1" or str(ports[0]["published"]) != "15001":
    raise SystemExit("backend: staging must bind only to 127.0.0.1:15001")

for name in ("postgres", "mailpit", "backend"):
    logging = services[name].get("logging", {})
    if logging != {"driver": "local", "options": {"max-file": "5", "max-size": "10m"}}:
        raise SystemExit(f"{name}: staging log rotation is missing")

print("Staging Compose persistence, port isolation and log rotation passed.")
'
