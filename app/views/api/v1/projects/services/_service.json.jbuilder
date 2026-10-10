# frozen_string_literal: true

json.id service.id
json.name service.name
json.service_type service.service_type
json.status service.status
json.replicas service.replicas
json.container_port service.container_port
json.command service.command
json.healthcheck_url service.healthcheck_url
json.allow_public_networking service.allow_public_networking
json.cron_schedule service.cron_schedule&.schedule
json.internal_url service.internal_url
json.domains service.domains do |domain|
  json.id domain.id
  json.domain_name domain.domain_name
  json.status domain.status
end
