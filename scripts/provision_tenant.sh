#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/provision_tenant.sh \
    --admin-host <host> \
    --admin-port <port> \
    --admin-user <user> \
    --admin-password <password> \
    --tenant-key <tenant_key> \
    --database-name <database_name> \
    --app-role <app_role> \
    --app-password <app_password>

Optional:
  --platform-owner-role <role>                 Default: platform_owner
  --app-schema <schema>                        Default: app
  --statement-timeout <duration>               Default: 3s
  --lock-timeout <duration>                    Default: 2s
  --idle-in-tx-timeout <duration>              Default: 10s
  --connection-limit <number>                  Default: 2
  --sslmode <mode>                             Default: disable

This script provisions one tenant database and login role on a shared PostgreSQL host.
It is intentionally host-targeted and does not provision the VM itself.
EOF
}

ADMIN_HOST=""
ADMIN_PORT="5432"
ADMIN_USER="postgres"
ADMIN_PASSWORD=""
TENANT_KEY=""
DATABASE_NAME=""
APP_ROLE=""
APP_PASSWORD=""
PLATFORM_OWNER_ROLE="platform_owner"
APP_SCHEMA="app"
STATEMENT_TIMEOUT="3s"
LOCK_TIMEOUT="2s"
IDLE_IN_TX_TIMEOUT="10s"
CONNECTION_LIMIT="2"
SSLMODE="disable"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --admin-host)
      ADMIN_HOST="$2"
      shift 2
      ;;
    --admin-port)
      ADMIN_PORT="$2"
      shift 2
      ;;
    --admin-user)
      ADMIN_USER="$2"
      shift 2
      ;;
    --admin-password)
      ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --tenant-key)
      TENANT_KEY="$2"
      shift 2
      ;;
    --database-name)
      DATABASE_NAME="$2"
      shift 2
      ;;
    --app-role)
      APP_ROLE="$2"
      shift 2
      ;;
    --app-password)
      APP_PASSWORD="$2"
      shift 2
      ;;
    --platform-owner-role)
      PLATFORM_OWNER_ROLE="$2"
      shift 2
      ;;
    --app-schema)
      APP_SCHEMA="$2"
      shift 2
      ;;
    --statement-timeout)
      STATEMENT_TIMEOUT="$2"
      shift 2
      ;;
    --lock-timeout)
      LOCK_TIMEOUT="$2"
      shift 2
      ;;
    --idle-in-tx-timeout)
      IDLE_IN_TX_TIMEOUT="$2"
      shift 2
      ;;
    --connection-limit)
      CONNECTION_LIMIT="$2"
      shift 2
      ;;
    --sslmode)
      SSLMODE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_identifier() {
  local value="$1"
  local field="$2"
  if [[ ! "$value" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "Invalid ${field}: '${value}'. Use lowercase letters, numbers, and underscores only." >&2
    exit 1
  fi
}

escape_sql_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

run_psql() {
  local db_name="$1"
  local sql="$2"

  PGPASSWORD="$ADMIN_PASSWORD" psql \
    "host=${ADMIN_HOST} port=${ADMIN_PORT} user=${ADMIN_USER} dbname=${db_name} sslmode=${SSLMODE}" \
    -v ON_ERROR_STOP=1 <<SQL
${sql}
SQL
}

if [[ -z "$ADMIN_HOST" || -z "$ADMIN_PASSWORD" || -z "$TENANT_KEY" || -z "$DATABASE_NAME" || -z "$APP_ROLE" || -z "$APP_PASSWORD" ]]; then
  usage >&2
  exit 1
fi

require_identifier "$TENANT_KEY" "tenant key"
require_identifier "$DATABASE_NAME" "database name"
require_identifier "$APP_ROLE" "app role"
require_identifier "$PLATFORM_OWNER_ROLE" "platform owner role"
require_identifier "$APP_SCHEMA" "app schema"

if [[ ! "$CONNECTION_LIMIT" =~ ^[0-9]+$ ]]; then
  echo "Invalid connection limit: '${CONNECTION_LIMIT}'" >&2
  exit 1
fi

APP_PASSWORD_ESCAPED="$(escape_sql_literal "$APP_PASSWORD")"
STATEMENT_TIMEOUT_ESCAPED="$(escape_sql_literal "$STATEMENT_TIMEOUT")"
LOCK_TIMEOUT_ESCAPED="$(escape_sql_literal "$LOCK_TIMEOUT")"
IDLE_IN_TX_TIMEOUT_ESCAPED="$(escape_sql_literal "$IDLE_IN_TX_TIMEOUT")"

echo "Provisioning tenant '${TENANT_KEY}' on ${ADMIN_HOST}:${ADMIN_PORT} ..."

run_psql "postgres" "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${PLATFORM_OWNER_ROLE}') THEN
    EXECUTE 'CREATE ROLE ${PLATFORM_OWNER_ROLE} NOLOGIN';
  END IF;
END
\$\$;

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${APP_ROLE}') THEN
    EXECUTE 'CREATE ROLE ${APP_ROLE} LOGIN PASSWORD ''${APP_PASSWORD_ESCAPED}''';
  ELSE
    EXECUTE 'ALTER ROLE ${APP_ROLE} LOGIN PASSWORD ''${APP_PASSWORD_ESCAPED}''';
  END IF;
END
\$\$;

SELECT format('CREATE DATABASE %I OWNER %I', '${DATABASE_NAME}', '${ADMIN_USER}')
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_database
  WHERE datname = '${DATABASE_NAME}'
)\gexec

REVOKE CONNECT ON DATABASE ${DATABASE_NAME} FROM PUBLIC;
GRANT CONNECT ON DATABASE ${DATABASE_NAME} TO ${APP_ROLE};
ALTER DATABASE ${DATABASE_NAME} SET statement_timeout = '${STATEMENT_TIMEOUT_ESCAPED}';

ALTER ROLE ${APP_ROLE} CONNECTION LIMIT ${CONNECTION_LIMIT};
ALTER ROLE ${APP_ROLE} SET search_path = ${APP_SCHEMA}, pg_catalog;
ALTER ROLE ${APP_ROLE} SET lock_timeout = '${LOCK_TIMEOUT_ESCAPED}';
ALTER ROLE ${APP_ROLE} SET idle_in_transaction_session_timeout = '${IDLE_IN_TX_TIMEOUT_ESCAPED}';
"

run_psql "${DATABASE_NAME}" "
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM ${ADMIN_USER};
GRANT USAGE ON SCHEMA public TO ${ADMIN_USER};
GRANT CREATE ON SCHEMA public TO ${ADMIN_USER};

DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.schemata
    WHERE schema_name = '${APP_SCHEMA}'
  ) THEN
    EXECUTE 'CREATE SCHEMA ${APP_SCHEMA} AUTHORIZATION ${PLATFORM_OWNER_ROLE}';
  END IF;
