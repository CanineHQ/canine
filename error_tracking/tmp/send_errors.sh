#!/usr/bin/env bash
# Sends realistic Sentry-compatible errors as if from a Ruby on Rails app
set -e

HOST="http://0.0.0.0:3004"
SOURCE_ID=1
SENTRY_KEY="ba9095cd9cfc414db8443e9b715de44b"
STORE_URL="${HOST}/api/${SOURCE_ID}/store/?sentry_key=${SENTRY_KEY}"

send() {
  curl -s -X POST "$STORE_URL" -H 'Content-Type: application/json' -d "$1"
  echo ""
}

# 1) NoMethodError in UsersController#show
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d1",
  "level": "error",
  "platform": "ruby",
  "server_name": "web-1.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "UsersController#show",
  "timestamp": 1711609200.123,
  "exception": {
    "values": [{
      "type": "NoMethodError",
      "value": "undefined method `email` for nil:NilClass",
      "module": "",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/users_controller.rb", "lineno": 42, "function": "show", "context_line": "    @user.email"},
          {"filename": "app/controllers/application_controller.rb", "lineno": 18, "function": "set_current_user"},
          {"filename": "actionpack/lib/action_controller/metal.rb", "lineno": 227, "function": "dispatch"}
        ]
      }
    }]
  },
  "tags": {"controller": "UsersController", "action": "show", "request_id": "req-abc123"},
  "extra": {"params": {"id": "999"}, "session_id": "sess-xyz"},
  "contexts": {
    "runtime": {"name": "ruby", "version": "3.2.2"},
    "os": {"name": "Linux", "version": "6.1.0", "kernel_version": "6.1.0-18-amd64"}
  },
  "request": {
    "method": "GET",
    "url": "https://api.example.com/users/999",
    "headers": {"User-Agent": "Mozilla/5.0", "Accept": "application/json"}
  },
  "user": {"id": "user-42", "email": "alice@example.com", "username": "alice"}
}'

# 2) ActiveRecord::RecordNotFound
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d2",
  "level": "error",
  "platform": "ruby",
  "server_name": "web-2.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "OrdersController#show",
  "timestamp": 1711609320.456,
  "exception": {
    "values": [{
      "type": "ActiveRecord::RecordNotFound",
      "value": "Couldn'\''t find Order with '\''id'\''=8842",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/orders_controller.rb", "lineno": 15, "function": "show", "context_line": "    @order = Order.find(params[:id])"},
          {"filename": "activerecord/lib/active_record/core.rb", "lineno": 284, "function": "find"}
        ]
      }
    }]
  },
  "tags": {"controller": "OrdersController", "action": "show"},
  "request": {
    "method": "GET",
    "url": "https://api.example.com/orders/8842",
    "headers": {"User-Agent": "curl/7.88.1"}
  },
  "user": {"id": "user-7", "email": "bob@example.com"}
}'

# 3) Redis::TimeoutError in background job
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d3",
  "level": "fatal",
  "platform": "ruby",
  "server_name": "worker-1.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "NotificationJob#perform",
  "timestamp": 1711609500.789,
  "exception": {
    "values": [{
      "type": "Redis::TimeoutError",
      "value": "Connection timed out after 5.0 seconds",
      "stacktrace": {
        "frames": [
          {"filename": "app/jobs/notification_job.rb", "lineno": 28, "function": "perform", "context_line": "    Redis.current.publish(channel, payload.to_json)"},
          {"filename": "redis/lib/redis/client.rb", "lineno": 134, "function": "call"}
        ]
      }
    }]
  },
  "tags": {"job_class": "NotificationJob", "queue": "default", "sidekiq_tid": "abc123"},
  "extra": {"job_id": "jid-998877", "retry_count": 2, "args": [42, "welcome_email"]}
}'

# 4) ActionController::ParameterMissing
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
  "level": "error",
  "platform": "ruby",
  "server_name": "web-1.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "ProjectsController#create",
  "timestamp": 1711609620.111,
  "exception": {
    "values": [{
      "type": "ActionController::ParameterMissing",
      "value": "param is missing or the value is empty: project",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/projects_controller.rb", "lineno": 55, "function": "project_params", "context_line": "    params.require(:project).permit(:name, :description)"},
          {"filename": "actionpack/lib/action_controller/metal/strong_parameters.rb", "lineno": 256, "function": "require"}
        ]
      }
    }]
  },
  "tags": {"controller": "ProjectsController", "action": "create"},
  "request": {
    "method": "POST",
    "url": "https://api.example.com/projects",
    "headers": {"Content-Type": "application/json", "User-Agent": "PostmanRuntime/7.32.3"},
    "data": "{}"
  },
  "user": {"id": "user-3", "email": "carol@example.com"}
}'

# 5) JWT::DecodeError
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d5",
  "level": "warning",
  "platform": "ruby",
  "server_name": "web-2.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "AuthenticationService#decode_token",
  "timestamp": 1711609740.222,
  "exception": {
    "values": [{
      "type": "JWT::DecodeError",
      "value": "Signature verification raised",
      "stacktrace": {
        "frames": [
          {"filename": "app/services/authentication_service.rb", "lineno": 12, "function": "decode_token", "context_line": "    JWT.decode(token, secret, true, algorithm: '\''HS256'\'')"},
          {"filename": "jwt/lib/jwt/decode.rb", "lineno": 45, "function": "verify_signature"}
        ]
      }
    }]
  },
  "tags": {"source": "api_auth"},
  "request": {
    "method": "GET",
    "url": "https://api.example.com/api/v1/me",
    "headers": {"Authorization": "Bearer eyJ...tampered", "User-Agent": "okhttp/4.10.0"}
  }
}'

