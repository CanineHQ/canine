module AccountUniqueName
  extend ActiveSupport::Concern

  included do
    validate :name_unique_within_account
  end

  private

  def name_unique_within_account
    return unless name.present? && cluster.present?

    existing = self.class.joins(:cluster).where(clusters: { account_id: cluster.account_id }, name: name)
    existing = existing.where.not(id: id) if persisted?
    errors.add(:name, "has already been taken") if existing.exists?
  end
end
