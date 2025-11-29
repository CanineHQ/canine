# frozen_string_literal: true

module Projects
  class Filter
    extend LightService::Action

    expects :params, :projects
    promises :projects

    executed do |context|
      query = context.params[:q].to_s.strip

      if query.present?
        context.projects = context.projects.where("projects.name ILIKE ?", "%#{query}%")
      end
    end
  end
end
