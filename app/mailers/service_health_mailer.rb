class ServiceHealthMailer < ApplicationMailer
  def service_down(service, user)
    @service = service
    @project = service.project
    @user = user
    mail(to: user.email, subject: "[Canine] #{@service.name} is down (#{@project.name})")
  end

  def service_restored(service, user)
    @service = service
    @project = service.project
    @user = user
    mail(to: user.email, subject: "[Canine] #{@service.name} is back up (#{@project.name})")
  end
end
