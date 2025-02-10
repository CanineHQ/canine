# == Schema Information
#
# Table name: log_outputs
#
#  id            :bigint           not null, primary key
#  loggable_type :string           not null
#  output        :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  loggable_id   :bigint           not null
#
class LogOutput < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :loggable, polymorphic: true

  after_create_commit :broadcast_log_output

  private

  def broadcast_log_output
    broadcast_append_later_to dom_id(loggable, :logs), target: dom_id(loggable, :logs), partial: "log_outputs/log_line", locals: { log_output: self }
  end
end
