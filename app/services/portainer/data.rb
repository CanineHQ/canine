class Portainer::Data
  class Registry
    attr_accessor :id, :name, :url, :username, :password, :authentication

    def initialize(id:, name:, url:, username: nil, password: nil, authentication: false)
      @id = id
      @name = name
      @url = url
      @username = username
      @password = password
      @authentication = authentication
    end
  end

  class Endpoint
    attr_accessor :id, :name, :url

    def initialize(id:, name:, url:)
      @id = id
      @name = name
      @url = url
    end
  end
end
