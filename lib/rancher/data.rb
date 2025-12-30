# frozen_string_literal: true

class Rancher::Data
  class User
    attr_accessor :id, :username, :principal_ids

    def initialize(id:, username:, principal_ids: [])
      @id = id
      @username = username
      @principal_ids = principal_ids
    end
  end

  class Cluster
    attr_accessor :id, :name, :state, :provider, :kubernetes_version

    def initialize(id:, name:, state:, provider: nil, kubernetes_version: nil)
      @id = id
      @name = name
      @state = state
      @provider = provider
      @kubernetes_version = kubernetes_version
    end

    def active?
      state == "active"
    end
  end

  class Catalog
    attr_accessor :id, :name, :url, :branch, :catalog_type

    def initialize(id:, name:, url:, branch: nil, catalog_type: "helm")
      @id = id
      @name = name
      @url = url
      @branch = branch
      @catalog_type = catalog_type
    end
  end
end
