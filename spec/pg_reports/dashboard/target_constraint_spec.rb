# frozen_string_literal: true

RSpec.describe PgReports::Dashboard::ReportsRegistry, ".target_constraint" do
  it "marks schema_analysis as primary_default_database_only" do
    expect(described_class.target_constraint(:schema_analysis))
      .to eq(:primary_default_database_only)
  end

  it "returns nil for categories without a constraint" do
    expect(described_class.target_constraint(:queries)).to be_nil
    expect(described_class.target_constraint(:indexes)).to be_nil
    expect(described_class.target_constraint(:tables)).to be_nil
    expect(described_class.target_constraint(:connections)).to be_nil
    expect(described_class.target_constraint(:system)).to be_nil
  end

  it "tolerates string keys" do
    expect(described_class.target_constraint("schema_analysis"))
      .to eq(:primary_default_database_only)
  end

  it "returns nil for unknown categories" do
    expect(described_class.target_constraint(:nope)).to be_nil
  end
end
