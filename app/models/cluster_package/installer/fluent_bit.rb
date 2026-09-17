class ClusterPackage::Installer::FluentBit < ClusterPackage::Installer::Base
  private

  def build_values
    config = package.config || {}
    aws_region = config["aws_region"] || "us-east-1"
    log_group = config["log_group"] || "/canine/cluster-logs"
    aws_access_key_id = config["aws_access_key_id"]
    aws_secret_access_key = config["aws_secret_access_key"]

    {
      "env" => [
        { "name" => "AWS_ACCESS_KEY_ID", "value" => aws_access_key_id },
        { "name" => "AWS_SECRET_ACCESS_KEY", "value" => aws_secret_access_key }
      ],
      "config" => {
        "inputs" => <<~CONF,
          [INPUT]
              Name              tail
              Tag               kube.*
              Path              /var/log/containers/*.log
              Parser            cri
              DB                /var/log/flb_kube.db
              Mem_Buf_Limit     5MB
              Skip_Long_Lines   On
              Refresh_Interval  10
        CONF
        "filters" => <<~CONF,
          [FILTER]
              Name                kubernetes
              Match               kube.*
              Kube_URL            https://kubernetes.default.svc:443
              Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
              Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
              Merge_Log           On
              K8S-Logging.Parser  On
              K8S-Logging.Exclude On
        CONF
        "outputs" => <<~CONF
          [OUTPUT]
              Name                cloudwatch_logs
              Match               kube.*
              region              #{aws_region}
              log_group_name      #{log_group}
              log_stream_prefix   fluentbit-
              auto_create_group   true
        CONF
      }
    }
  end
end
