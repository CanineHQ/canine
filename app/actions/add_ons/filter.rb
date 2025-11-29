# frozen_string_literal: true

module AddOns
  class Filter
    extend LightService::Action

    expects :params, :add_ons
    promises :add_ons

    executed do |context|
      query = context.params[:q].to_s.strip

      if query.present?
        context.add_ons = context.add_ons.where("add_ons.name ILIKE ?", "%#{query}%")
      end
    end
  end
end
