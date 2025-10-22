# == Schema Information
#
# Table name: api_tokens
#
#  id           :bigint           not null, primary key
#  access_token :string           not null
#  expires_at   :datetime
#  last_used_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  context "#generate_token" do
    it "generates a random access token on create" do
      api_token = create(:api_token)
      expect(api_token.access_token).not_to be_nil
    end
  end

  context "#expired?" do
    let(:api_token) { create(:api_token, expires_at:) }
    let(:expires_at) { nil }

    context "when expires_at is nil" do
      it "returns false" do
        expect(api_token.expired?).to be_falsey
      end
    end

    context "when expires_at is in the future" do
      let(:expires_at) { 1.day.from_now }

      it "returns false" do
        expect(api_token.expired?).to be_falsey
      end
    end

    context "when expires_at is in the past" do
      let(:expires_at) { 1.day.ago }

      it "returns true" do
        expect(api_token.expired?).to be_truthy
      end
    end
  end
end
