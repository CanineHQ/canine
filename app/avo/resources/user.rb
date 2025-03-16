class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    tool Avo::ResourceTools::User, show_on: :index

    field :id, as: :id
    field :email, as: :text
    field :first_name, as: :text
    field :announcements_last_read_at, as: :date_time
    field :admin, as: :boolean
    field :avatar, as: :file
    field :account_users, as: :has_many
    field :accounts, as: :has_many, through: :account_users
    field :owned_accounts, as: :has_many
    field :clusters, as: :has_many, through: :accounts
    field :projects, as: :has_many, through: :accounts
    field :add_ons, as: :has_many, through: :accounts
  end
end
