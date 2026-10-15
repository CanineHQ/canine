# == Schema Information
#
# Table name: error_tracking_configurations
#
#  id                :bigint           not null, primary key
#  last_issue_number :integer          default(0), not null
#  public_key        :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :bigint           not null
#
# Indexes
#
#  index_error_tracking_configurations_on_project_id  (project_id) UNIQUE
#  index_error_tracking_configurations_on_public_key  (public_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
# Present while a project has error tracking enabled. Holds the public key of the project's Sentry-compatible DSN
# and owns everything reported to it.
class ErrorTrackingConfiguration < ApplicationRecord
  belongs_to :project
  has_many :issues, class_name: "ErrorTracking::Issue", dependent: :delete_all

  validates :project_id, uniqueness: true

  before_validation :generate_public_key, on: :create

  # https://<public_key>@<host>/<id>; Sentry SDKs require the trailing project id to be numeric.
  def dsn(base_url)
    uri = URI.parse(base_url)
    uri.userinfo = public_key
    uri.path = "/#{id}"
    uri.to_s
  end

  # Issues are numbered per project (HELLO-WORLD-1, HELLO-WORLD-2, ...). The increment locks this row until the
  # surrounding transaction ends, so concurrent ingests never hand out the same number. exec_query bypasses the query
  # cache, which would otherwise answer a repeat of this identical statement without running it.
  def next_issue_number!
    self.class.connection.exec_query(self.class.sanitize_sql_array([
      "UPDATE error_tracking_configurations SET last_issue_number = last_issue_number + 1 WHERE id = ? RETURNING last_issue_number", id
    ])).rows.first.first
  end

  def regenerate_public_key!
    update!(public_key: SecureRandom.hex(16))
  end

  private

  def generate_public_key
    self.public_key ||= SecureRandom.hex(16)
  end
end
