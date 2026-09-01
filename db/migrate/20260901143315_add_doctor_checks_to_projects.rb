class AddDoctorChecksToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :doctor_checks, :jsonb
  end
end
