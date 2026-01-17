# frozen_string_literal: true

RSpec.describe PgReports::AnnotationParser do
  describe ".parse" do
    it "parses PgReports format annotations" do
      query = "/*app:myapp,file:app/models/user.rb,line:42,method:find_active*/ SELECT * FROM users"

      result = described_class.parse(query)

      expect(result[:app]).to eq("myapp")
      expect(result[:file]).to eq("app/models/user.rb")
      expect(result[:line]).to eq("42")
      expect(result[:method]).to eq("find_active")
    end

    it "parses Marginalia format annotations" do
      query = "/*application:myapp,controller:users,action:index*/ SELECT * FROM users"

      result = described_class.parse(query)

      expect(result[:application]).to eq("myapp")
      expect(result[:controller]).to eq("users")
      expect(result[:action]).to eq("index")
    end

    it "parses Rails QueryLogs format" do
      query = "/*controller='users',action='show'*/ SELECT * FROM users"

      result = described_class.parse(query)

      expect(result[:controller]).to eq("users")
      expect(result[:action]).to eq("show")
    end

    it "returns empty hash for queries without annotations" do
      query = "SELECT * FROM users"

      result = described_class.parse(query)

      expect(result).to eq({})
    end

    it "returns empty hash for nil query" do
      expect(described_class.parse(nil)).to eq({})
    end
  end

  describe ".strip_annotations" do
    it "removes annotations from query" do
      query = "/*app:myapp,file:test.rb*/ SELECT * FROM users WHERE id = 1"

      result = described_class.strip_annotations(query)

      expect(result).to eq("SELECT * FROM users WHERE id = 1")
    end

    it "handles multiple annotations" do
      query = "/*app:myapp*/ /*controller:users*/ SELECT * FROM users"

      result = described_class.strip_annotations(query)

      expect(result).to eq("SELECT * FROM users")
    end

    it "returns query unchanged if no annotations" do
      query = "SELECT * FROM users"

      result = described_class.strip_annotations(query)

      expect(result).to eq(query)
    end
  end

  describe ".format_for_display" do
    it "formats file and line" do
      annotation = {file: "app/models/user.rb", line: "42"}

      result = described_class.format_for_display(annotation)

      expect(result).to eq("app/models/user.rb:42")
    end

    it "includes method if present" do
      annotation = {file: "app/models/user.rb", line: "42", method: "find_active"}

      result = described_class.format_for_display(annotation)

      expect(result).to include("app/models/user.rb:42")
      expect(result).to include("#find_active")
    end

    it "includes controller/action if present" do
      annotation = {controller: "users", action: "index"}

      result = described_class.format_for_display(annotation)

      expect(result).to include("users#index")
    end

    it "includes app name if present" do
      annotation = {app: "myapp", file: "test.rb"}

      result = described_class.format_for_display(annotation)

      expect(result).to include("[myapp]")
    end

    it "returns nil for empty annotation" do
      expect(described_class.format_for_display({})).to be_nil
    end
  end
end
