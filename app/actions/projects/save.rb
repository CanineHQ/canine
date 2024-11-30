class Projects::Save
  extend LightService::Action

  expects :project, :account
  promises :project

  executed do |context|
    ActiveRecord::Base.transaction do
      context.project.save!
      ProjectCredentialProvider.create!(project: context.project, provider: context.account.github_provider)
    end
  end
end
