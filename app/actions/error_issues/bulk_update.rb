# frozen_string_literal: true

module ErrorIssues
  # Applies a bulk action to the checked issues within the given scope (one status tab, possibly searched), or to every
  # issue in it when all_matching.
  class BulkUpdate
    extend LightService::Action

    ACTIONS = %w[resolved unresolved ignored delete].freeze

    expects :issues, :bulk_action, :ids, :all_matching
    promises :updated_count

    executed do |context|
      context.fail_and_return!("Unknown action.") unless ACTIONS.include?(context.bulk_action)

      scope = context.issues
      scope = scope.where(id: Array(context.ids)) unless context.all_matching
      context.updated_count = if context.bulk_action == "delete"
        scope.delete_all
      else
        scope.update_all(status: context.bulk_action, updated_at: Time.current)
      end
    end
  end
end
