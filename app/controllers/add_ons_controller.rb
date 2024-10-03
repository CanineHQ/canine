class AddOnsController < ApplicationController
  include StorageHelper
  before_action :set_add_on, only: [ :show, :edit, :update, :destroy, :logs ]

  # GET /add_ons
  def index
    @pagy, @add_ons = pagy(AddOn.all)

    # Uncomment to authorize with Pundit
    # authorize @add_ons
  end

  # GET /add_ons/1 or /add_ons/1.json
  def show
  end

  # GET /add_ons/new
  def new
    @add_on = AddOn.new

    # Uncomment to authorize with Pundit
    # authorize @add_on
  end

  def logs
  end

  # GET /add_ons/1/edit
  def edit
  end

  # POST /add_ons or /add_ons.json
  def create
    @add_on = AddOn.new(add_on_params)
    # Uncomment to authorize with Pundit
    # authorize @add_on

    respond_to do |format|
      if @add_on.save
        AddOns::InstallJob.perform_later(@add_on)
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
    respond_to do |format|
      if @add_on.update(add_on_params)
        format.html { redirect_to @add_on, notice: "Add on was successfully updated." }
        format.json { render :show, status: :ok, location: @add_on }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @add_on.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /add_ons/1 or /add_ons/1.json
  def destroy
    @add_on.uninstalling!
    respond_to do |format|
      AddOns::UninstallJob.perform_later(@add_on)
      format.html { redirect_to add_ons_url, status: :see_other, notice: "Uninstalling add on #{@add_on.name}" }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_add_on
    @add_on = current_user.add_ons.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @add_on
    if @add_on.chart_type == "redis"
      @service = K8::Helm::Redis.new(@add_on)
    elsif @add_on.chart_type == "postgresql"
      @service = K8::Helm::Postgresql.new(@add_on)
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to add_ons_path
  end

  # Only allow a list of trusted parameters through.
  def add_on_params
    params[:add_on][:metadata] = params[:add_on][:metadata][params[:add_on][:chart_type]]
    params.require(:add_on).permit(:cluster_id, :chart_type, :name, metadata: {})

    # Uncomment to use Pundit permitted attributes
    # params.require(:add_on).permit(policy(@add_on).permitted_attributes)
  end
end
