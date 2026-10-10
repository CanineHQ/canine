# frozen_string_literal: true

# Creates or updates a single environment variable on a project.
module Api
  module EnvironmentVariables
    class Upsert
      extend LightService::Action
      expects :project, :user, :params
      promises :environment_variable, :created

      executed do |context|
        params = context.params.to_h.with_indifferent_access
        env_var = context.project.environment_variables.find_or_initialize_by(name: params[:name].to_s.strip.upcase)
        context.created = env_var.new_record?
        env_var.value = params[:value].to_s.strip
        env_var.storage_type = params[:storage_type].presence || "config"
        env_var.current_user = context.user
        context.environment_variable = env_var

        context.fail_and_return!(env_var.errors.full_messages.to_sentence) unless env_var.save

        env_var.events.create!(
          user: context.user,
          event_action: context.created ? :create : :update,
          project: context.project
        )
      end
    end
  end
end
