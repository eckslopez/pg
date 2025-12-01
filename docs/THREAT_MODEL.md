# Multi-Tenant PostgreSQL Threat Model

## Purpose

This document outlines the threat model for running multiple tenants on a single PostgreSQL server (e.g., a shared AWS RDS instance) with one database per tenant. It identifies key assets, actors, threats, and the controls used to mitigate them.

## Assets

- Tenant data stored in per-tenant databases:
  - `db_tenant_a`, `db_tenant_b`, `db_tenant_c`, …
- Tenant credentials:
  - `tenant_a_app`, `tenant_b_app`, `tenant_c_app`, …
- PostgreSQL configuration and privileges.
- RDS instance configuration, snapshots, and backups.
- Audit logs / connection logs.

## Actors

- **Tenant application**:
  - Connects as its assigned role (e.g., `tenant_a_app`).
- **Platform operators / DBAs**:
  - Use the admin role (e.g., `postgres` or `rds_superuser` on RDS).
- **Adversarial tenant**:
  - Attempts to access other tenants’ data, escalate privileges, or disrupt service.
- **External attacker**:
  - Attempts to compromise application or database from outside.

## Primary Security Goal

Prevent **tenant-to-tenant data access**:

> A tenant must never be able to read, write, or otherwise access another tenant’s data, even though they share the same PostgreSQL server and infrastructure.

## Key Threats and Mitigations

### T1. Cross-database data access

- **Threat**: Tenant A connects to Tenant B’s database and queries data.
- **Mitigations**:
  - `REVOKE CONNECT` on all tenant databases from `PUBLIC`.
  - `GRANT CONNECT` only to the corresponding tenant role.
  - RDS `pg_hba` equivalent plus security groups restrict network access.
- **Evidence**:
  - `scripts/test_isolation.sh` attempts cross-database connections and expects failures.

### T2. Cross-schema access within a database

- **Threat**: Tenant tries to access objects outside its own schema.
- **Mitigations**:
  - Each tenant uses only its `app` schema (`CREATE SCHEMA app AUTHORIZATION tenant_x_app`).
  - No tenant role is granted privileges on other schemas.
  - The `public` schema is not used for tenant data and can be fully locked down.
- **Evidence**:
  - Tests verify that tenant roles can only query `app.sample_data` in their own DB.

### T3. Abuse of `public` schema and `search_path`

- **Threat**: Tenant creates functions or tables in `public` to shadow system functions or pollute namespaces.
- **Mitigations**:
  - `public` schema is locked down (no `CREATE` for tenant roles).
  - Tenant objects are placed in the `app` schema.
  - `search_path` can be set to `app, pg_catalog` in the hardened configuration.
- **Evidence**:
  - Configuration and future tests ensure tenant roles cannot use `public` for arbitrary object creation.

### T4. Privilege escalation via extensions or foreign data wrappers

- **Threat**: Tenant uses `CREATE EXTENSION`, `CREATE SERVER`, or FDW features to access other data.
- **Mitigations**:
  - Only admin roles can create extensions.
  - Tenant roles are not granted `CREATE EXTENSION` or `CREATE SERVER`.
- **Evidence**:
  - Future negative tests will try to create extensions as tenant roles and expect failures.

### T5. Data exposure via backups and snapshots

- **Threat**: A single RDS snapshot contains multiple tenants’ data and is improperly shared.
- **Mitigations**:
  - Strict control over who can create and access RDS snapshots.
  - Clear SOP for backup/restore that treats snapshots as multi-tenant sensitive artifacts.
  - Optional per-tenant logical dumps for export/return-of-data use cases.

### T6. Noisy neighbor / resource starvation

- **Threat**: One tenant’s workload degrades performance for others.
- **Mitigations**:
  - Appropriate sizing and IO class for the shared RDS instance.
  - Connection pooling and connection limits per application.
  - Monitoring and alerting on CPU/IO/per-tenant usage.
- **Note**:
  - This is an availability/SLO concern rather than direct data isolation but is relevant for multi-tenant systems.

## Residual Risks

- Admin account compromise (e.g., `rds_superuser`) remains a critical risk; this is true for single-tenant instances as well.
- Misconfiguration in IAM, security groups, or parameter groups could weaken isolation if not audited.
- Bugs in PostgreSQL or the cloud provider’s platform are possible but mitigated by timely patching and version management.

## Conclusion

With the controls described above, multi-tenant use of a single PostgreSQL server can provide strong tenant isolation while significantly reducing the number of database instances required. The test suite in this project serves as ongoing evidence that these controls function as intended.
