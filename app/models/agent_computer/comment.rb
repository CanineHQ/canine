# == Schema Information
#
# Table name: agent_computer_comments
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :bigint           not null
#  session_id :bigint
#  user_id    :bigint           not null
#
# Indexes
#
#  index_agent_computer_comments_on_post_id     (post_id)
#  index_agent_computer_comments_on_session_id  (session_id)
#  index_agent_computer_comments_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (post_id => agent_computer_posts.id) ON DELETE => cascade
#  fk_rails_...  (session_id => agent_computer_sessions.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
class AgentComputer::Comment < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :post
  belongs_to :user
  # The follow-up run that acts on it
  belongs_to :session, optional: true

  validates :body, presence: true

  after_create_commit -> { broadcast_append_to [ post.agent_computer, :feed ], target: dom_id(post, :comments), partial: "agent_computers/comments/comment", locals: { comment: self } }

  def act!
    task = post.session.task
    # No window: it acts on the comment, and a scheduled run's next window shouldn't start where this one ended
    run = task.sessions.create!(trigger: :comment, model: task.model)
    update!(session: run)
    AgentSessions::TurnJob.perform_later(run)
    run
  end

  def broadcast_reply
    broadcast_replace_to [ post.agent_computer, :feed ], target: dom_id(self), partial: "agent_computers/comments/comment", locals: { comment: self }
  end
end
