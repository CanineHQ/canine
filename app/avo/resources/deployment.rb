class Avo::Resources::Deployment < Avo::BaseResource
  def fields
    field :id, as: :id
    # Generated fields from model
    field :status, as: :select, options: Deployment.statuses.keys.map { |status| [ status.humanize, status ] }
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
    field :project, as: :belongs_to

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
