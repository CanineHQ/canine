# == Schema Information
#
# Table name: agent_computer_reactions
#
#  id         :bigint           not null, primary key
#  tag        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_agent_computer_reactions_on_post_id              (post_id)
#  index_agent_computer_reactions_on_post_id_and_user_id  (post_id,user_id) UNIQUE
#  index_agent_computer_reactions_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (post_id => agent_computer_posts.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
class AgentComputer::Reaction < ApplicationRecord
  # tag => [label, icon, color]; the first is what a plain click on the button gives, like a Like
  TAGS = {
    "useful" => [ "Useful", "lucide:thumbs-up", "text-info" ],
    "important" => [ "Important", "lucide:star", "text-warning" ],
    "not_needed" => [ "Not needed", "lucide:eye-off", "text-base-content/70" ],
    "wrong" => [ "Wrong", "lucide:circle-x", "text-error" ]
  }.freeze
  DEFAULT = TAGS.keys.first

  belongs_to :post
  belongs_to :user

  validates :tag, inclusion: { in: TAGS.keys }

  def label = TAGS[tag][0]
  def icon = TAGS[tag][1]
  def color = TAGS[tag][2]
end
