class CreateProjectCredentialProviders < ActiveRecord::Migration[7.2]
  def change
    create_table :project_credential_providers do |t|
      t.references :project, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true

      t.timestamps
    end
    add_index :project_credential_providers, [:project_id, :provider_id], unique: true
    Project.all.each do |project|
      ProjectCredentialProvider.create!(project:, provider: project.account.github_provider)
    end
  end
end
