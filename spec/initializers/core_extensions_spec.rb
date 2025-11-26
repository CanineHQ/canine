require "rails_helper"

RSpec.describe "Hash#to_yaml_raw" do
  it "returns YAML without the document start marker" do
    hash = { "nodeSelector" => { "gpu" => "true" } }

    result = hash.to_yaml_raw

    expect(result).to eq("nodeSelector:\n  gpu: 'true'\n")
  end

  it "produces valid YAML that can be parsed back" do
    hash = { name: "test", items: [ 1, 2, 3 ] }

    result = hash.to_yaml_raw
    parsed = YAML.safe_load(result, permitted_classes: [ Symbol ], permitted_symbols: [ :name, :items ])

    expect(parsed).to eq(hash)
  end
end
