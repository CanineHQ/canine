class AddOnsController < ApplicationController
  include StorageHelper
  before_action :set_add_on, only: [ :show, :edit, :update, :destroy, :restart, :download_values ]

  # GET /add_ons
  def index
    add_ons = AddOns::List.call(account_user: current_account_user, params: params).add_ons
    @pagy, @add_ons = pagy(add_ons)

    respond_to do |format|
      format.html
      format.json { render json: @add_ons.map { |a| { id: a.id, name: a.name } } }
    end
  end

  def search
    result = AddOns::HelmChartSearch.execute(query: params[:q])
    if result.success?
      render json: result.response
    else
      render json: { error: "Failed to fetch package details" }, status: :unprocessable_entity
    end
  end

  # GET /add_ons/1 or /add_ons/1.json
  def show
  end

  # GET /add_ons/new
  def new
    @add_on = AddOn.new
  end

  # GET /add_ons/1/edit
  def edit
    @endpoints = @service.get_endpoints
    @ingresses = @service.get_ingresses
  end

  # POST /add_ons or /add_ons.json
  def create
    add_on_params = AddOns::Create.parse_params(params)
    result = AddOns::Create.call(AddOn.new(add_on_params), current_user)
    @add_on = result.add_on

    respond_to do |format|
      if result.success?
        AddOns::InstallJob.perform_later(@add_on, current_user)
        format.html { redirect_to @add_on, notice: "Add on was successfully created." }
        format.json { render :show, status: :created, location: @add_on }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @add_on.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /add_ons/1 or /add_ons/1.json
  def update
    @add_on.assign_attributes(AddOns::Create.parse_params(params))
    result = AddOns::Update.execute(add_on: @add_on)

    respond_to do |format|
      if result.success?
        AddOns::InstallJob.perform_later(@add_on, current_user)
        format.html { redirect_to @add_on, notice: "Add on #{@add_on.name} is updating..." }
        format.json { render :show, status: :ok, location: @add_on }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @add_on.errors, status: :unprocessable_entity }
      end
    end
  end

  def restart
    @service.restart
    redirect_to add_on_url(@add_on), notice: "Add on #{@add_on.name} restarted"
  end

  def fetch_helm_repository_index
    result = AddOns::FetchChartDetailsFromRepositoryUrl.execute(repo_url: params[:repo_url])

    if result.success?
      render json: { charts: result.charts }
    else
      render json: { error: result.message }, status: :unprocessable_entity
    end
  end

  def metadata
    cache_key = "helm_metadata:#{Digest::SHA256.hexdigest("#{params[:chart_url]}:#{params[:version]}")}"

    metadata = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      result = AddOns::FetchChartDetailsFromArtifactHub.execute(chart_url: params[:chart_url], version: params[:version])
      next { schema: {}, default_values: nil } if result.failure?

      package = result.response
      repository = package["repository"]

      version = package["version"]
      values_yaml = K8::Helm::Client.get_default_values_yaml(package["package_id"], package["version"])
      next { schema: {}, default_values: nil, version: } if values_yaml.blank?

      schema_data = fetch_or_infer_schema(package, values_yaml)
      { schema: schema_data[:schema], schema_source: schema_data[:schema_source], default_values: values_yaml, version: }
    rescue Psych::SyntaxError => e
      Rails.logger.error("Failed to parse values.yaml: #{e.message}")
      { schema: {}, default_values: nil, version: }
    end

    render json: metadata
  end

  def download_values
    if @add_on.installed?
      values_yaml = @service.all_values_yaml
      if values_yaml.present?
        send_data values_yaml,
                  filename: "#{@add_on.name}-values.yaml",
                  type: 'text/yaml',
                  disposition: 'attachment'
      else
        redirect_to @add_on, alert: "Unable to download values. Please ensure the add-on is properly installed."
      end
    else
      redirect_to @add_on, alert: "Values can only be downloaded for installed add-ons."
    end
  end

  # DELETE /add_ons/1 or /add_ons/1.json
  def destroy
    @add_on.uninstalling!
    respond_to do |format|
      AddOns::UninstallJob.perform_later(@add_on, current_user.id)
      format.html { redirect_to add_ons_url, notice: "Uninstalling add on #{@add_on.name}" }
      format.json { head :no_content }
    end
  end

  private

  def fetch_or_infer_schema(package, values_yaml)
    if package["has_values_schema"]
      schema_result = AddOns::HelmChartValuesSchema.execute(
        package_id: package["package_id"],
        version: package["version"]
      )
      return { schema: schema_result.schema, schema_source: "fetched" } if schema_result.success?
    end

    values = YAML.safe_load(values_yaml, permitted_classes: [ Symbol ], aliases: true)
    { schema: InferJsonSchemaService.new(values).infer, schema_source: "inferred" }
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_add_on
    add_ons = AddOns::VisibleToUser.execute(account_user: current_account_user).add_ons
    @add_on = add_ons.find(params[:id])
    @service = K8::Helm::Service.create_from_add_on(K8::Connection.new(@add_on, current_user))
  rescue ActiveRecord::RecordNotFound
    redirect_to add_ons_path
  end
end
