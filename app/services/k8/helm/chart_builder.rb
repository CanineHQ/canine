class K8::Helm::ChartBuilder < K8::Base
  attr_reader :chart_name, :resources, :logger, :client

  def initialize(chart_name, logger)
    @chart_name = chart_name
    @logger = logger
    @resources = []
  end

  def connect(connection)
    @client = K8::Helm::Client.connect(connection, Cli::RunAndLog.new(logger))
    super(connection)
  end

  def <<(resource)
    resources << resource
  end

  def chart_yaml
    <<-YAML
    apiVersion: v2
    name: <%= chart_name %>
    version: 1.0.0
    type: application
    appVersion: "1.0.0"
    YAML
  end

  def install_chart(namespace)
    Dir.mktmpdir do |chart_directory|
      logger.info("Creating chart directory #{chart_directory}...")
      # Create /templates directory
      FileUtils.mkdir_p(File.join(chart_directory, "templates"))

      logger.info("Creating Chart.yaml")
      File.write(File.join(chart_directory, "Chart.yaml"), chart_yaml)

      resources.each do |resource|
        logger.info("Writing template #{resource.suggested_file_name}...")
        File.write(File.join(chart_directory, "templates", resource.suggested_file_name), resource.to_yaml)
      end

      logger.info("Installing chart #{chart_name} in namespace #{namespace}...")
      client.install(chart_name, chart_directory, namespace: namespace)
    end
  end
end