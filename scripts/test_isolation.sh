#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="pg-multitenant"

echo "=== Testing tenant_a_app isolation ==="
docker exec -it "$CONTAINER_NAME" psql -U tenant_a_app -d db_tenant_a -c "SELECT current_user, current_database();"
echo

echo ">>> tenant_a_app trying to access sample_data in own DB (should succeed)"
docker exec -it "$CONTAINER_NAME" psql -U tenant_a_app -d db_tenant_a -c "SELECT * FROM public.sample_data;"
echo

echo ">>> tenant_a_app trying to connect to db_tenant_b (should FAIL)"
set +e
docker exec -it "$CONTAINER_NAME" psql -U tenant_a_app -d db_tenant_b -c "SELECT current_user, current_database();"
echo "Exit code (expect non-zero): $?"
set -e
echo

echo "=== Testing tenant_b_app isolation ==="
docker exec -it "$CONTAINER_NAME" psql -U tenant_b_app -d db_tenant_b -c "SELECT current_user, current_database();"
echo

echo ">>> tenant_b_app trying to connect to db_tenant_c (should FAIL)"
set +e
docker exec -it "$CONTAINER_NAME" psql -U tenant_b_app -d db_tenant_c -c "SELECT current_user, current_database();"
echo "Exit code (expect non-zero): $?"
set -e
echo

echo "=== Testing tenant_c_app isolation ==="
docker exec -it "$CONTAINER_NAME" psql -U tenant_c_app -d db_tenant_c -c "SELECT current_user, current_database();"
echo

echo ">>> tenant_c_app trying to connect to db_tenant_a (should FAIL)"
set +e
docker exec -it "$CONTAINER_NAME" psql -U tenant_c_app -d db_tenant_a -c "SELECT current_user, current_database();"
echo "Exit code (expect non-zero): $?"
set -e

echo
echo "=== Isolation smoke test complete ==="
