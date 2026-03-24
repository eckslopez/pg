# Shared PostgreSQL Provisioning Workflow

## Purpose

This document defines the first real provisioning workflow for the external shared PostgreSQL host.

It is intentionally split from VM provisioning:

- the PostgreSQL VM/host is provisioned by `kubernetes-platform-infrastructure`
- PostgreSQL internals are provisioned by `pg`

This repository owns:
- tenant database creation
- tenant login role creation
- schema/grant/default privilege hardening
- tenant-facing secret contract

## Scope

V1 provisioning creates:

- one tenant database
- one tenant login role
- one application schema (`app`)
- database-level `CONNECT` isolation
- schema/table/sequence hardening
- role-level operational guardrails

It does not:

- provision the VM
- write values into Vault automatically
- onboard every tenant in one step

## Provisioning Entry Point

The first provisioning entry point is:

- [`scripts/provision_tenant.sh`](/Users/xavierlopez/Dev/pg/scripts/provision_tenant.sh)

It targets any reachable PostgreSQL host and applies the hardened tenant model to one tenant at a time.

## Required Inputs

Per run:

- PostgreSQL admin host
- PostgreSQL admin port
- PostgreSQL admin user
- PostgreSQL admin password
- tenant key
- database name
- application role name
- application role password

Optional inputs:

- platform owner role, default `platform_owner`
- app schema, default `app`
- statement timeout, default `3s`
- lock timeout, default `2s`
- idle-in-transaction timeout, default `10s`
- connection limit, default `2`

## Example

```bash
./scripts/provision_tenant.sh \
  --admin-host pg-01.internal \
  --admin-port 5432 \
  --admin-user postgres \
  --admin-password 'replace-me' \
  --tenant-key demo \
  --database-name db_demo \
  --app-role demo_app \
  --app-password 'replace-me'
```

## What The Script Applies

Against the shared host:

1. Ensures `platform_owner` exists
2. Creates or updates the tenant login role
3. Creates the tenant database if missing
4. Revokes `CONNECT` for `PUBLIC` on the tenant database
5. Grants `CONNECT` only to the tenant app role
6. Applies per-role operational guardrails:
   - `search_path`
   - `connection_limit`
   - `lock_timeout`
   - `idle_in_transaction_session_timeout`
7. Locks down `public` in the tenant database
8. Ensures the tenant `app` schema exists and is owned by `platform_owner`
9. Applies default privileges and runtime grants for tables and sequences

## Tenant Secret Output Contract

Provisioning produces this tenant-facing contract:

- Vault path: `tenants/<tenant>/db`

Required keys:

- `DATABASE_URL`
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

Example for tenant `demo`:

```text
tenants/demo/db
  DATABASE_URL=postgresql://demo_app:<password>@pg-01.internal:5432/db_demo
  DB_HOST=pg-01.internal
  DB_PORT=5432
  DB_NAME=db_demo
  DB_USER=demo_app
  DB_PASSWORD=<password>
```

`gitops` tenant manifests should consume only this output contract. They should not own database provisioning mechanics.

## Validation Procedure

After provisioning:

1. Connect as the tenant role to the tenant database
2. Confirm the role can access only its own database
3. Confirm the role cannot create objects in `public`
4. Confirm timeouts and connection limits are applied

The broader negative-test model remains in:

- [`scripts/test_isolation.sh`](/Users/xavierlopez/Dev/pg/scripts/test_isolation.sh)

## First Consumer

The first real tenant to consume this workflow will be:

- `panchito`

That onboarding remains tracked separately so the generic provisioning model can stabilize first.
