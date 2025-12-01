# Cost Model and Savings Potential

## Purpose

This document provides a simple cost model for comparing:

- One RDS PostgreSQL instance per tenant (single-tenant model), versus
- One multi-tenant RDS PostgreSQL instance with one database per tenant.

The goal is to demonstrate potential cost savings while maintaining strong tenant isolation.

## Assumptions (Example)

These numbers are illustrative and should be replaced with actual instance types and pricing for the target environment.

- Workload:
  - 10 tenants (could scale up to dozens or more).
- Single-tenant baseline:
  - One `r6g.large` (example) RDS PostgreSQL instance per tenant.
- Multi-tenant shared model:
  - One `r6g.2xlarge` RDS PostgreSQL instance hosting all 10 tenants.
- Storage:
  - Similar total storage allocated in both models, possibly with some additional headroom for multi-tenant.

## Single-Tenant Model

- 10 tenants → 10 RDS instances.
- Operational characteristics:
  - 10 instances to patch, monitor, and tune.
  - 10 sets of parameter groups, security groups, and alarms.
  - 10 sets of backups and snapshots.
- Cost characteristics:
  - Instance-hour cost is roughly 10 × (cost of baseline instance).
  - Fixed overhead per instance is multiplied by tenant count.

## Multi-Tenant Model

- 10 tenants → 1 larger RDS instance.
- Resources are shared:
  - CPU, memory, and IO capacity sized appropriately for aggregate load.
  - One instance to patch, monitor, and tune.
  - One set of parameter groups and security groups.
  - Backups and snapshots at instance-level instead of per-tenant.
- Cost characteristics:
  - Instance-hour cost is closer to 1 × (cost of a larger instance).
  - Storage may be similar or slightly higher, but paid once.
  - Fixed overhead is significantly reduced.

## Qualitative Cost Comparison

Compared to the single-tenant model, the multi-tenant approach:

- Reduces the number of RDS instances by approximately the number of tenants.
- Reduces operational overhead:
  - fewer instances to patch and upgrade,
  - fewer monitoring targets,
  - fewer parameter groups and maintenance windows.
- Simplifies infrastructure-as-code:
  - one RDS resource with multiple `postgresql_database` resources instead of many RDS instances.

Even if the multi-tenant instance is 2–3 sizes larger than a single-tenant instance, the total cost is often substantially lower than N separate instances.

## Non-Cost Tradeoffs

- **Pros**:
  - Lower RDS cost.
  - Centralized tuning and performance management.
  - Easier management with Terraform and shared modules.
- **Cons / Considerations**:
  - Performance isolation must be managed carefully (noisy neighbor issues).
  - RDS backups and snapshots become multi-tenant artifacts and must be handled with care.
  - Accreditation teams must be comfortable with data-plane isolation instead of infra-only isolation.

## Summary

By moving from “one RDS instance per tenant” to “one RDS instance with one database per tenant,” this design can significantly reduce cost and operational overhead. The security controls and test suite in this project exist to demonstrate that these savings can be achieved without sacrificing tenant data isolation.
