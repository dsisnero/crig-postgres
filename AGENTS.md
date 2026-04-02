# AGENTS

## Source Of Truth

- This repository ports Rust upstream behavior from `https://github.com/0xPlaygrounds/rig.git`.
- The pinned upstream checkout lives at `../../vendor/rig/rig-integrations/rig-postgres`.
- Current parity work targets the Rust crate at `vendor/rig/rig-integrations/rig-postgres`.
- The pinned upstream commit for this baseline is the same as the parent crig project.

## Required Workflow

1. Treat upstream Rust behavior, tests, and fixtures as normative.
2. Update `plans/inventory/rust_port_inventory.tsv` before or alongside implementation.
3. Keep `plans/inventory/rust_source_parity.tsv` and `plans/inventory/rust_test_parity.tsv`
   in sync with the pinned upstream source.
4. Preserve upstream semantics before introducing Crystal idioms.
5. Run `make format`, `make lint`, and `make test` before closing work.

## Parity Commands

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

## PostgreSQL Requirements

- PostgreSQL must be installed with pgvector extension
- Connection via environment variable: `DATABASE_URL`
- Test database created with: `CREATE EXTENSION vector;`
