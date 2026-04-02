-- ensure extension is installed
CREATE EXTENSION IF NOT EXISTS vector;

-- create table with embeddings
CREATE TABLE IF NOT EXISTS documents (
  id UUID DEFAULT gen_random_uuid(),
  document JSONB NOT NULL,
  embedded_text TEXT NOT NULL,
  embedding vector(1536)
);

-- create index on embeddings
CREATE INDEX IF NOT EXISTS document_embeddings_idx ON documents
USING hnsw(embedding vector_cosine_ops);
