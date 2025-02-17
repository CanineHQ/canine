# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Users" do
          h3 "Total Users: #{User.count}"
          h3 "Recent Users"
          ul do
            User.order(created_at: :desc).limit(5).map do |user|
              li link_to(user.email, admin_user_path(user))
            end
          end
        end
      end

      column do
        panel "Recent Projects" do
          ul do
            Project.order(created_at: :desc).limit(5).map do |project|
              li link_to(project.name, admin_project_path(project))
            end
          end
        end
      end
    end
  end # content
end
