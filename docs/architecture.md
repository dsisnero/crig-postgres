# Architecture

## Overview

crig-postgres is a Crystal port of the Rust rig-postgres crate, providing PostgreSQL vector storage with pgvector support.

## Components

### PostgresVectorStore

The main vector store implementation that:
- Manages document storage with embeddings
- Provides vector similarity search
- Supports multiple distance functions

### PgVectorDistanceFunction

Enum defining supported distance functions:
- L2 (Euclidean distance)
- InnerProduct
- Cosine
- L1 (Manhattan distance)
- Hamming
- Jaccard

### PgSearchFilter

Filter builder for composing SQL WHERE clauses with support for:
- Equality, comparison operators
- AND/OR/NOT combinations
- LIKE patterns
- NULL checks

### EmbeddingModel

Interface for embedding generation that must be implemented by users.

## Data Flow

1. Documents are inserted with their embeddings
2. Search queries embed the query text
3. Vector similarity search uses pgvector operators
4. Results are returned with distance scores

## Dependencies

- `pg` (crystal-pg): PostgreSQL driver
- `json`: JSON serialization
- `uuid`: UUID generation for document IDs
