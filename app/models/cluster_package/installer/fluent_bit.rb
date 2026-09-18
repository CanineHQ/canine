class ClusterPackage::Installer::FluentBit < ClusterPackage::Installer::Base
  private

  def build_values
    config = package.config || {}
    aws_region = config["aws_region"] || "us-east-1"
    log_group = config["log_group"] || "/canine/cluster-logs"
    aws_access_key_id = config["aws_access_key_id"]
    aws_secret_access_key = config["aws_secret_access_key"]

    template = Rails.root.join("resources/helm/values/fluent-bit.yaml.erb").read
    yaml = ERB.new(template).result(binding)
    YAML.safe_load(yaml)
  end
end
