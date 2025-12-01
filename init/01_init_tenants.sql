#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="pg-multitenant"

section() {
  echo
  echo "---------------------------------------------------"
  echo "$1"
  echo "---------------------------------------------------"
}

echo "==================================================="
echo "  MULTI-TENANT POSTGRES ISOLATION TEST SUITE"
echo "==================================================="

# -----------------------------------------------------
# Cluster overview
# -----------------------------------------------------

section "Cluster overview: list databases"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -c "\l"

# -----------------------------------------------------
# Schema checks per tenant DB (existence + owner)
# -----------------------------------------------------

section "Schema layout for db_tenant_a"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_a -c "SELECT schema_name, schema_owner FROM information_schema.schemata ORDER BY schema_name;"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_a -c "SELECT * FROM app.sample_data;"

section "Schema layout for db_tenant_b"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_b -c "SELECT schema_name, schema_owner FROM information_schema.schemata ORDER BY schema_name;"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_b -c "SELECT * FROM app.sample_data;"

section "Schema layout for db_tenant_c"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_c -c "SELECT schema_name, schema_owner FROM information_schema.schemata ORDER BY schema_name;"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_c -c "SELECT * FROM app.sample_data;"

# -----------------------------------------------------
# Tenant A isolation tests
# -----------------------------------------------------

section "Tenant A: can connect to db_tenant_a"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_a_app -d db_tenant_a -c "SELECT current_user, current_database();"

section "Tenant A: can read its own app.sample_data"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_a_app -d db_tenant_a -c "SELECT * FROM app.sample_data;"

section "Tenant A: cannot connect to db_tenant_b"

set +e
docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_a_app -d db_tenant_b -c "SELECT current_user, current_database();"
echo "Exit code (expected non-zero): $?"
set -e

# -----------------------------------------------------
# Tenant B isolation tests
# -----------------------------------------------------

section "Tenant B: can connect to db_tenant_b"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_b_app -d db_tenant_b -c "SELECT current_user, current_database();"

section "Tenant B: can read its own app.sample_data"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_b_app -d db_tenant_b -c "SELECT * FROM app.sample_data;"

section "Tenant B: cannot connect to db_tenant_c"

set +e
docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_b_app -d db_tenant_c -c "SELECT current_user, current_database();"
echo "Exit code (expected non-zero): $?"
set -e

# -----------------------------------------------------
# Tenant C isolation tests
# -----------------------------------------------------

section "Tenant C: can connect to db_tenant_c"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_c_app -d db_tenant_c -c "SELECT current_user, current_database();"

section "Tenant C: can read its own app.sample_data"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_c_app -d db_tenant_c -c "SELECT * FROM app.sample_data;"

section "Tenant C: cannot connect to db_tenant_a"

set +e
docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_c_app -d db_tenant_a -c "SELECT current_user, current_database();"
echo "Exit code (expected non-zero): $?"
set -e

echo
echo "==================================================="
echo "  Isolation tests complete."
echo "==================================================="
