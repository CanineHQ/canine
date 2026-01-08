class Projects::LegacyUninstallService < Projects::BaseUninstallService
  DELETABLE_RESOURCES = %w[ConfigMap Secrets Deployment CronJob Service Ingress Pvc].freeze

  private

  def uninstall_resources
    DELETABLE_RESOURCES.each do |resource_type|
      @logger.info("Deleting all #{resource_type} resources with label caninemanaged=true", color: :yellow)
      @kubectl.call("delete #{resource_type.downcase} -l caninemanaged=true -n #{@project.namespace}")
    end
  end
end
