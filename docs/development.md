# Development Guide

## Setup

1. Clone the repository
2. Run `make install` to install dependencies

## Running Unit Tests

```bash
make test
```

## Running Integration Tests

Integration tests require PostgreSQL with pgvector extension.

### Option 1: Use Docker (Recommended)

```bash
# Start PostgreSQL container
make docker-up

# Run integration tests
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/crig_test" crystal spec

# Stop container
make docker-down
```

Or use the all-in-one script:

```bash
make test-integration
```

### Option 2: Local PostgreSQL

1. Install PostgreSQL with pgvector extension
2. Create a test database:

```sql
CREATE DATABASE crig_test;
\c crig_test
CREATE EXTENSION vector;
```

3. Run migrations:

```bash
psql $DATABASE_URL < spec/migrations/001_setup.sql
```

4. Run tests:

```bash
DATABASE_URL="postgresql://user:pass@localhost:5432/crig_test" crystal spec
```

## Code Style

- Follow Crystal conventions
- Run `make format` before committing
- Run `make lint` to check for issues

## Adding Features

1. Check the upstream Rust implementation at `../../vendor/rig/rig-integrations/rig-postgres/`
2. Port behavior faithfully
3. Add tests
4. Update documentation
