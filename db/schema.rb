# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_09_02_182502) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.bigint "owner_id"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "add_ons", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.string "name", null: false
    t.string "chart_type", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "values", default: {}
    t.string "chart_url"
    t.index ["cluster_id", "name"], name: "index_add_ons_on_cluster_id_and_name", unique: true
    t.index ["cluster_id"], name: "index_add_ons_on_cluster_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.datetime "published_at"
    t.string "announcement_type"
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "build_clouds", force: :cascade do |t|
    t.bigint "cluster_id", null: false
    t.string "namespace", default: "canine-k8s-builder", null: false
    t.integer "status", default: 0, null: false
    t.string "driver_version"
    t.string "webhook_url"
    t.jsonb "installation_metadata", default: {}
    t.datetime "installed_at"
    t.text "error_message"
    t.integer "replicas", default: 2
    t.bigint "cpu_requests", default: 500
    t.bigint "cpu_limits", default: 2000
    t.bigint "memory_requests", default: 536870912
    t.bigint "memory_limits", default: 4294967296
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_build_clouds_on_cluster_id"
  end

  create_table "build_configurations", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "driver", null: false
    t.bigint "build_cloud_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "provider_id", null: false
    t.string "image_repository", null: false
    t.index ["build_cloud_id"], name: "index_build_configurations_on_build_cloud_id"
    t.index ["project_id"], name: "index_build_configurations_on_project_id"
    t.index ["provider_id"], name: "index_build_configurations_on_provider_id"
  end

  create_table "builds", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "repository_url"
    t.string "git_sha"
    t.string "commit_message"
    t.integer "status", default: 0
    t.string "commit_sha", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_builds_on_project_id"
  end

  create_table "clusters", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "kubeconfig", default: {}
    t.bigint "account_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cluster_type", default: 0
    t.string "external_id"
    t.index ["account_id", "name"], name: "index_clusters_on_account_id_and_name", unique: true
  end

  create_table "cron_schedules", force: :cascade do |t|
    t.bigint "service_id", null: false
    t.string "schedule", null: false
    t.index ["service_id"], name: "index_cron_schedules_on_service_id"
  end

  create_table "deployments", force: :cascade do |t|
    t.bigint "build_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["build_id"], name: "index_deployments_on_build_id"
  end

  create_table "domains", force: :cascade do |t|
    t.bigint "service_id", null: false
    t.string "domain_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0
    t.string "status_reason"
    t.index ["service_id"], name: "index_domains_on_service_id"
  end

  create_table "environment_variables", force: :cascade do |t|
    t.string "name", null: false
    t.text "value"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_environment_variables_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_environment_variables_on_project_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "project_id", null: false
    t.string "eventable_type", null: false
    t.bigint "eventable_id", null: false
    t.integer "event_action", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
    t.index ["project_id"], name: "index_events_on_project_id"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "inbound_webhooks", force: :cascade do |t|
    t.text "body"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "log_outputs", force: :cascade do |t|
    t.bigint "loggable_id", null: false
    t.string "loggable_type", null: false
    t.text "output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "metrics", force: :cascade do |t|
    t.integer "metric_type", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "tags", default: [], null: false, array: true
    t.bigint "cluster_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cluster_id"], name: "index_metrics_on_cluster_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.string "type"
    t.string "record_type"
    t.bigint "record_id"
    t.jsonb "params"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "notifications_count"
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.string "type"
    t.bigint "event_id", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.datetime "read_at", precision: nil
    t.datetime "seen_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "project_add_ons", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "add_on_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["add_on_id"], name: "index_project_add_ons_on_add_on_id"
    t.index ["project_id"], name: "index_project_add_ons_on_project_id"
  end

  create_table "project_credential_providers", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "provider_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "provider_id"], name: "idx_on_project_id_provider_id_92125f73e5", unique: true
    t.index ["project_id"], name: "index_project_credential_providers_on_project_id"
    t.index ["provider_id"], name: "index_project_credential_providers_on_provider_id"
  end

  create_table "project_forks", force: :cascade do |t|
    t.bigint "child_project_id", null: false
    t.bigint "parent_project_id", null: false
    t.string "external_id", null: false
    t.string "number", null: false
    t.string "title", null: false
    t.string "url", null: false
    t.string "user", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_project_id"], name: "index_project_forks_on_child_project_id", unique: true
    t.index ["parent_project_id"], name: "index_project_forks_on_parent_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "repository_url", null: false
    t.string "branch", default: "main", null: false
    t.bigint "cluster_id", null: false
    t.boolean "autodeploy", default: true, null: false
    t.string "dockerfile_path", default: "./Dockerfile", null: false
    t.string "docker_build_context_directory", default: ".", null: false
    t.string "docker_command"
    t.text "predeploy_command"
    t.integer "status", default: 0, null: false
    t.jsonb "canine_config", default: {}
    t.text "postdeploy_command"
    t.text "predestroy_command"
    t.text "postdestroy_command"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "container_registry_url"
    t.bigint "project_fork_cluster_id"
    t.integer "project_fork_status", default: 0
    t.index ["cluster_id"], name: "index_projects_on_cluster_id"
  end

  create_table "providers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider"
    t.string "uid"
    t.string "access_token"
    t.string "access_token_secret"
    t.string "refresh_token"
    t.datetime "expires_at"
    t.text "auth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at"
    t.string "registry_url"
    t.index ["user_id"], name: "index_providers_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "service_type", null: false
    t.string "command"
    t.string "name", null: false
    t.integer "replicas", default: 1
    t.string "healthcheck_url"
    t.boolean "allow_public_networking", default: false
    t.integer "status", default: 0
    t.datetime "last_health_checked_at"
    t.integer "container_port", default: 3000
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.index ["project_id"], name: "index_services_on_project_id"
  end

  create_table "stack_managers", force: :cascade do |t|
    t.string "provider_url", null: false
    t.integer "stack_manager_type", default: 0, null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_stack_managers_on_account_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.datetime "announcements_last_read_at"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "volumes", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "size", default: "10Gi", null: false
    t.integer "access_mode", default: 0
    t.string "mount_path", default: "/volumes/data", null: false
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "mount_path"], name: "index_volumes_on_project_id_and_mount_path", unique: true
    t.index ["project_id", "name"], name: "index_volumes_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_volumes_on_project_id"
  end

  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "add_ons", "clusters"
  add_foreign_key "build_clouds", "clusters"
  add_foreign_key "build_configurations", "build_clouds"
  add_foreign_key "build_configurations", "projects"
  add_foreign_key "build_configurations", "providers"
  add_foreign_key "builds", "projects"
  add_foreign_key "clusters", "accounts"
  add_foreign_key "cron_schedules", "services"
  add_foreign_key "deployments", "builds"
  add_foreign_key "environment_variables", "projects"
  add_foreign_key "project_add_ons", "add_ons"
  add_foreign_key "project_add_ons", "projects"
  add_foreign_key "project_credential_providers", "projects"
  add_foreign_key "project_credential_providers", "providers"
  add_foreign_key "project_forks", "projects", column: "child_project_id"
  add_foreign_key "project_forks", "projects", column: "parent_project_id"
  add_foreign_key "projects", "clusters"
  add_foreign_key "projects", "clusters", column: "project_fork_cluster_id"
  add_foreign_key "providers", "users"
  add_foreign_key "services", "projects"
  add_foreign_key "stack_managers", "accounts"
  add_foreign_key "volumes", "projects"
end
