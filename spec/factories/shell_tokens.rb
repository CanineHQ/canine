# == Schema Information
#
# Table name: shell_tokens
#
#  id         :bigint           not null, primary key
#  container  :string
#  expires_at :datetime         not null
#  namespace  :string           not null
#  pod_name   :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_shell_tokens_on_cluster_id  (cluster_id)
#  index_shell_tokens_on_token       (token) UNIQUE
#  index_shell_tokens_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :shell_token do
    user
    cluster
    pod_name { "my-app-pod-abc123" }
    namespace { "default" }
    container { nil }
  end
end
