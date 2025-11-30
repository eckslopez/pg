-- 01_init_tenants.sql
-- Multi-tenant Postgres: 1 cluster -> many DBs -> 1 tenant per DB
-- Each tenant database has its own dedicated schema "app" owned by the tenant role.

-------------------------------
-- 0. Global hygiene
-------------------------------

-- Prevent random roles from connecting to admin-ish DBs by default
REVOKE CONNECT ON DATABASE postgres  FROM PUBLIC;
REVOKE CONNECT ON DATABASE template0 FROM PUBLIC;
REVOKE CONNECT ON DATABASE template1 FROM PUBLIC;

-------------------------------
-- 1. Create tenant databases
-------------------------------

CREATE DATABASE db_tenant_a;
CREATE DATABASE db_tenant_b;
CREATE DATABASE db_tenant_c;

-------------------------------
-- 2. Create tenant app roles
-------------------------------

CREATE ROLE tenant_a_app LOGIN PASSWORD 'tenant_a_password';
CREATE ROLE tenant_b_app LOGIN PASSWORD 'tenant_b_password';
CREATE ROLE tenant_c_app LOGIN PASSWORD 'tenant_c_password';

-------------------------------
-- 3. Restrict CONNECT on each DB
-------------------------------

REVOKE CONNECT ON DATABASE db_tenant_a FROM PUBLIC;
REVOKE CONNECT ON DATABASE db_tenant_b FROM PUBLIC;
REVOKE CONNECT ON DATABASE db_tenant_c FROM PUBLIC;

GRANT CONNECT ON DATABASE db_tenant_a TO tenant_a_app;
GRANT CONNECT ON DATABASE db_tenant_b TO tenant_b_app;
GRANT CONNECT ON DATABASE db_tenant_c TO tenant_c_app;

-------------------------------
-- 4. Per-DB schema / privileges:
--    - Lock down public
--    - Create dedicated schema "app"
--    - Set search_path
--    - Default privileges only for tenant role
-------------------------------

----------------------
-- Tenant A
----------------------
\connect db_tenant_a

-- 4.1 Lock down public schema; we won't use it for tenant data
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM tenant_a_app;

-- 4.2 Create dedicated schema "app" owned by tenant
CREATE SCHEMA app AUTHORIZATION tenant_a_app;

-- 4.3 Ensure tenant can use and create in this schema
GRANT USAGE, CREATE ON SCHEMA app TO tenant_a_app;

-- 4.4 Set search_path for the tenant role in this DB
ALTER ROLE tenant_a_app IN DATABASE db_tenant_a SET search_path = app, pg_catalog;

-- 4.5 Default privileges: newly created objects in "app" are only for tenant_a_app
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_a_app IN SCHEMA app
  REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_a_app IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tenant_a_app;

ALTER DEFAULT PRIVILEGES FOR ROLE tenant_a_app IN SCHEMA app
  REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_a_app IN SCHEMA app
  GRANT USAGE, SELECT ON SEQUENCES TO tenant_a_app;

ALTER DEFAULT PRIVILEGES FOR ROLE tenant_a_app IN SCHEMA app
  REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_a_app IN SCHEMA app
  GRANT EXECUTE ON FUNCTIONS TO tenant_a_app;


----------------------
-- Tenant B
----------------------
\connect db_tenant_b

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM tenant_b_app;

CREATE SCHEMA app AUTHORIZATION tenant_b_app;
GRANT USAGE, CREATE ON SCHEMA app TO tenant_b_app;

ALTER ROLE tenant_b_app IN DATABASE db_tenant_b SET search_path = app, pg_catalog;

ALTER DEFAULT PRIVILEGES FOR ROLE tenant_b_app IN SCHEMA app
  REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_b_app IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tenant_b_app;

ALTER DEFAULT PRIVILEGES FOR ROLE tenant_b_app IN SCHEMA app
  REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_b_app IN SCHEMA app
  GRANT USAGE, SELECT ON SEQUENCES TO tenant_b_app;

ALTER DEFAULT PRIVILEGES FOR ROLE tenant_b_app IN SCHEMA app
  REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE tenant_b_
