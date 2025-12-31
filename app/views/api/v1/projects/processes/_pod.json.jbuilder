# frozen_string_literal: true

json.name pod.metadata.name
json.namespace pod.metadata.namespace
json.status pod.status.phase
json.created_at pod.metadata.creationTimestamp
json.labels pod.metadata.labels&.to_h
