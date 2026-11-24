class Clusters::Update
  extend LightService::Organizer

  def self.call(cluster, params, user)
    attributes = begin
      Clusters::ParseParams.parse_params(params)
    rescue Clusters::ParseParams::InvalidParams => e
      cluster.errors.add(:base, e.message)
      return LightService::Context.make(cluster:, user:).tap { |context| context.fail!(e.message) }
    end
    # The import field is empty unless a new kubeconfig is being imported.
    attributes.delete(:kubeconfig) if attributes[:kubeconfig].blank?
    cluster.assign_attributes(attributes)
    recipe = if attributes.key?(:kubeconfig)
      [ Clusters::ValidateKubeConfig, Clusters::BootstrapServiceAccount, Clusters::Save ]
    else
      [ Clusters::Save ]
    end
    with(cluster:, user:).reduce(recipe)
  end
end
