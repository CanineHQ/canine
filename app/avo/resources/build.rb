class Avo::Resources::Build < Avo::BaseResource
  self.visible_on_sidebar = false
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :project, as: :belongs_to
    field :status, as: :select, enum: ::Build.statuses
    field :deployment, as: :has_one
    field :created_at, as: :date_time
    field :repository_url, as: :text
    field :git_sha, as: :text
    field :commit_sha, as: :text
    field :commit_message, as: :text, format_using: -> { value.truncate 30 }

    field :logs, as: :code, language: "shell", theme: "dracula" do
      lines = record.log_outputs.order(:created_at).pluck(:output).map { |o| o.gsub(/\e\[\d+m/, "") }
      if view == :show
        lines.join("\n")
      else
        lines.last(20).join("\n")
      end
    end
  end
end
