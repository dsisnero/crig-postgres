#!/bin/bash
set -e

echo "Starting PostgreSQL with pgvector..."

# Start Docker container
docker-compose up -d

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
  sleep 1
done

# Export DATABASE_URL
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/crig_test"

echo "PostgreSQL is ready at $DATABASE_URL"

# Run migrations
echo "Running migrations..."
docker-compose exec -T postgres psql -U postgres -d crig_test -f /dev/stdin < spec/migrations/001_setup.sql

# Run tests
echo "Running tests..."
crystal spec

# Cleanup
echo "Stopping PostgreSQL..."
docker-compose down

echo "Done!"
