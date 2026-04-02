require "./spec_helper"

describe CrigPostgres do
  describe CrigPostgres::PgVectorDistanceFunction do
    it "converts L2 to SQL operator" do
      CrigPostgres::PgVectorDistanceFunction::L2.to_s.should eq("<->")
    end

    it "converts InnerProduct to SQL operator" do
      CrigPostgres::PgVectorDistanceFunction::InnerProduct.to_s.should eq("<#>")
    end

    it "converts Cosine to SQL operator" do
      CrigPostgres::PgVectorDistanceFunction::Cosine.to_s.should eq("<=>")
    end

    it "converts L1 to SQL operator" do
      CrigPostgres::PgVectorDistanceFunction::L1.to_s.should eq("<+>")
    end

    it "converts Hamming to SQL operator" do
      CrigPostgres::PgVectorDistanceFunction::Hamming.to_s.should eq("<~>")
    end

    it "converts Jaccard to SQL operator" do
      CrigPostgres::PgVectorDistanceFunction::Jaccard.to_s.should eq("<%>")
    end
  end

  describe CrigPostgres::PgSearchFilter do
    describe ".eq" do
      it "creates equality filter" do
        filter = CrigPostgres::PgSearchFilter.eq("category", JSON::Any.new("science"))
        filter.condition.should eq("category = $")
        filter.values.size.should eq(1)
        filter.values[0].as_s.should eq("science")
      end
    end

    describe ".gt" do
      it "creates greater than filter" do
        filter = CrigPostgres::PgSearchFilter.gt("score", JSON::Any.new(0.5))
        filter.condition.should eq("score > $")
        filter.values.size.should eq(1)
      end
    end

    describe ".lt" do
      it "creates less than filter" do
        filter = CrigPostgres::PgSearchFilter.lt("price", JSON::Any.new(100))
        filter.condition.should eq("price < $")
        filter.values.size.should eq(1)
      end
    end

    describe ".gte" do
      it "creates greater than or equal filter" do
        filter = CrigPostgres::PgSearchFilter.gte("score", JSON::Any.new(0.5))
        filter.condition.should eq("score >= $")
      end
    end

    describe ".lte" do
      it "creates less than or equal filter" do
        filter = CrigPostgres::PgSearchFilter.lte("score", JSON::Any.new(0.5))
        filter.condition.should eq("score <= $")
      end
    end

    describe ".like" do
      it "creates like filter" do
        filter = CrigPostgres::PgSearchFilter.like("title", "'%Crystal%'")
        filter.condition.should eq("title like '%Crystal%'")
        filter.values.should be_empty
      end
    end

    describe ".is_null" do
      it "creates is null filter" do
        filter = CrigPostgres::PgSearchFilter.is_null("deleted_at")
        filter.condition.should eq("deleted_at is null")
        filter.values.should be_empty
      end
    end

    describe ".is_not_null" do
      it "creates is not null filter" do
        filter = CrigPostgres::PgSearchFilter.is_not_null("published_at")
        filter.condition.should eq("published_at is not null")
        filter.values.should be_empty
      end
    end

    describe "#and" do
      it "combines filters with AND" do
        filter1 = CrigPostgres::PgSearchFilter.eq("category", JSON::Any.new("science"))
        filter2 = CrigPostgres::PgSearchFilter.gt("score", JSON::Any.new(0.5))
        combined = filter1.and(filter2)
        combined.condition.should eq("(category = $) AND (score > $)")
        combined.values.size.should eq(2)
      end
    end

    describe "#or" do
      it "combines filters with OR" do
        filter1 = CrigPostgres::PgSearchFilter.eq("category", JSON::Any.new("science"))
        filter2 = CrigPostgres::PgSearchFilter.eq("category", JSON::Any.new("tech"))
        combined = filter1.or(filter2)
        combined.condition.should eq("(category = $) OR (category = $)")
        combined.values.size.should eq(2)
      end
    end

    describe "#not" do
      it "negates filter" do
        filter = CrigPostgres::PgSearchFilter.eq("archived", JSON::Any.new(true))
        negated = filter.not
        negated.condition.should eq("NOT (archived = $)")
        negated.values.size.should eq(1)
      end
    end

    describe "#into_clause" do
      it "returns condition and values tuple" do
        filter = CrigPostgres::PgSearchFilter.eq("category", JSON::Any.new("science"))
        condition, values = filter.into_clause
        condition.should eq("category = $")
        values.size.should eq(1)
      end
    end

    describe "complex filter composition" do
      it "supports nested AND/OR/NOT" do
        category_filter = CrigPostgres::PgSearchFilter.eq("category", JSON::Any.new("science"))
        score_filter = CrigPostgres::PgSearchFilter.gt("score", JSON::Any.new(0.8))
        archived_filter = CrigPostgres::PgSearchFilter.eq("archived", JSON::Any.new(false))

        combined = category_filter.and(score_filter).and(archived_filter.not)
        combined.condition.should contain("AND")
        combined.condition.should contain("NOT")
        combined.values.size.should eq(3)
      end
    end
  end

  describe CrigPostgres::SearchResult do
    it "stores id, document, and distance" do
      id = UUID.random
      doc = JSON::Any.new({"id" => JSON::Any.new("test"), "content" => JSON::Any.new("Hello"), "category" => JSON::Any.new("greeting")})
      result = CrigPostgres::SearchResult.new(id, doc, 0.5)

      result.id.should eq(id)
      result.distance.should eq(0.5)
    end

    it "converts to typed result" do
      id = UUID.random
      doc = JSON::Any.new({"id" => JSON::Any.new("test"), "content" => JSON::Any.new("Hello"), "category" => JSON::Any.new("greeting")})
      result = CrigPostgres::SearchResult.new(id, doc, 0.5)

      distance, result_id, typed_doc = result.to_result(CrigPostgres::TestHelpers::TestDocument)
      distance.should eq(0.5)
      result_id.should eq(id.to_s)
      typed_doc.id.should eq("test")
      typed_doc.content.should eq("Hello")
      typed_doc.category.should eq("greeting")
    end
  end

  describe CrigPostgres::SearchResultOnlyId do
    it "stores id and distance" do
      id = UUID.random
      result = CrigPostgres::SearchResultOnlyId.new(id, 0.75)
      result.id.should eq(id)
      result.distance.should eq(0.75)
    end
  end
end
