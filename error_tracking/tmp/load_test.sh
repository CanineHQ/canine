#!/usr/bin/env bash
# Continuously sends randomized errors to the error tracking service.
# Usage: ./load_test.sh [errors_per_minute] [host]
# Default: 20 errors/min to http://0.0.0.0:3004

set -e

EPM="${1:-20}"
HOST="${2:-http://0.0.0.0:3004}"
SOURCE_ID=1
SENTRY_KEY="ba9095cd9cfc414db8443e9b715de44b"
URL="${HOST}/api/${SOURCE_ID}/store/?sentry_key=${SENTRY_KEY}"

SLEEP_INTERVAL=$(echo "scale=2; 60 / $EPM" | bc)

EXCEPTIONS=(
  'NoMethodError|undefined method '\''name'\'' for nil:NilClass'
  'NoMethodError|undefined method '\''email'\'' for nil:NilClass'
  'ActiveRecord::RecordNotFound|Couldn'\''t find User with '\''id'\''=%d'
  'ActiveRecord::RecordNotFound|Couldn'\''t find Order with '\''id'\''=%d'
  'ActiveRecord::RecordNotFound|Couldn'\''t find Project with '\''id'\''=%d'
  'ActiveRecord::RecordInvalid|Validation failed: Email has already been taken'
  'ActiveRecord::RecordInvalid|Validation failed: Name can'\''t be blank'
  'Redis::TimeoutError|Connection timed out after 5.0 seconds'
  'Redis::CannotConnectError|Error connecting to Redis on redis:6379 (Errno::ECONNREFUSED)'
  'PG::ConnectionBad|could not connect to server: Connection refused'
  'PG::UndefinedTable|ERROR: relation "sessions" does not exist'
  'ActionController::ParameterMissing|param is missing or the value is empty: user'
  'ActionController::ParameterMissing|param is missing or the value is empty: project'
  'ActionController::RoutingError|No route matches [GET] "/api/v2/users"'
  'JWT::DecodeError|Signature verification raised'
  'JWT::ExpiredSignature|Signature has expired'
  'Net::ReadTimeout|Net::ReadTimeout with #<TCPSocket:(closed)>'
  'Net::OpenTimeout|execution expired'
  'Rack::Timeout::RequestTimeoutException|Request ran for longer than 30000ms'
  'Rack::Timeout::RequestTimeoutException|Request ran for longer than 60000ms'
  'ArgumentError|wrong number of arguments (given 3, expected 2)'
  'ArgumentError|invalid byte sequence in UTF-8'
  'TypeError|no implicit conversion of nil into String'
  'TypeError|String can'\''t be coerced into Integer'
  'NameError|uninitialized constant ReportGenerator'
  'RuntimeError|Cannot perform this action in read-only mode'
  'Errno::ENOSPC|No space left on device @ io_write'
  'OpenSSL::SSL::SSLError|SSL_connect returned=1 errno=0 peeraddr=api.stripe.com:443'
  'Faraday::ConnectionFailed|Connection refused - connect(2) for "payments.internal"'
  'Faraday::TimeoutError|Net::ReadTimeout with #<TCPSocket:(closed)>'
  'JSON::ParserError|unexpected token at '\''<!DOCTYPE html>'\'''
  'Encoding::UndefinedConversionError|"\\xFF" from ASCII-8BIT to UTF-8'
  'ZeroDivisionError|divided by 0'
  'RangeError|bignum too big to convert into long'
  'IOError|closed stream'
  'Aws::S3::Errors::AccessDenied|Access Denied'
  'Aws::S3::Errors::NoSuchKey|The specified key does not exist.'
  'Sidekiq::Shutdown|Sidekiq::Shutdown'
  'SignalException|SIGTERM'
  'ActiveStorage::FileNotFoundError|ActiveStorage::FileNotFoundError'
)

TRANSACTIONS=(
  'UsersController#show'
  'UsersController#create'
  'UsersController#update'
  'UsersController#index'
  'OrdersController#show'
  'OrdersController#create'
  'ProjectsController#create'
  'ProjectsController#update'
  'ProjectsController#destroy'
  'PaymentsController#create'
  'PaymentsController#webhook'
  'ReportsController#export'
  'ReportsController#index'
  'DashboardController#index'
  'WebhooksController#github'
  'WebhooksController#stripe'
  'SessionsController#create'
  'Api::V1::UsersController#index'
  'Api::V1::ProjectsController#show'
  'Api::V1::DeploymentsController#create'
  'NotificationJob#perform'
  'CleanupJob#perform'
  'BillingJob#perform'
  'ReportGeneratorJob#perform'
  'WebhookDeliveryJob#perform'
)

LEVELS=("error" "error" "error" "error" "error" "warning" "warning" "fatal")
ENVS=("production" "production" "production" "production" "staging" "staging" "development")
SERVERS=("web-1.prod" "web-2.prod" "web-3.prod" "worker-1.prod" "worker-2.prod" "web-1.staging" "localhost")
RELEASES=("rails-api@2.4.1" "rails-api@2.4.1" "rails-api@2.4.2" "rails-api@2.5.0-rc1" "rails-api@main-abc123")

pick() {
  local arr=("$@")
  echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}

COUNT=0
echo "Load test started: ~${EPM} errors/min to ${HOST}"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  COUNT=$((COUNT + 1))

  exc="$(pick "${EXCEPTIONS[@]}")"
  exc_type="${exc%%|*}"
  exc_value="${exc#*|}"
  # Substitute %d with a random ID if present
  exc_value="${exc_value//%d/$((RANDOM % 9999 + 1))}"

  txn="$(pick "${TRANSACTIONS[@]}")"
  level="$(pick "${LEVELS[@]}")"
  env="$(pick "${ENVS[@]}")"
  server="$(pick "${SERVERS[@]}")"
  release="$(pick "${RELEASES[@]}")"
  ts="$(date +%s).$(( RANDOM % 999 ))"
  eid="load_$(date +%s%N)_${RANDOM}"

  curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "{
    \"event_id\": \"${eid}\",
    \"level\": \"${level}\",
    \"platform\": \"ruby\",
    \"server_name\": \"${server}\",
    \"environment\": \"${env}\",
    \"release\": \"${release}\",
    \"transaction\": \"${txn}\",
    \"timestamp\": ${ts},
    \"exception\": {\"values\": [{\"type\": \"${exc_type}\", \"value\": \"${exc_value}\"}]}
  }" > /dev/null 2>&1

  if (( COUNT % 10 == 0 )); then
    echo "[$(date '+%H:%M:%S')] sent ${COUNT} errors"
  fi

  sleep "${SLEEP_INTERVAL}"
done
