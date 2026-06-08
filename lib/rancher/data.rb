class Rancher::Data
  class User
    attr_accessor :id, :username

    def initialize(id:, username:)
      @id = id
      @username = username
    end
  end

  class Cluster
    attr_accessor :id, :name, :state

    def initialize(id:, name:, state:)
      @id = id
      @name = name
      @state = state
    end
  end
end
