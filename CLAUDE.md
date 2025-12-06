# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **hardened multi-tenant PostgreSQL isolation pattern** designed for production environments including DoD, FedRAMP Moderate, and NIST 800-53 compliance. The architecture consolidates multiple tenants on a single PostgreSQL server while maintaining strict, testable isolation.

**Core isolation model:**
- Database-per-tenant: `db_tenant_a`, `db_tenant_b`, `db_tenant_c`
- Role-per-tenant: `tenant_a_app`, `tenant_b_app`, `tenant_c_app`
- Dedicated schema per database: `app` (owned by tenant role)
- Locked-down `public` schema (tenants have no access)
- Controlled `search_path`: `app, pg_catalog`
- No cross-database extensions (dblink, postgres_fdw)

## Environment Setup

Start the PostgreSQL environment:
```bash
docker compose up -d
```

Reset all data (removes volumes):
```bash
docker compose down -v
```

Connect to the container for admin queries:
```bash
docker exec -it pg-multitenant psql -U postgres
```

Connect as a specific tenant:
```bash
docker exec -it pg-multitenant psql -U tenant_a_app -d db_tenant_a
```

## Testing

Run the full isolation test suite:
```bash
./scripts/test_isolation.sh
```

The test suite validates:
- Positive tests: tenants can access their own data
- Negative tests (expected failures): cross-database access, public schema creation, extension creation, search_path bypass attempts, cross-tenant grants

## Architecture Details

### Database Initialization (init/01_init_tenants.sql)

The initialization script follows this pattern for each tenant:

1. **Create roles and databases** (in postgres database)
2. **Revoke default permissions** on databases from PUBLIC
3. **Grant CONNECT** only to the tenant's role
4. **Per-database setup** (connect to each tenant database):
   - Lock down `public` schema
   - Create `app` schema with tenant role as owner
   - Set safe `search_path` for the tenant role
   - Configure default privileges for future objects
   - Create sample tables owned by tenant role

**Critical pattern:** Tables must be explicitly owned by the tenant role using `ALTER TABLE ... OWNER TO tenant_x_app` to ensure proper isolation.

### Privilege Model

**Tenant roles have:**
- CONNECT privilege only on their own database
- USAGE and CREATE on their `app` schema
- No privileges on `public` schema
- No ability to create extensions
- No ability to connect to other tenant databases
- search_path locked to `app, pg_catalog` at database level

**Admin (postgres) role:**
- Full superuser access
- Can connect to all databases
- Used only for maintenance and testing verification

### Schema Structure

Each tenant database contains:
- `public` schema (locked down, not used for tenant data)
- `app` schema (tenant-owned namespace for all tenant objects)
- PostgreSQL system catalogs (`pg_catalog`, `information_schema`)

## Key Files

- `docker-compose.yml`: PostgreSQL 17 container configuration
- `init/01_init_tenants.sql`: Database initialization and hardening script
- `scripts/test_isolation.sh`: Comprehensive isolation test suite
- `docs/ARCHITECTURE.md`: Detailed architecture documentation
- `docs/SECURITY.md`: Security controls and assurance documentation
- `docs/COMPLIANCE.md`: NIST 800-53 and DoD SRG control mappings
- `docs/PGAUDIT.md`: Audit strategy for production deployments
- `docs/THREAT_MODEL.md`: Threat analysis and mitigations
- `docs/COST_MODEL.md`: Cost comparison analysis

## Adding a New Tenant

To add a new tenant, modify `init/01_init_tenants.sql` following the existing pattern:

1. Create the tenant role: `CREATE ROLE tenant_x_app LOGIN PASSWORD '...';`
2. Create the tenant database: `CREATE DATABASE db_tenant_x;`
3. Revoke PUBLIC access and grant CONNECT to tenant role
4. Connect to the new database: `\connect db_tenant_x`
5. Lock down `public` schema
6. Create and configure `app` schema
7. Set search_path for the tenant role
8. Configure default privileges
9. Create initial tables (if any) and set ownership

Then add corresponding tests to `scripts/test_isolation.sh`.

## Security Considerations

**When modifying tenant isolation:**
- Always use `REVOKE ... FROM PUBLIC` before granting specific privileges
- Always set table ownership explicitly with `ALTER TABLE ... OWNER TO tenant_x_app`
- Never grant privileges on `public` schema to tenant roles
- Test both positive (tenant can access own data) and negative (tenant cannot access other data) scenarios
- Consider search_path manipulation attacks when adding new functionality

**Extensions and FDW:**
- Tenant roles cannot create extensions (enforced by PostgreSQL permissions)
- Cross-database extensions (dblink, postgres_fdw) should never be enabled for tenant roles
- Only admin roles should have extension creation privileges

## Roadmap Context

This repository is designed to migrate to:
1. **Terraform-managed infrastructure** using the PostgreSQL provider (`postgresql_database`, `postgresql_role`, `postgresql_schema`, `postgresql_grant`)
2. **AWS RDS/Aurora deployment** with parameter groups for pgAudit, KMS encryption, and backup policies
3. **CI/CD integration** for automated testing and Terraform deployment

The local Docker environment serves as the reference implementation that will be replicated on RDS via Terraform.
