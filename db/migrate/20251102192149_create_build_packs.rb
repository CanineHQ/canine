class CreateBuildPacks < ActiveRecord::Migration[7.2]
  def change
    create_table :build_packs do |t|
      t.references :build_configuration, null: false, foreign_key: true
      t.string :reference_type, null: false # registry, docker, git, url, path
      t.string :namespace # for registry buildpacks
      t.string :name # for registry buildpacks
      t.string :version
      t.text :uri # for git, url, path, or docker references
      t.jsonb :details, default: {}

      t.timestamps
    end

    add_index :build_packs, [ :build_configuration_id, :reference_type, :namespace, :name ], name: 'index_build_packs_on_config_type_namespace_name'
    add_index :build_packs, [ :build_configuration_id, :uri ], name: 'index_build_packs_on_config_uri'
  end
end