END
\$\$;

ALTER SCHEMA ${APP_SCHEMA} OWNER TO ${PLATFORM_OWNER_ROLE};

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${APP_SCHEMA} FROM ${APP_ROLE};
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ${APP_SCHEMA} FROM ${APP_ROLE};
REVOKE GRANT OPTION FOR ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${APP_SCHEMA} FROM ${APP_ROLE};
REVOKE GRANT OPTION FOR ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ${APP_SCHEMA} FROM ${APP_ROLE};

ALTER DEFAULT PRIVILEGES FOR ROLE ${PLATFORM_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
  REVOKE ALL ON TABLES FROM ${APP_ROLE};
ALTER DEFAULT PRIVILEGES FOR ROLE ${PLATFORM_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
  REVOKE ALL ON SEQUENCES FROM ${APP_ROLE};
ALTER DEFAULT PRIVILEGES FOR ROLE ${PLATFORM_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_ROLE};
ALTER DEFAULT PRIVILEGES FOR ROLE ${PLATFORM_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
  GRANT USAGE, SELECT ON SEQUENCES TO ${APP_ROLE};

GRANT USAGE ON SCHEMA ${APP_SCHEMA} TO ${APP_ROLE};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${APP_SCHEMA} TO ${APP_ROLE};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ${APP_SCHEMA} TO ${APP_ROLE};

REVOKE GRANT OPTION FOR SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${APP_SCHEMA} FROM ${APP_ROLE};
REVOKE GRANT OPTION FOR USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ${APP_SCHEMA} FROM ${APP_ROLE};
"

cat <<EOF
Tenant '${TENANT_KEY}' provisioned.

Vault output contract:
  path: tenants/${TENANT_KEY}/db
  keys:
    DATABASE_URL=postgresql://${APP_ROLE}:<redacted>@${ADMIN_HOST}:${ADMIN_PORT}/${DATABASE_NAME}
    DB_HOST=${ADMIN_HOST}
    DB_PORT=${ADMIN_PORT}
    DB_NAME=${DATABASE_NAME}
    DB_USER=${APP_ROLE}
    DB_PASSWORD=<redacted>
EOF
