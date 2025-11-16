class ResourceConstraints::Save
  extend LightService::Action

  expects :resource_constraint, :params

  executed do |context|
    # Get params hash
    rc_params = context.params

    # Convert blank strings to nil
    rc_params.each do |key, value|
      rc_params[key] = nil if value.blank?
    end

    # Convert CPU cores to millicores
    if rc_params[:cpu_request].present?
      rc_params[:cpu_request] = (rc_params[:cpu_request].to_f * 1000).to_i
    end

    if rc_params[:cpu_limit].present?
      rc_params[:cpu_limit] = (rc_params[:cpu_limit].to_f * 1000).to_i
    end

    context.resource_constraint.assign_attributes(rc_params)
    context.resource_constraint.save!
  rescue StandardError => e
    context.fail_and_return!(e.message)
  end
end
