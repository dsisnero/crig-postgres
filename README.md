# crig-postgres

This repository is a Crystal port of the [rig-postgres](https://github.com/0xPlaygrounds/rig/tree/main/rig-integrations/rig-postgres) Rust crate.

PostgreSQL vector store for Crystal with pgvector support, providing vector similarity search powered by the pgvector extension.

## Upstream Source

- **Repository**: https://github.com/0xPlaygrounds/rig.git
- **Subdirectory**: rig-integrations/rig-postgres
- **Pinned ref**: Same as parent crig project

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crig-postgres:
       github: dsisnero/crig-postgres
   ```

2. Run `shards install`

## Prerequisites

- PostgreSQL with [pgvector](https://github.com/pgvector/pgvector) extension installed
- Create extension in your database: `CREATE EXTENSION vector;`

## Usage

```crystal
require "crig-postgres"

# Connect to PostgreSQL
db = DB.open("postgresql://localhost/mydb")

# Create a mock embedding model (or use a real one from crig)
class MyEmbeddingModel
  include CrigPostgres::EmbeddingModel

  def max_documents : Int32
    100
  end

  def ndims : Int32
    1536
  end

  def embed_texts(texts : Enumerable(String)) : Array(CrigPostgres::Embedding)
    texts.map do |text|
      vec = Array.new(ndims) { rand }
      CrigPostgres::Embedding.new(text, vec)
    end
  end
end

model = MyEmbeddingModel.new

# Create vector store
store = CrigPostgres::PostgresVectorStore.new(
  embedding_model: model,
  db: db,
  documents_table: "documents",
  distance_function: CrigPostgres::PgVectorDistanceFunction::Cosine
)

# Create table with vector support
store.create_table(dims: 1536)

# Insert documents
documents = [{my_doc, [embedding]}]
store.insert_documents(documents)

# Search for similar documents
req = CrigPostgres::VectorSearchRequest(CrigPostgres::PgSearchFilter).builder
  .query("search query")
  .samples(5)
  .build

results = store.top_n(req, MyDocumentType)
```

## Upstream README Highlights

The original Rust implementation provides:
- `PostgresVectorStore` struct with generic embedding model support
- Multiple distance functions (L2, InnerProduct, Cosine, L1, Hamming, Jaccard)
- `PgSearchFilter` for composing SQL WHERE clauses
- Integration with `pgvector` for vector similarity search
- Support for both full document and ID-only search results

## Development

```bash
make install    # Install dependencies
make format     # Format code
make lint       # Run linter
make test       # Run tests
make clean      # Clean build artifacts
```

## Contributing

1. Fork it (<https://github.com/dsisnero/crig-postgres/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
