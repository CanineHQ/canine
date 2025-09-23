class Portainer::Data
  class User
    attr_accessor :id, :username, :jwt

    def initialize(id:, username:, jwt:)
      @id = id
      @username = username
      @jwt = jwt
    end
  end

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
