# frozen_string_literal: true

class AddIndexGoodJobsJobClass < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    reversible do |dir|
      dir.up do
        # Ensure this incremental update migration is idempotent
        # with monolithic install migration.
        return if connection.index_exists? :good_jobs, :job_class
      end
    end

    add_index :good_jobs, :job_class, algorithm: :concurrently
  end
end
