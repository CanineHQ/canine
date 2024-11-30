class Projects::Save
  extend LightService::Action

  expects :project, :account
  promises :project

  executed do |context|
    context.project.save!
    ProjectCredentialProvider.new(project: context.project, provider: context.account.github_account)
  end
end
