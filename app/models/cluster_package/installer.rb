module ClusterPackage::Installer
  REGISTRY = {
    "nginx-ingress" => "ClusterPackage::Installer::NginxIngress",
    "cert-manager" => "ClusterPackage::Installer::CertManager",
    "metrics-server" => "ClusterPackage::Installer::MetricsServer",
    "telepresence" => "ClusterPackage::Installer::Telepresence",
    "cloudflared" => "ClusterPackage::Installer::Cloudflared"
  }.freeze

  def self.for(package)
    class_name = REGISTRY[package.name]
    klass = class_name ? class_name.constantize : Base
    klass.new(package)
  end
end
