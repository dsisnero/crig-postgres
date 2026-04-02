require "spec"
require "../src/crig-postgres"

# Helper module for testing
module CrigPostgres::TestHelpers
  # Word document struct matching Rust test
  struct Word
    include JSON::Serializable

    getter id : String
    getter name : String
    getter definition : String

    def initialize(@id : String, @name : String, @definition : String)
    end
  end

  # Simple document struct for testing
  struct TestDocument
    include JSON::Serializable

    getter id : String
    getter content : String
    getter category : String

    def initialize(@id : String, @content : String, @category : String)
    end
  end

  # Mock embedding model for testing
  class MockEmbeddingModel
    include CrigPostgres::EmbeddingModel

    def max_documents : Int32
      100
    end

    def ndims : Int32
      1536
    end

    def embed_texts(texts : Enumerable(String)) : Array(CrigPostgres::Embedding)
      texts.map do |text|
        # Create simple deterministic embedding based on text hash
        seed = text.hash
        vec = Array.new(ndims) do |i|
          ((seed + i) % 1000).to_f / 1000.0
        end
        CrigPostgres::Embedding.new(text, vec)
      end
    end
  end

  # Test words matching Rust integration test
  def self.test_words : Array(Word)
    [
      Word.new(
        id: "0981d983-a5f8-49eb-89ea-f7d3b2196d2e",
        name: "flurbo",
        definition: "Definition of a *flurbo*: A flurbo is a green alien that lives on cold planets"
      ),
      Word.new(
        id: "62a36d43-80b6-4fd6-990c-f75bb02287d1",
        name: "glarb-glarb",
        definition: "Definition of a *glarb-glarb*: A glarb-glarb is a ancient tool used by the ancestors of the inhabitants of planet Jiro to farm the land."
      ),
      Word.new(
        id: "f9e17d59-32e5-440c-be02-b2759a654824",
        name: "linglingdong",
        definition: "Definition of a *linglingdong*: A term used by inhabitants of the far side of the moon to describe humans."
      ),
    ]
  end

  # Run migration SQL
  def self.run_migration(db : DB::Database)
    migration_sql = File.read("#{__DIR__}/migrations/001_setup.sql")
    db.exec(migration_sql)
  end

  # Clean up test data
  def self.cleanup(db : DB::Database)
    db.exec("DROP TABLE IF EXISTS documents")
    db.exec("DROP INDEX IF EXISTS document_embeddings_idx")
  end
end
