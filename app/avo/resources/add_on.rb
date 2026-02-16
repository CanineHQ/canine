class Avo::Resources::AddOn < Avo::BaseResource
  self.includes = [ :cluster ]
  self.search = {
    query: -> { query.ransack(name_cont: params[:q], chart_url_cont: params[:q], m: "or").result(distinct: false) },
    item: -> {
      {
        title: record.name
      }
    }
  }

  def fields
    field :id, as: :id
    field :logo, as: :external_image, link_to_record: true, only_on: [ :index, :show ] do
      record.chart_definition&.dig("logo")
    end
    field :name, as: :text, link_to_record: true
    field :chart_url, as: :text, name: "Chart"
    field :version, as: :text
    field :status, as: :badge, options: { success: [ :installed ], warning: [ :installing, :updating, :uninstalling ], danger: [ :failed, :uninstalled ] }
    field :namespace, as: :text
    field :cluster, as: :belongs_to
    field :chart_url, as: :text, only_on: [ :show ]
    field :created_at, as: :date_time, sortable: true
  end
end
