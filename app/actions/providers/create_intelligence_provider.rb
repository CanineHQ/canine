class Providers::CreateIntelligenceProvider
  extend LightService::Action

  expects :provider
  promises :provider

  executed do |context|
    provider = context.provider

    if provider.access_token.blank?
      provider.errors.add(:access_token, "can't be blank")
      context.fail_and_return!("Access token is required")
      next
    end

    provider.auth = {
      info: {
        nickname: provider.provider.titleize
      }
    }.to_json

    provider.save!
  rescue ActiveRecord::RecordInvalid => e
    context.fail_and_return!(e.message)
  end
end
