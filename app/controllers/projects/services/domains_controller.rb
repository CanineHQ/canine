# frozen_string_literal: true

class Projects::Services::DomainsController < Projects::Services::BaseController
  def create
    @domain = @service.domains.new(domain_params)
    if @domain.save
      @service.updated!
      render partial: "projects/services/domains/index", locals: { service: @service }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def check_dns
    Networks::CheckDns.execute(
      ingress: K8::Stateless::Ingress.new(@service),
      connection: active_connection,
    )
    render partial: "projects/services/domains/index", locals: { service: @service, refreshed: true }
  end

  def destroy
    @domain = @service.domains.find(params[:id])
    Domains::Destroy.execute(domain: @domain)
    @service.updated!
    @service.domains.reload

    respond_to do |format|
      format.turbo_stream
      format.html { render partial: "projects/services/domains/index", locals: { service: @service } }
    end
  end

  private

  def domain_params
    params.require(:domain).permit(:domain_name)
  end
end