# 6) PG::ConnectionBad in staging
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d6",
  "level": "fatal",
  "platform": "ruby",
  "server_name": "web-1.staging",
  "environment": "staging",
  "release": "rails-api@2.5.0-rc1",
  "transaction": "ApplicationRecord.connection",
  "timestamp": 1711610000.333,
  "exception": {
    "values": [{
      "type": "PG::ConnectionBad",
      "value": "could not connect to server: Connection refused\n\tIs the server running on host \"db.staging\" and accepting TCP/IP connections on port 5432?",
      "stacktrace": {
        "frames": [
          {"filename": "activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb", "lineno": 89, "function": "new_client"},
          {"filename": "pg/lib/pg/connection.rb", "lineno": 34, "function": "initialize"}
        ]
      }
    }]
  },
  "tags": {"database": "primary"},
  "contexts": {
    "runtime": {"name": "ruby", "version": "3.3.0"},
    "os": {"name": "Linux", "version": "6.1.0"}
  }
}'

# 7) Timeout::Error during external API call
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d7",
  "level": "error",
  "platform": "ruby",
  "server_name": "web-1.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "PaymentsController#create",
  "timestamp": 1711610100.444,
  "exception": {
    "values": [{
      "type": "Net::ReadTimeout",
      "value": "Net::ReadTimeout with #<TCPSocket:(closed)>",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/payments_controller.rb", "lineno": 33, "function": "create", "context_line": "    response = StripeService.charge(amount: params[:amount])"},
          {"filename": "app/services/stripe_service.rb", "lineno": 18, "function": "charge"},
          {"filename": "net/http/lib/net/http.rb", "lineno": 960, "function": "transport_request"}
        ]
      }
    }]
  },
  "tags": {"payment_provider": "stripe", "controller": "PaymentsController"},
  "extra": {"amount_cents": 4999, "currency": "usd", "customer_id": "cus_abc"},
  "request": {
    "method": "POST",
    "url": "https://api.example.com/payments",
    "headers": {"Content-Type": "application/json"}
  },
  "user": {"id": "user-88", "email": "dave@example.com"}
}'

# 8) NameError in development
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d8",
  "level": "error",
  "platform": "ruby",
  "server_name": "localhost",
  "environment": "development",
  "release": "rails-api@main-abc123",
  "transaction": "DashboardController#index",
  "timestamp": 1711610200.555,
  "exception": {
    "values": [{
      "type": "NameError",
      "value": "uninitialized constant DashboardController::ReportGenerator",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/dashboard_controller.rb", "lineno": 8, "function": "index", "context_line": "    @report = ReportGenerator.new(current_account)"}
        ]
      }
    }]
  },
  "tags": {"controller": "DashboardController"},
  "user": {"id": "user-1", "email": "dev@localhost"}
}'

# 9) ArgumentError in staging
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d9",
  "level": "error",
  "platform": "ruby",
  "server_name": "web-1.staging",
  "environment": "staging",
  "release": "rails-api@2.5.0-rc1",
  "transaction": "WebhooksController#github",
  "timestamp": 1711610300.666,
  "exception": {
    "values": [{
      "type": "ArgumentError",
      "value": "wrong number of arguments (given 3, expected 2)",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/webhooks_controller.rb", "lineno": 22, "function": "github", "context_line": "    WebhookProcessor.process(event_type, payload, headers)"},
          {"filename": "app/services/webhook_processor.rb", "lineno": 5, "function": "process"}
        ]
      }
    }]
  },
  "tags": {"webhook_provider": "github", "event_type": "push"},
  "extra": {"delivery_id": "ghd-12345"},
  "request": {
    "method": "POST",
    "url": "https://staging.example.com/webhooks/github",
    "headers": {"X-GitHub-Event": "push", "X-GitHub-Delivery": "ghd-12345"}
  }
}'

# 10) Rack::Timeout::RequestTimeoutException
send '{
  "event_id": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3da",
  "level": "fatal",
  "platform": "ruby",
  "server_name": "web-2.prod",
  "environment": "production",
  "release": "rails-api@2.4.1",
  "transaction": "ReportsController#export",
  "timestamp": 1711610400.777,
  "exception": {
    "values": [{
      "type": "Rack::Timeout::RequestTimeoutException",
      "value": "Request ran for longer than 30000ms",
      "stacktrace": {
        "frames": [
          {"filename": "app/controllers/reports_controller.rb", "lineno": 47, "function": "export", "context_line": "    csv = Report.generate_csv(filters: filter_params)"},
          {"filename": "app/models/report.rb", "lineno": 112, "function": "generate_csv"},
          {"filename": "rack-timeout/lib/rack/timeout/core.rb", "lineno": 120, "function": "check!"}
        ]
      }
    }]
  },
  "tags": {"controller": "ReportsController", "action": "export", "format": "csv"},
  "extra": {"filter_params": {"date_range": "2024-01-01..2024-12-31", "account_id": 15}},
  "request": {
    "method": "GET",
    "url": "https://api.example.com/reports/export.csv?date_range=2024-01-01..2024-12-31",
    "headers": {"Accept": "text/csv"}
  },
  "user": {"id": "user-15", "email": "manager@example.com", "username": "manager"}
}'

echo ""
echo "Done! Sent 10 errors to ${HOST}"
