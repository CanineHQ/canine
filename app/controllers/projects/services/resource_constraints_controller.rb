class Projects::Services::ResourceConstraintsController < Projects::Services::BaseController
  before_action :set_service

  def create
    result = ResourceConstraints::Create.call(@service.build_resource_constraint, resource_constraint_params)

    if result.success?
      @service.updated!
      render_partial
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    render_partial
  end

  def new
    render_partial(show_form: true)
  end

  def update
    result = ResourceConstraints::Update.call(@service.resource_constraint, resource_constraint_params)
    @service.updated!

    if result.success?
      render_partial
    else
      raise StandardError, result.message
    end
  end

  def destroy
    @service.resource_constraint.destroy
    @service.updated!
    render_partial
  end

  private

  def render_partial(locals = {})
    render partial: "projects/services/resource_constraints/show", locals: { service: @service, resource_constraint: @service.resource_constraint }.merge(locals)
  end

  def resource_constraint_params
    params.require(:resource_constraint).permit(
      :cpu_request,
      :cpu_limit,
      :memory_request,
      :memory_limit,
      :gpu_request
    )
  end
end
