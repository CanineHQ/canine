class Avo::Resources::User < Avo::BaseResource
  self.includes = [ :accounts, :teams ]
  self.search = {
    query: -> { query.ransack(email_cont: params[:q], first_name_cont: params[:q], last_name_cont: params[:q], m: "or").result(distinct: false) },
    item: -> {
      {
        title: record.name.present? ? "#{record.name} (#{record.email})" : record.email
      }
    }
  }

  def fields
    tool Avo::ResourceTools::User, only_on: :show

    field :id, as: :id
    field :email, as: :text, link_to_record: true
    field :first_name, as: :text
    field :last_name, as: :text
    field :created_at, as: :date_time, sortable: true
    field :avatar, as: :file, only_on: [ :show, :edit ]

    field :accounts, as: :has_many
    field :teams, as: :has_many
    field :clusters, as: :has_many, through: :accounts, only_on: :show
    field :projects, as: :has_many, through: :accounts, only_on: :show
    field :add_ons, as: :has_many, through: :accounts, only_on: :show
  end
end
