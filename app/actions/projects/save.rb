class Projects::Save
  extend LightService::Action

  expects :project, :user
  promises :project

  executed do |context|
    ActiveRecord::Base.transaction do
      context.project.repository_url = context.project.repository_url.strip.downcase
      context.project.save!
      ProjectCredentialProvider.create!(project: context.project, provider: context.user.github_provider)
    end
  rescue => e
    context.fail_and_return!(e.message)
  end
end
