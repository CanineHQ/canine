class EnvironmentVariables::BulkUpdate
  extend LightService::Action

  expects :project, :params
  expects :current_user, default: nil

  executed do |context|
    project = context.project
    ActiveRecord::Base.transaction do
      env_variable_data = context.params[:environment_variables] || []

      incoming_ids = env_variable_data.filter_map { |ev| ev[:id].presence&.to_i }
      incoming_variable_names = env_variable_data.map { |ev| ev[:name] }

      # Destroy variables not in the incoming data (by ID if available, fallback to name)
      destroy_scope = project.environment_variables
      destroy_scope = destroy_scope.where.not(id: incoming_ids) if incoming_ids.any?
      destroy_scope.where.not(name: incoming_variable_names).destroy_all

      current_vars = project.environment_variables.to_a
      vars_by_id = current_vars.index_by(&:id)
      vars_by_name = current_vars.index_by(&:name)

      env_variable_data.each do |ev|
        next if ev[:name].blank?

        existing = vars_by_id[ev[:id].to_i] if ev[:id].present?
        existing ||= vars_by_name[ev[:name]]

        if existing
          update_attrs = {}
          update_attrs[:name] = ev[:name].strip.upcase if ev[:name].strip.upcase != existing.name

          if ev[:keep_existing_value] == "true"
            # Don't update value
          else
            update_attrs[:value] = ev[:value].strip if ev[:value] != existing.value
          end

          update_attrs[:storage_type] = ev[:storage_type] if ev[:storage_type] && ev[:storage_type] != existing.storage_type

          if update_attrs.any?
            existing.update!(
              **update_attrs,
              current_user: context.current_user
            )
            existing.events.create!(
              user: context.current_user,
              event_action: :update,
              project: project
            )
          end
        else
          project.environment_variables.create!(
            name: ev[:name].strip.upcase,
            value: ev[:value].strip,
            storage_type: ev[:storage_type] || :config,
            current_user: context.current_user
          )
          # eventable automatically creates an event
        end
      end
    end
  rescue => e
    context.fail!(e.message)
  end
end
