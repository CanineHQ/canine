class Projects::LegacyUninstallService < Projects::BaseUninstallService
  DELETABLE_RESOURCES = %w[ConfigMap Secrets Deployment CronJob Service HTTPRoute Certificate ReferenceGrant Pvc].freeze

  private

  def uninstall_resources
    cleanup_gateway_certificate_refs

    DELETABLE_RESOURCES.each do |resource_type|
      @logger.info("Deleting all #{resource_type} resources with label caninemanaged=true", color: :yellow)
      @kubectl.call("delete #{resource_type.downcase} -l caninemanaged=true -n #{@project.namespace}")
    end
  end

  def cleanup_gateway_certificate_refs
    gateway_manager = K8::Shared::GatewayManager.new.connect(@connection)
    @project.services.each do |service|
      gateway_manager.remove_certificate_ref(service)
    rescue StandardError => e
      @logger.error("Failed to remove certificate ref for #{service.name}: #{e.message}")
    end
  rescue StandardError => e
    @logger.error("Failed to cleanup gateway certificate refs: #{e.message}")
  end
end
