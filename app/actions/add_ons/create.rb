class AddOns::Create
  def self.parse_params(params)
    if params[:add_on][:values_yaml].present?
      params[:add_on][:values] = YAML.safe_load(params[:add_on][:values_yaml])
    end
    if params[:add_on][:metadata].present?
      params[:add_on][:metadata] = params[:add_on][:metadata][params[:add_on][:chart_type]]
    end
    params.require(:add_on).permit(
      :cluster_id,
      :chart_type,
      :chart_url,
      :name,
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

  def self.call(add_on)
    with(add_on:).reduce(
      AddOns::ApplyTemplateToValues,
      AddOns::SetPackageDetails,
      AddOns::Save
    )
  end
end
