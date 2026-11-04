#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# Explicit local daemon: never touch a remote Docker context.
docker_local() { env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH docker --host=unix:///var/run/docker.sock "$@"; }
container="vett-sql-test-$$"
trap 'docker_local rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker_local run -d --rm --name "$container" --network none -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17 >/dev/null
ready=false
for attempt in {1..30}; do
 if docker_local exec "$container" pg_isready -U postgres >/dev/null 2>&1; then ready=true; break; fi
 sleep 1
done
if [ "$ready" != true ]; then echo 'PostgreSQL not ready' >&2; exit 1; fi
sql() { docker_local exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1; }
sql < supabase/test-support/bootstrap.sql >/dev/null
for file in supabase/migrations/*.sql; do
 echo "Migration: $file"
 sql < "$file" >/dev/null
done
echo 'Deployment audit: scripts/deploy/audit-readonly.sql'
sql < scripts/deploy/audit-readonly.sql >/dev/null
for file in supabase/tests/*.sql; do
 echo "Test: $file"
 sql < "$file" >/dev/null
done
echo 'All SQL tests passed (Auth/Storage stubs).'
