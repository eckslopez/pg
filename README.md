```markdown
# Multi-Tenant PostgreSQL Isolation Demo

This project demonstrates secure multi-tenant isolation in PostgreSQL using:

- One Postgres server (cluster)
- One database per tenant
- One dedicated schema per tenant (`app`)
- One login role per tenant
- Strict `CONNECT` privileges
- Locked-down `public` schema
- Safe `search_path` settings

It uses Docker and docker-compose to start a PostgreSQL instance and automatically initialize tenant databases. A test script verifies that tenants cannot connect to or read data from each other’s databases.

## Project Structure

```
pg-multitenant/
├── docker-compose.yml
├── init/
│   └── 01_init_tenants.sql
└── scripts/
    └── test_isolation.sh
```

- `docker-compose.yml`: Starts PostgreSQL and runs initialization scripts.  
- `init/01_init_tenants.sql`: Creates tenant databases, roles, schemas, and sample data.  
- `scripts/test_isolation.sh`: Tests database creation, schema existence, sample data, and tenant isolation.

## Getting Started

Start PostgreSQL:

    docker compose up -d

On first startup, the initialization script:

- Creates tenant databases: `db_tenant_a`, `db_tenant_b`, `db_tenant_c`
- Creates tenant roles: `tenant_a_app`, `tenant_b_app`, `tenant_c_app`
- Creates a dedicated schema named `app` in each database
- Locks down the `public` schema
- Applies basic privileges
- Creates a simple table (`app.sample_data`) with one row to verify isolation behavior

## What the Test Script Checks

The test script (`scripts/test_isolation.sh`) performs:

### Cluster-level checks
- Lists all databases (`\l`) to confirm that `db_tenant_a`, `db_tenant_b`, and `db_tenant_c` exist.

### Per-database checks (as user `postgres`)
- Lists schemas in each tenant database.
- Confirms the presence of the `app` schema.
- Shows the owner of the `app` schema.
- Confirms that the table `app.sample_data` exists and contains the expected test row.

### Tenant isolation checks
- Each tenant role (e.g., `tenant_a_app`) can connect only to its own database (e.g., `db_tenant_a`).
- Each tenant role can query only its own `app.sample_data`.
- Each tenant role fails when attempting to connect to another tenant’s database.
- Forbidden connections produce non-zero exit codes.

Run the test suite:

    ./scripts/test_isolation.sh

Example expected failure:

    FATAL: permission denied for database "db_tenant_b"
    Exit code (expected non-zero): 2

## Resetting the Environment

To completely reset and reinitialize the PostgreSQL cluster:

    docker compose down -v
    docker compose up -d

## Security Principles Demonstrated

- One tenant per database
- Dedicated schema per tenant
- Locked-down `public` schema
- Minimal privileges
- Safe `search_path`
- Controlled schema ownership
- No cross-database tenant access

This pattern is suitable for local development and for production deployments such as AWS RDS PostgreSQL and Aurora PostgreSQL.

## Future Improvements

Possible enhancements:

- Add stronger hardening using `ALTER DEFAULT PRIVILEGES`
- Add Terraform modules to deploy the model on AWS RDS
- Integrate pgAudit for auditing DDL and role changes
- Add negative tests for `search_path`, extension creation, and FDW creation
- Add an application layer to demonstrate real tenant-bound query paths
