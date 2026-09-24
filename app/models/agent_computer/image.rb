require "rubygems/package"

# The golden disk every agent computer is cloned from, built per cluster from resources/agent_computer/provision.sh
# plus the computer server in resources/agent_computer/computer_server. Versioned by their contents, so editing
# either produces a new image on each cluster's next provision.
class AgentComputer::Image
  NAMESPACE = "canine-agent-computers"
  BASE_IMAGE = "docker://quay.io/containerdisks/ubuntu:24.04"
  PROVISION_SCRIPT = Rails.root.join("resources/agent_computer/provision.sh")
  COMPUTER_SERVER_DIR = Rails.root.join("resources/agent_computer/computer_server")
  DISK_SIZE = "20Gi"
  BUILD_OK = "AGENT_COMPUTER_BUILD_OK"
  BUILD_FAILED = "AGENT_COMPUTER_BUILD_FAILED"

  def self.version
    @version ||= begin
      digest = Digest::SHA256.new
      digest << PROVISION_SCRIPT.read
      computer_server_files.each { |path, content| digest << path << content }
      digest.hexdigest[0, 12]
    end
  end

  # [relative path, content] for every file the server ships, in a stable order
  def self.computer_server_files
    Dir.glob("**/*", base: COMPUTER_SERVER_DIR).sort.filter_map do |path|
      full = COMPUTER_SERVER_DIR.join(path)
      [ path, full.binread ] if full.file? && !path.include?("__pycache__")
    end
  end

  # Gzipped tarball of the server, with fixed metadata so the same files always produce the same bytes
  def self.computer_server_tarball
    tar = StringIO.new
    Gem::Package::TarWriter.new(tar) do |writer|
      computer_server_files.each do |path, content|
        writer.add_file_simple(path, 0o644, content.bytesize) { |io| io.write(content) }
      end
    end
    gzipped = StringIO.new
    gzip = Zlib::GzipWriter.new(gzipped)
    gzip.mtime = 0
    gzip.write(tar.string)
    gzip.close
    gzipped.string
  end

  # DataVolume, PVC and DataSource all share this name
  def self.name
    "agent-computer-#{version}"
  end

  def self.builder_name
    "#{name}-builder"
  end

  def self.namespace_yaml
    {
      "apiVersion" => "v1",
      "kind" => "Namespace",
      "metadata" => { "name" => NAMESPACE, "labels" => { "caninemanaged" => "true" } }
    }.to_yaml
  end

  def self.data_volume_yaml
    {
      "apiVersion" => "cdi.kubevirt.io/v1beta1",
      "kind" => "DataVolume",
      "metadata" => { "name" => name, "namespace" => NAMESPACE },
      "spec" => {
        "source" => { "registry" => { "url" => BASE_IMAGE } },
        # CDI's StorageProfile for local-path has no default access mode, so always spell these out
        "storage" => {
          "accessModes" => [ "ReadWriteOnce" ],
          "volumeMode" => "Filesystem",
          "resources" => { "requests" => { "storage" => DISK_SIZE } }
        }
      }
    }.to_yaml
  end

  # Boots the base image once, runs provision.sh, reports the result on the serial console and powers off.
  # KubeVirt caps inline cloud-init user data at 2KB, so it lives in a Secret.
  def self.builder_user_data
    <<~YAML
      #cloud-config
      write_files:
        - path: /root/provision.sh
          permissions: "0755"
          encoding: b64
          content: #{Base64.strict_encode64(PROVISION_SCRIPT.read)}
        - path: /root/computer_server.tar.gz
          encoding: b64
          content: #{Base64.strict_encode64(computer_server_tarball)}
      runcmd:
        # Not tee'd live: the serial getty starting mid-build hangs up other writers to ttyS0
        - [ bash, -c, "/root/provision.sh > /var/log/agent-computer-provision.log 2>&1; rc=$?; tail -n 40 /var/log/agent-computer-provision.log > /dev/ttyS0; if [ $rc -eq 0 ]; then echo #{BUILD_OK}; else echo #{BUILD_FAILED}; fi > /dev/ttyS0; poweroff" ]
    YAML
  end

  def self.builder_secret_yaml
    {
      "apiVersion" => "v1",
      "kind" => "Secret",
      "metadata" => { "name" => builder_name, "namespace" => NAMESPACE },
      "stringData" => { "userdata" => builder_user_data }
    }.to_yaml
  end

  def self.builder_vm_yaml
    {
      "apiVersion" => "kubevirt.io/v1",
      "kind" => "VirtualMachine",
      "metadata" => { "name" => builder_name, "namespace" => NAMESPACE },
      "spec" => {
        "runStrategy" => "Once",
        "template" => {
          "spec" => {
            "terminationGracePeriodSeconds" => 30,
            "domain" => {
              "cpu" => { "cores" => 2 },
              "memory" => { "guest" => "4Gi" },
              "devices" => {
                "logSerialConsole" => true,
                "disks" => [
                  { "name" => "root", "disk" => { "bus" => "virtio" } },
                  { "name" => "cloudinit", "disk" => { "bus" => "virtio" } }
                ],
                "interfaces" => [ { "name" => "default", "masquerade" => {} } ]
              }
            },
            "networks" => [ { "name" => "default", "pod" => {} } ],
            "volumes" => [
              { "name" => "root", "dataVolume" => { "name" => name } },
              { "name" => "cloudinit", "cloudInitNoCloud" => { "secretRef" => { "name" => builder_name } } }
            ]
          }
        }
      }
    }.to_yaml
  end

  CLONE_ROLE = "agent-computer-image-cloner"

  # Cloning across namespaces is authorized against the VM's service account, which needs to be allowed to use
  # this namespace's disks as a clone source
  def self.clone_role_yaml
    {
      "apiVersion" => "rbac.authorization.k8s.io/v1",
      "kind" => "ClusterRole",
      "metadata" => { "name" => CLONE_ROLE },
      "rules" => [
        { "apiGroups" => [ "cdi.kubevirt.io" ], "resources" => [ "datavolumes/source" ], "verbs" => [ "create" ] },
        { "apiGroups" => [ "cdi.kubevirt.io" ], "resources" => [ "datasources" ], "verbs" => [ "get" ] }
      ]
    }.to_yaml
  end

  # Grants one agent computer's namespace (and nothing else) clone access to the golden image
  def self.clone_role_binding_name(agent_computer)
    "clone-to-#{agent_computer.namespace}"
  end

  def self.clone_role_binding_yaml(agent_computer)
    {
      "apiVersion" => "rbac.authorization.k8s.io/v1",
      "kind" => "RoleBinding",
      "metadata" => { "name" => clone_role_binding_name(agent_computer), "namespace" => NAMESPACE },
      "roleRef" => { "apiGroup" => "rbac.authorization.k8s.io", "kind" => "ClusterRole", "name" => CLONE_ROLE },
      "subjects" => [ { "apiGroup" => "rbac.authorization.k8s.io", "kind" => "Group", "name" => "system:serviceaccounts:#{agent_computer.namespace}" } ]
    }.to_yaml
  end

  def self.data_source_yaml
    {
      "apiVersion" => "cdi.kubevirt.io/v1beta1",
      "kind" => "DataSource",
      "metadata" => { "name" => name, "namespace" => NAMESPACE },
      "spec" => { "source" => { "pvc" => { "name" => name, "namespace" => NAMESPACE } } }
    }.to_yaml
  end
end
