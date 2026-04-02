require "pg"
require "json"
require "uuid"

# PostgreSQL vector store for Crystal with pgvector support
# This is a standalone implementation that doesn't require crig
module CrigPostgres
  VERSION = "0.1.0"

  # Simple embedding struct for standalone use
  struct Embedding
    include JSON::Serializable

    getter document : String
    getter vec : Array(Float64)

    def initialize(@document : String = "", @vec : Array(Float64) = [] of Float64)
    end
  end

  # Embedding model interface
  module EmbeddingModel
    abstract def max_documents : Int32
    abstract def ndims : Int32
    abstract def embed_texts(texts : Enumerable(String)) : Array(Embedding)

    def embed_text(text : String) : Embedding
      embed_texts([text]).first? || raise "There should be at least one embedding"
    end
  end

  # Vector search request
  class VectorSearchRequest(F)
    getter query : String
    getter samples : UInt64
    getter threshold : Float64?
    getter filter : F?

    def initialize(@query : String, @samples : UInt64, @threshold : Float64? = nil, @filter : F? = nil)
    end

    class Builder(F)
      @query : String = ""
      @samples : UInt64 = 10
      @threshold : Float64? = nil
      @filter : F? = nil

      def query(@query : String) : self
        self
      end

      def samples(@samples : UInt64) : self
        self
      end

      def threshold(@threshold : Float64) : self
        self
      end

      def filter(@filter : F) : self
        self
      end

      def build : VectorSearchRequest(F)
        VectorSearchRequest.new(@query, @samples, @threshold, @filter)
      end
    end

    def self.builder : Builder(F)
      Builder(F).new
    end
  end

  # PgVector supported distance functions
  enum PgVectorDistanceFunction
    L2
    InnerProduct
    Cosine
    L1
    Hamming
    Jaccard

    def to_s : String
      case self
      in .l2?            then "<->"
      in .inner_product? then "<#>"
      in .cosine?        then "<=>"
      in .l1?            then "<+>"
      in .hamming?       then "<~>"
      in .jaccard?       then "<%>"
      end
    end
  end

  # Search filter for PostgreSQL queries
  class PgSearchFilter
    property condition : String
    property values : Array(JSON::Any)

    def initialize(@condition : String = "", @values = [] of JSON::Any)
    end

    def self.eq(key : String, value : JSON::Any) : self
      new("#{key} = $", [value])
    end

    def self.gt(key : String, value : JSON::Any) : self
      new("#{key} > $", [value])
    end

    def self.lt(key : String, value : JSON::Any) : self
      new("#{key} < $", [value])
    end

    def self.gte(key : String, value : JSON::Any) : self
      new("#{key} >= $", [value])
    end

    def self.lte(key : String, value : JSON::Any) : self
      new("#{key} <= $", [value])
    end

    def self.like(key : String, pattern : String) : self
      new("#{key} like #{pattern}")
    end

    # ameba:disable Naming/PredicateName
    def self.is_null(key : String) : self
      new("#{key} is null")
    end

    # ameba:disable Naming/PredicateName
    def self.is_not_null(key : String) : self
      new("#{key} is not null")
    end

    def and(other : self) : self
      PgSearchFilter.new(
        condition: "(#{@condition}) AND (#{other.condition})",
        values: @values + other.values
      )
    end

    def or(other : self) : self
      PgSearchFilter.new(
        condition: "(#{@condition}) OR (#{other.condition})",
        values: @values + other.values
      )
    end

    def not : self
      PgSearchFilter.new(
        condition: "NOT (#{@condition})",
        values: @values
      )
    end

    def into_clause : Tuple(String, Array(JSON::Any))
      {@condition, @values}
    end
  end

  # Search result from PostgreSQL query
  struct SearchResult
    getter id : UUID
    getter document : JSON::Any
    getter distance : Float64

    def initialize(@id : UUID, @document : JSON::Any, @distance : Float64)
    end

    def to_result(type : T.class) : Tuple(Float64, String, T) forall T
      doc = T.from_json(@document.to_json)
      {@distance, @id.to_s, doc}
    end
  end

  # Search result with only ID
  struct SearchResultOnlyId
    getter id : UUID
    getter distance : Float64

    def initialize(@id : UUID, @distance : Float64)
    end
  end

  # PostgreSQL vector store implementation
  class PostgresVectorStore(E)
    @embedding_model : E
    @db : DB::Database
    @documents_table : String
    @distance_function : PgVectorDistanceFunction

    def initialize(
      @embedding_model : E,
      @db : DB::Database,
      @documents_table : String = "documents",
      @distance_function : PgVectorDistanceFunction = PgVectorDistanceFunction::Cosine,
    )
    end

    def self.with_defaults(model : E, db : DB::Database) : self forall E
      new(model, db)
    end

    # Create the documents table with pgvector support
    def create_table(dims : Int32) : Nil
      @db.exec <<-SQL
        CREATE TABLE IF NOT EXISTS #{@documents_table} (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          document JSONB NOT NULL,
          embedded_text TEXT NOT NULL,
          embedding vector(#{dims}) NOT NULL
        )
      SQL

      # Create index for vector similarity search
      @db.exec <<-SQL
        CREATE INDEX IF NOT EXISTS #{@documents_table}_embedding_idx
        ON #{@documents_table}
        USING ivfflat (embedding #{@distance_function} vector_ops)
        WITH (lists = 100)
      SQL
    end

    # Insert documents with their embeddings
    def insert_documents(documents : Array(Tuple(T, Array(Embedding)))) : Nil forall T
      documents.each do |document, embeddings|
        id = UUID.random
        json_document = document.to_json

        embeddings.each do |embedding|
          embedding_text = embedding.document
          embedding_vec = embedding.vec

          @db.exec(
            "INSERT INTO #{@documents_table} (id, document, embedded_text, embedding) VALUES ($1, $2, $3, $4)",
            args: [id, json_document, embedding_text, embedding_vec.map(&.to_f32)]
          )
        end
      end
    end

    private def search_query(with_document : Bool, req : VectorSearchRequest(PgSearchFilter)) : Tuple(String, Array(JSON::Any))
      document_col = with_document ? ", document" : ""

      # Build threshold filter if provided
      thresh = req.threshold.try { |threshold| PgSearchFilter.gt("distance", JSON::Any.new(threshold)) }

      # Combine with request filter
      filter = case {thresh, req.filter}
               when {PgSearchFilter, PgSearchFilter}
                 thresh_value = thresh
                 filter_value = req.filter
                 if thresh_value && filter_value
                   thresh_value.and(filter_value)
                 end
               when {PgSearchFilter, _}
                 thresh
               when {_, PgSearchFilter}
                 req.filter
               end

      # Build WHERE clause
      where_clause, params = if filter
                               expr, filter_params = filter.into_clause
                               {"WHERE #{expr}", filter_params}
                             else
                               {"", [] of JSON::Any}
                             end

      # Replace $ placeholders with numbered parameters
      counter = 3
      where_clause = where_clause.gsub('$') do
        result = "$#{counter}"
        counter += 1
        result
      end

      query = <<-SQL
        SELECT id#{document_col}, distance FROM (
          SELECT DISTINCT ON (id) id#{document_col}, embedding #{@distance_function} $1 as distance
          FROM #{@documents_table}
          #{where_clause}
          ORDER BY id, distance
        ) as d
        ORDER BY distance
        LIMIT $2
      SQL

      {query, params}
    end

    # Find top N similar documents
    def top_n(req : VectorSearchRequest(PgSearchFilter), type : D.class) : Array(Tuple(Float64, String, D)) forall D
      # Embed the query text
      prompt_embedding = @embedding_model.embed_text(req.query)
      embedding_vec = prompt_embedding.vec.map(&.to_f32)

      query, params = search_query(true, req)

      # Build query parameters
      db_params = [embedding_vec.as(DB::Any), req.samples.to_i64.as(DB::Any)]
      params.each do |param|
        db_params << extract_db_value(param)
      end

      results = [] of Tuple(Float64, String, D)

      @db.query(query, args: db_params) do |result_set|
        result_set.each do
          id = result_set.read(UUID)
          document = JSON.parse(result_set.read(String))
          distance = result_set.read(Float64)

          doc = D.from_json(document.to_json)
          results << {distance, id.to_s, doc}
        end
      end

      results
    end

    # Find top N similar document IDs only
    def top_n_ids(req : VectorSearchRequest(PgSearchFilter)) : Array(Tuple(Float64, String))
      # Embed the query text
      prompt_embedding = @embedding_model.embed_text(req.query)
      embedding_vec = prompt_embedding.vec.map(&.to_f32)

      query, params = search_query(false, req)

      # Build query parameters
      db_params = [embedding_vec.as(DB::Any), req.samples.to_i64.as(DB::Any)]
      params.each do |param|
        db_params << extract_db_value(param)
      end

      results = [] of Tuple(Float64, String)

      @db.query(query, args: db_params) do |result_set|
        result_set.each do
          id = result_set.read(UUID)
          distance = result_set.read(Float64)
          results << {distance, id.to_s}
        end
      end

      results
    end

    private def extract_db_value(value : JSON::Any) : DB::Any
      case value.raw
      when Nil     then nil.as(DB::Any)
      when Bool    then value.as_bool.as(DB::Any)
      when Int64   then value.as_i64.as(DB::Any)
      when Float64 then value.as_f.as(DB::Any)
      when String  then value.as_s.as(DB::Any)
      else
        value.to_json.as(DB::Any)
      end
    end
  end
end
