class Projects::Save
  extend LightService::Action

  expects :project, :project_credential_provider
  promises :project

  executed do |context|
    ActiveRecord::Base.transaction do
      context.project.repository_url = context.project.repository_url.strip.downcase
      context.project.save!
      context.project_credential_provider.save!
    end
  rescue => e
    context.fail_and_return!(e.message)
  end
end
