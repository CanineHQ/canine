class K8::Helm::ChartBuilder < K8::Base
  attr_reader :chart_name, :resources, :logger, :client, :version

  def initialize(chart_name, version, logger)
    @chart_name = chart_name
    @version = version
    @logger = logger
    @resources = []
    @before_install_callbacks = []
  end

  def register_before_install(&block)
    @before_install_callbacks << block
  end

  def connect(connection)
    @client = K8::Helm::Client.connect(connection, Cli::RunAndLog.new(logger, killable: logger))
    super(connection)
  end

  def <<(resource)
    resources << resource
  end

  def chart_yaml
    <<-YAML
apiVersion: v2
name: #{chart_name}
version: #{version}
type: application
appVersion: #{version}
    YAML
  end

  def install_chart(namespace, atomic: true, wait: true)
    Dir.mktmpdir do |chart_directory|
      logger.info("Creating chart directory #{chart_directory}...")
      # Create /templates directory
      FileUtils.mkdir_p(File.join(chart_directory, "templates"))

      logger.info("Creating Chart.yaml")
      File.write(File.join(chart_directory, "Chart.yaml"), chart_yaml)

      resources.each do |resource|
        yaml_content = resource.to_yaml
        @before_install_callbacks.each { |callback| callback.call(yaml_content) }
        logger.info("Writing template #{resource.suggested_file_name}...")
        File.write(File.join(chart_directory, "templates", resource.suggested_file_name), yaml_content)
      end

      logger.info("Installing chart #{chart_name} in namespace #{namespace}...")
      client.install(
        chart_name,
        chart_directory,
        version,
        namespace: namespace,
        atomic:,
        timeout: "5m0s",
        wait:,
        history_max: 10
      )
    end
  end
end
