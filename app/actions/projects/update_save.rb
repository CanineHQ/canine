# frozen_string_literal: true

module Projects
  class UpdateSave
    extend LightService::Action

    expects :project, :params, :build_configuration
    promises :project

    executed do |context|
      ActiveRecord::Base.transaction do
        # Update project with permitted params
        context.project.assign_attributes(Projects::Create.create_params(context.params))
        context.project.repository_url = context.project.repository_url.strip.downcase if context.project.repository_url_changed?
        context.project.save!

        # Save build configuration if present
        context.build_configuration&.save!
      end
    rescue => e
      context.fail_and_return!(e.message)
    end
  end
end
