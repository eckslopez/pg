#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="pg-multitenant"

echo "==================================================="
echo "  MULTI-TENANT POSTGRES ISOLATION TEST SUITE"
echo "==================================================="
echo

# Helper function for visually separating sections
section() {
  echo
  echo "---------------------------------------------------"
  echo "$1"
  echo "---------------------------------------------------"
}

# -----------------------------------------------------
# EXPECT: Each tenant DB contains a schema named 'app'
# EXPECT: Schema 'app' is owned by tenant_x_app
# EXPECT: 'public' exists but is locked down
# -----------------------------------------------------

section "Checking schema layout for db_tenant_a"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_a -c "SELECT schema_name FROM information_schema.schemata;"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_a -c "SELECT schema_name, schema_owner FROM information_schema.schemata WHERE schema_name = 'app';"

section "Checking schema layout for db_tenant_b"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_b -c "SELECT schema_name FROM information_schema.schemata;"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_b -c "SELECT schema_name, schema_owner FROM information_schema.schemata WHERE schema_name = 'app';"

section "Checking schema layout for db_tenant_c"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_c -c "SELECT schema_name FROM information_schema.schemata;"

docker exec -it "$CONTAINER_NAME" \
  psql -U postgres -d db_tenant_c -c "SELECT schema_name, schema_owner FROM information_schema.schemata WHERE schema_name = 'app';"

# -----------------------------------------------------
# EXPECT: Each tenant can connect only to its own DB
# -----------------------------------------------------

section "Testing tenant_a_app can connect to db_tenant_a"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_a_app -d db_tenant_a -c "SELECT current_user, current_database();"

section "Testing tenant_a_app access to its schema"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_a_app -d db_tenant_a -c "SELECT * FROM app.sample_data;"

section "Testing tenant_a_app cannot connect to db_tenant_b"

set +e
docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_a_app -d db_tenant_b -c "SELECT current_user, current_database();"
echo "Exit code (expected non-zero): $?"
set -e

# -----------------------------------------------------
section "Testing tenant_b_app can connect to db_tenant_b"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_b_app -d db_tenant_b -c "SELECT current_user, current_database();"

section "Testing tenant_b_app access to its schema"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_b_app -d db_tenant_b -c "SELECT * FROM app.sample_data;"

section "Testing tenant_b_app cannot connect to db_tenant_c"

set +e
docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_b_app -d db_tenant_c -c "SELECT current_user, current_database();"
echo "Exit code (expected non-zero): $?"
set -e

# -----------------------------------------------------
section "Testing tenant_c_app can connect to db_tenant_c"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_c_app -d db_tenant_c -c "SELECT current_user, current_database();"

section "Testing tenant_c_app access to its schema"

docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_c_app -d db_tenant_c -c "SELECT * FROM app.sample_data;"

section "Testing tenant_c_app cannot connect to db_tenant_a"

set +e
docker exec -it "$CONTAINER_NAME" \
  psql -U tenant_c_app -d db_tenant_a -c "SELECT current_user, current_database();"
echo "Exit code (expected non-zero): $?"
set -e

section "Isolation tests complete."
