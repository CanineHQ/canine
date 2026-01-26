class AddSlugToProjects < ActiveRecord::Migration[7.2]
  def up
    add_column :projects, :slug, :string
    Project.find_each do |project|
      project.slug = if Project.exists?(slug: project.name)
        SecureRandom.uuid[0..7]
      else
        project.name
      end
      project.save!(validate: false)
    end

    change_column_null :projects, :slug, false
    add_index :projects, :slug, unique: true
    remove_index :services, :project_id
    add_index :services, [:project_id, :name], unique: true
  end

  def down
    remove_column :projects, :slug
    add_index :services, :project_id
    remove_index :services, [:project_id, :name]
  end
end
