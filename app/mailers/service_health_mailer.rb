class ServiceHealthMailer < ApplicationMailer
  manageable
  def service_down(service, user)
    @service = service
    @project = service.project
    @user = user
    @favicon_url = project_favicon_url
    attachments.inline["logo.png"] = File.read(Rails.root.join("public/images/dark.png"))
    mail(to: user.email, subject: "[Canine] #{@project.name}/#{@service.name} is down")
  end

  def service_restored(service, user)
    @service = service
    @project = service.project
    @user = user
    @favicon_url = project_favicon_url
    attachments.inline["logo.png"] = File.read(Rails.root.join("public/images/dark.png"))
    mail(to: user.email, subject: "[Canine] #{@project.name}/#{@service.name} is back up")
  end

  private

  def project_favicon_url
    domain = @service.domains.first&.domain_name
    return nil if domain.blank?

    FaviconService.new(domain).fetch_url(size: 32, provider: :google)
  end
end
