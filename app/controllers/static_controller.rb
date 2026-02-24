class StaticController < ApplicationController
  INSTALL_SCRIPT = "curl -sSL https://canine.sh/install.sh | bash"
  MAC_INSTALL_SCRIPT = "brew tap CanineHQ/canine && brew install canine"
  MAC_START_SCRIPT = "canine local start"
  skip_before_action :authenticate_user!
  ILLUSTRATIONS = [
    {
      src: "/images/illustrations/design_2.webp",
      title: "You enjoy vendor lock-in",
      description: "Canine makes it possible to deploy to 230+ cloud providers, with the same UI.",
      background_color: "bg-green-100"

    },
    {
      src: "/images/illustrations/design_3.webp",
      title: "You like spending more, for less",
      description: "Pay Hetzner like pricing for Heroku like dev experiences.",
      background_color: "bg-yellow-100"
    },
    {
      src: "/images/illustrations/design_4.webp",
      title: "You don't want modern infrastructure",
      description: "Would rather cobble together SSH scripts? Look elsewhere.",
      background_color: "bg-blue-100"
    },
    {
      src: "/images/illustrations/design_5.webp",
      title: "You like configuring infrastructure more than building apps",
      description: "Canine makes your infrastructure \"just work\".",
      background_color: "bg-violet-100"
    }
  ]
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

  def calculator
    @prices = JSON.parse(File.read(File.join(Rails.root, 'public', 'resources', 'prices.json')))
  end

  def docs
    render "static/docs", layout: false
  end

  def swagger
    render plain: File.read(Rails.root.join('swagger', 'v1', 'swagger.yaml')), layout: false
  end

  def install
    GoogleAnalytics.track("install_script_download", client_id: request.remote_ip, params: { user_agent: request.user_agent.to_s })
    send_file Rails.root.join("install", "install.sh"), type: "text/plain", disposition: "inline"
  end
end
