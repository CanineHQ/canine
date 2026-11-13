require "rails_helper"

RSpec.describe AgentLoop::Titler do
  let(:client) { instance_double(Llm::OpenRouter) }

  before { allow(Llm::OpenRouter).to receive(:new).and_return(client) }

  it "tidies the model's title, and gives nil when the call fails" do
    allow(client).to receive(:chat).and_return(Llm::OpenRouter::Reply.new({ "content" => "\"Complete Amazon security training.\"\nExtra" }, {}))
    expect(described_class.title("do the amazon training", api_key: "key", model: "test/model")).to eq("Complete Amazon security training")
    expect(client).to have_received(:chat).with(hash_including(timeout: described_class::TIMEOUT, max_tokens: 50))

    allow(client).to receive(:chat).and_raise(Llm::OpenRouter::Error, "Couldn't reach OpenRouter: Net::ReadTimeout")
    expect(described_class.title("do the amazon training", api_key: "key", model: "test/model")).to be_nil
  end
end
