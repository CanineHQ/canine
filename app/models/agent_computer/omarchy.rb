require "bcrypt"
require "open3"

# How an agent computer's VM is built: Omarchy (Arch Linux + Hyprland) installed unattended from its ISO.
#
# The ISO installs itself without a keyboard when it finds a drive labeled "cidata" holding its configurator's answer
# files (see https://github.com/omacom/omarchy-iso, "Autoinstall"). KubeVirt can present a ConfigMap as exactly such a
# drive. On first boot the empty root disk falls through to the ISO; after the install the VM reboots from the disk.
# Our public key goes in authorized_keys, which also makes the installer enable sshd, so ProvisionJob can log in and
# run resources/agent_computer/omarchy-setup.sh to add the Selkies stream.
class AgentComputer::Omarchy
  VERSION = "4.0.4"
  ISO_URL = "https://iso.omarchy.org/omarchy-#{VERSION}.iso"
  ISO_DISK_SIZE = "8Gi" # the ISO is ~6.2GB
  SETUP_SCRIPT = Rails.root.join("resources/agent_computer/omarchy-setup.sh")
  COMPUTER_USE_SERVER = Rails.root.join("resources/agent_computer/computer_use")
  # Pinned Selkies build for Arch, installed by the setup script
  SELKIES_PACKAGE_URL = "https://github.com/selkies-project/selkies/releases/download/2.0.0/selkies-2.0.0-x86_64.pkg.tar.zst"
  SELKIES_PACKAGE_SHA256 = "39d195ac7acb2924f57cfa564aa97f2ede0d6a5f3c92720c1906142c824a8f74"

  MIB = 1024**2
  GIB = 1024**3

  def initialize(agent_computer)
    @computer = agent_computer
  end

  def cidata_config_map_name = "#{@computer.name}-cidata"

  def cidata_config_map_yaml
    {
      "apiVersion" => "v1",
      "kind" => "ConfigMap",
      "metadata" => { "name" => cidata_config_map_name, "namespace" => @computer.namespace },
      "data" => {
        "user_configuration.json" => JSON.pretty_generate(user_configuration),
        "user_credentials.json" => JSON.pretty_generate(user_credentials),
        "user_full_name.txt" => [ @computer.user.first_name, @computer.user.last_name ].compact_blank.join(" ").presence || @computer.name,
        "user_email_address.txt" => @computer.user.email,
        "user_encrypt_installation.txt" => "false",
        "authorized_keys" => "#{@computer.ssh_public_key}\n"
      }
    }.to_yaml
  end

  def virtual_machine_yaml(labels)
    {
      "apiVersion" => "kubevirt.io/v1",
      "kind" => "VirtualMachine",
      "metadata" => { "name" => @computer.name, "namespace" => @computer.namespace, "labels" => labels.dup },
      "spec" => {
        "runStrategy" => "Always",
        "dataVolumeTemplates" => [
          data_volume("#{@computer.name}-iso", { "http" => { "url" => ISO_URL } }, ISO_DISK_SIZE),
          data_volume("#{@computer.name}-root", { "blank" => {} }, AgentComputer::DISK_SIZE)
        ],
        "template" => {
          "metadata" => { "labels" => labels.dup },
          "spec" => {
            "terminationGracePeriodSeconds" => 30,
            "domain" => {
              "firmware" => { "bootloader" => { "efi" => { "secureBoot" => false } } },
              "cpu" => { "cores" => AgentComputer::CPU_CORES, "model" => "host-passthrough" },
              "memory" => { "guest" => AgentComputer::MEMORY },
              "devices" => {
                "video" => { "type" => "virtio" },
                # An absolute pointer, so the VNC view's clicks land where you click
                "inputs" => [ { "type" => "tablet", "bus" => "usb", "name" => "tablet" } ],
                "logSerialConsole" => true,
                # Empty on first boot, so the firmware falls through to the ISO; the installed system boots after that
                "disks" => [
                  { "name" => "root", "bootOrder" => 1, "disk" => { "bus" => "virtio" } },
                  { "name" => "iso", "bootOrder" => 2, "cdrom" => { "bus" => "sata", "readonly" => true } },
                  { "name" => "cidata", "disk" => { "bus" => "usb" } }
                ],
                "interfaces" => [ { "name" => "default", "masquerade" => {} } ]
              }
            },
            "networks" => [ { "name" => "default", "pod" => {} } ],
            "volumes" => [
              { "name" => "root", "dataVolume" => { "name" => "#{@computer.name}-root" } },
              { "name" => "iso", "dataVolume" => { "name" => "#{@computer.name}-iso" } },
              { "name" => "cidata", "configMap" => { "name" => cidata_config_map_name, "volumeLabel" => "cidata" } }
            ]
          }
        }
      }
    }.to_yaml
  end

  # Environment for omarchy-setup.sh
  def setup_environment
    {
      "SETUP_PASSWORD" => @computer.password,
      "DESKTOP_PORT" => AgentComputer::DESKTOP_PORT.to_s,
      "COMPUTER_USE_PORT" => AgentComputer::COMPUTER_USE_PORT.to_s,
      "SELKIES_PACKAGE_URL" => SELKIES_PACKAGE_URL,
      "SELKIES_PACKAGE_SHA256" => SELKIES_PACKAGE_SHA256
    }.merge(turn_environment)
  end

  # Cloudflare TURN credentials for Selkies' WebRTC transport, from the Canine deployment's env. When unset, the setup
  # script leaves Selkies on its WebSocket transport, so this is optional infrastructure.
  def turn_environment
    id = ENV["CLOUDFLARE_TURN_TOKEN_ID"]
    token = ENV["CLOUDFLARE_TURN_API_TOKEN"]
    return {} if id.blank? || token.blank?

    { "CLOUDFLARE_TURN_TOKEN_ID" => id, "CLOUDFLARE_TURN_API_TOKEN" => token }
  end

  # The computer-use server's Python project (pyproject.toml and the package) as a .tar.gz, which the setup unpacks
  # into ~/.local/share/canine/computer_use and pip-installs
  def self.computer_use_archive
    archive, status = Open3.capture2("tar", "-czf", "-", "--exclude=__pycache__", "--exclude=build", "--exclude=*.egg-info",
                                     "-C", COMPUTER_USE_SERVER.dirname.to_s, COMPUTER_USE_SERVER.basename.to_s, binmode: true)
    raise "Couldn't archive #{COMPUTER_USE_SERVER}" unless status.success?

    archive
  end

  private

  # CDI's StorageProfile for local-path has no default access mode, so always spell these out
  def data_volume(name, source, size)
    {
      "metadata" => { "name" => name },
      "spec" => {
        "source" => source,
        "storage" => { "accessModes" => [ "ReadWriteOnce" ], "volumeMode" => "Filesystem", "resources" => { "requests" => { "storage" => size } } }
      }
    }
  end

  # Libxcrypt reads $2b$ bcrypt hashes; the gem writes the equivalent $2a$ prefix
  def password_hash
    BCrypt::Password.create(@computer.password).to_s.sub(/\A\$2a\$/, "$2b$")
  end

  def user_credentials
    {
      "root_enc_password" => password_hash,
      "users" => [ { "username" => AgentComputer::DESKTOP_USER, "enc_password" => password_hash, "sudo" => true, "groups" => [] } ]
    }
  end

  # The configurator's own output format (archinstall), for a full-disk install on the VM's virtio disk
  def user_configuration
    disk = AgentComputer::DISK_SIZE.delete_suffix("Gi").to_i * GIB - 64 * MIB # stay a little under the disk size
    boot_start = MIB
    boot_size = 2 * GIB
    main_start = boot_start + boot_size
    {
      "app_config" => nil,
      "archinstall-language" => "English",
      "auth_config" => {},
      "audio_config" => { "audio" => "pipewire" },
      "bootloader_config" => { "bootloader" => "Limine", "uki" => false, "removable" => false },
      "custom_commands" => [],
      "omarchy_install" => {
        "mode" => "full_disk", "defer_provisioning" => false, "target_mount" => "/mnt",
        "boot" => { "esp_mount" => "/boot", "esp_path" => "/EFI/limine", "efi_binary" => "limine_x64.efi", "enable_fallback" => true },
        "storage" => { "kernel" => "linux-omarchy" }
      },
      "disk_config" => {
        "config_type" => "default_layout",
        "device_modifications" => [ {
          "device" => "/dev/vda",
          "wipe" => true,
          "partitions" => [
            partition(boot_start, boot_size, "fat32", mountpoint: "/boot", flags: %w[boot esp]),
            partition(main_start, disk - main_start - MIB, "btrfs", mount_options: [ "compress=zstd" ], btrfs: [
              { "mountpoint" => "/", "name" => "@" }, { "mountpoint" => "/home", "name" => "@home" },
              { "mountpoint" => "/var/log", "name" => "@log" }, { "mountpoint" => "/var/cache/pacman/pkg", "name" => "@pkg" }
            ])
          ]
        } ]
      },
      "hostname" => @computer.name,
      "kernels" => [ "linux-omarchy" ],
      "network_config" => { "type" => "iso" },
      "ntp" => true,
      "parallel_downloads" => 8,
      "script" => nil,
      "services" => [],
      "swap" => true,
      "timezone" => "UTC",
      "locale_config" => { "kb_layout" => "us", "sys_enc" => "UTF-8", "sys_lang" => "en_US.UTF-8" },
      "mirror_config" => {
        "custom_repositories" => [], "mirror_regions" => {}, "optional_repositories" => [],
        "custom_servers" => [
          { "url" => "https://mirror.omarchy.org/$repo/os/$arch" },
          { "url" => "https://mirror.rackspace.com/archlinux/$repo/os/$arch" },
          { "url" => "https://geo.mirror.pkgbuild.com/$repo/os/$arch" }
        ]
      },
      "packages" => %w[base-devel git omarchy-keyring omarchy-settings omarchy],
      "profile_config" => { "gfx_driver" => nil, "greeter" => nil, "profile" => {} },
      "version" => "3.0.9"
    }
  end

  def partition(start, size, fs_type, mountpoint: nil, flags: [], mount_options: [], btrfs: [])
    bytes = ->(value) { { "sector_size" => { "unit" => "B", "value" => 512 }, "unit" => "B", "value" => value } }
    {
      "btrfs" => btrfs, "dev_path" => nil, "flags" => flags, "fs_type" => fs_type, "mount_options" => mount_options,
      "mountpoint" => mountpoint, "obj_id" => SecureRandom.uuid, "size" => bytes.(size), "start" => bytes.(start),
      "status" => "create", "type" => "primary"
    }
  end
end
