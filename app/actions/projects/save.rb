class Projects::Save
  extend LightService::Action

  expects :project, :user
  promises :project

  executed do |context|
    ActiveRecord::Base.transaction do
      context.project.save!
      ProjectCredentialProvider.create!(project: context.project, provider: context.user.github_provider)
    end
  end
end
