# frozen_string_literal: true

module TeamAccessible
  extend ActiveSupport::Concern

  included do
    has_many :team_resources, as: :resourceable, dependent: :destroy
    has_many :teams, through: :team_resources
  end
end
