class AddOns::Create
  def self.parse_params(params)
    if params[:add_on][:values_yaml].present?
      params[:add_on][:values] = YAML.safe_load(params[:add_on][:values_yaml])
    end
    if params[:add_on][:metadata].present? && params[:add_on][:chart_url].present?
      chart_name = params[:add_on][:chart_url].split('/').last
      params[:add_on][:metadata] = params[:add_on][:metadata][chart_name]
    end
    params.require(:add_on).permit(
      :cluster_id,
      :chart_url,
      :name,
      :version,
      :repository_url,
      :artifact_hub_package_id,
      metadata: {},
      values: {}
    )
  end

  class ToNamespaced
    extend LightService::Action
    expects :add_on
    promises :namespaced
    executed do |context|
      context.namespaced = context.add_on
    end
  end

  extend LightService::Organizer

  def self.call(add_on, user)
    with(add_on:, user:).reduce(
      AddOns::Create::ToNamespaced,
      Namespaced::SetUpNamespace,
      Namespaced::ValidateNamespace,
      AddOns::ApplyTemplateToValues,
      AddOns::SetPackageDetails,
      AddOns::Save
    )
  end
end
