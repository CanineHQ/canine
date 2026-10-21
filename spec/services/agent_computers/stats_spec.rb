require "rails_helper"

RSpec.describe AgentComputers::Stats do
  describe ".parse_stream" do
    def output(status, turn)
      [ status, turn ].map { |response| "#{described_class::STREAM_SEPARATOR}\n#{response}" }.join
    end

    it "reads Selkies' transport and TURN relay hosts, without the credentials" do
      turn = { iceServers: [ { urls: [ "stun:stun.cloudflare.com:3478" ] },
                             { urls: [ "turn:turn.cloudflare.com:3478?transport=udp", "turns:turn.cloudflare.com:5349" ], username: "u", credential: "secret" } ] }
      stream = described_class.parse_stream(output("HTTP/1.0 200 OK\r\n\r\n{\"current_mode\": \"webrtc\"}",
                                                   "HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n#{turn.to_json}"))
      expect(stream.to_h).to eq(mode: "webrtc", relays: [ "turn.cloudflare.com" ])
      expect(stream).to be_cloudflare_turn

      stream = described_class.parse_stream(output("HTTP/1.0 200 OK\r\n\r\n{\"current_mode\": \"websockets\"}", "HTTP/1.0 409 Conflict\r\n\r\n{}"))
      expect(stream.to_h).to eq(mode: "websockets", relays: [])

      expect(described_class.parse_stream("")).to be_nil
    end
  end
end
