# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial port from Rust rig-postgres crate
- `PostgresVectorStore` for vector similarity search
- `PgVectorDistanceFunction` enum (L2, InnerProduct, Cosine, L1, Hamming, Jaccard)
- `PgSearchFilter` class for SQL WHERE clause composition
- `SearchResult` and `SearchResultOnlyId` structs
- `EmbeddingModel` interface for embedding generation
- `VectorSearchRequest` builder for search queries
- Unit tests for filter operations
- Integration test helpers

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [0.1.0] - 2026-04-02

### Added
- Initial release
