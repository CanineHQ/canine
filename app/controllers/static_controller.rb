class StaticController < ApplicationController
  INSTALL_SCRIPT = "curl -sSL https://raw.githubusercontent.com/czhu12/canine/refs/heads/main/install/install.sh | bash"
  skip_before_action :authenticate_user!
  PRICES = [
    {
      name: "Heroku",
      price: 250,
      style: "bg-red-400"
    },
    {
      name: "Fly.io",
      price: 90,
      style: "bg-red-400"
    },
    {
      name: "Render",
      price: 85,
      style: "bg-red-400"
    },
    {
      name: "Digital Ocean",
      price: 24,
      style: "bg-green-400"
    },
    {
      name: "Hetzner",
      price: 4,
      style: "bg-green-400"
    }
  ]

  def index
  end
end
