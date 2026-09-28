require "rails_helper"

RSpec.describe AgentComputer::Omarchy do
  let(:account_user) { create(:account_user) }
  let(:cluster) { create(:cluster, account: account_user.account) }
  let(:computer) { AgentComputer.create!(name: "desk", cluster:, account_user:) }
  let(:omarchy) { described_class.new(computer) }

  it "builds an unattended install drive and VM for the computer" do
    files = YAML.safe_load(omarchy.cidata_config_map_yaml).fetch("data")
    config = JSON.parse(files["user_configuration.json"])
    credentials = JSON.parse(files["user_credentials.json"])

    expect(config["hostname"]).to eq("desk")
    main = config.dig("disk_config", "device_modifications", 0, "partitions", 1)
    expect(main.dig("start", "value") + main.dig("size", "value")).to be < 60 * 1024**3

    user = credentials["users"].first
    expect(user).to include("username" => AgentComputer::DESKTOP_USER, "sudo" => true)
    expect(user["enc_password"]).to start_with("$2b$")
    expect(BCrypt::Password.new(user["enc_password"].sub("$2b$", "$2a$"))).to eq(computer.password)
    expect(files["authorized_keys"]).to eq("#{computer.ssh_public_key}\n")
    expect(computer.ssh_public_key).to start_with("ecdsa-sha2-nistp256 ")

    vm = YAML.safe_load(omarchy.virtual_machine_yaml({ "app" => "desk" }))
    volumes = vm.dig("spec", "template", "spec", "volumes").to_h { |v| [ v["name"], v ] }
    expect(volumes.dig("cidata", "configMap")).to eq("name" => "desk-cidata", "volumeLabel" => "cidata")
    expect(vm.dig("spec", "dataVolumeTemplates", 0, "spec", "source", "http", "url")).to eq(described_class::ISO_URL)
  end
end
