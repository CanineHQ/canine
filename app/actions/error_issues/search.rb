# frozen_string_literal: true

module ErrorIssues
  # Narrows a configuration's issues to those whose title or culprit contains the query, or whose short ID matches it
  # (MY-APP-42 or just 42). A blank query returns every issue.
  class Search
    extend LightService::Action

    expects :configuration, :query
    promises :issues

    executed do |context|
      issues = context.configuration.issues
      query = context.query.to_s.strip
      next context.issues = issues if query.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      matches = issues.where("title ILIKE :pattern OR culprit ILIKE :pattern", pattern:)
      number = query.upcase.delete_prefix("#{context.configuration.project.name.upcase}-")
      context.issues = number.match?(/\A\d{1,9}\z/) ? matches.or(issues.where(number: number.to_i)) : matches
    end
  end
end
