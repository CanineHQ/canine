class ServiceHealthMailer < ApplicationMailer
  manageable
  def service_down(service, user)
    @service = service
    @project = service.project
    @user = user
    mail(to: user.email, subject: "[Canine] #{@project.name}/#{@service.name} is down")
  end

  def service_restored(service, user)
    @service = service
    @project = service.project
    @user = user
    mail(to: user.email, subject: "[Canine] #{@project.name}/#{@service.name} is back up")
  end
end
