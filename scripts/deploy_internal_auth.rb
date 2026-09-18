# Usage: rails runner scripts/deploy_internal_auth.rb <service_id> [--dry-run]
#
# Manually deploys the oauth2-proxy auth proxy for an internal service.
# Use --dry-run to print the generated YAML without applying it.

service_id = ARGV[0]
dry_run = ARGV.include?("--dry-run")

abort "Usage: rails runner scripts/deploy_internal_auth.rb <service_id> [--dry-run]" if service_id.blank?

service = Service.find(service_id)
project = service.project
user = User.first # fallback user for K8 connection

puts "Service: #{service.name} (ID: #{service.id})"
puts "Project: #{project.name} (namespace: #{project.namespace})"
puts "Internal (has OAuth app): #{service.internal?}"
puts "Requires auth: #{service.requires_auth?}"
puts ""

# Step 1: Ensure OAuth application exists
oauth_app = service.oauth_application
if oauth_app.nil?
  puts "[!] No OAuth application found. Creating one..."
  oauth_app = service.create_oauth_application!(
    name: "Auth Proxy: #{service.name} (#{project.name})",
    scopes: "openid profile email",
    confidential: true,
    redirect_uri: "https://#{ENV.fetch('APP_HOST')}/oauth2/callback"
  )
  puts "[+] Created OAuth application: #{oauth_app.name} (uid: #{oauth_app.uid})"
else
  puts "[OK] OAuth application exists: #{oauth_app.name}"
end

# Update redirect_uri if service has a domain
if service.primary_domain.present?
  redirect_uri = "https://#{service.primary_domain}/oauth2/callback"
  if oauth_app.redirect_uri != redirect_uri
    oauth_app.update!(redirect_uri: redirect_uri)
    puts "[~] Updated redirect_uri to: #{redirect_uri}"
  end
end

puts ""
puts "OAuth App UID:      #{oauth_app.uid}"
puts "OAuth App Secret:   #{oauth_app.secret.first(8)}..."
puts "Cookie Secret:      #{service.auth_proxy_cookie_secret.first(8)}..."
puts "OIDC Issuer URL:    #{ENV.fetch('APP_HOST')}"
puts "Primary Domain:     #{service.primary_domain || '(none)'}"
puts "Upstream:           http://#{service.name}-service.#{project.namespace}.svc.cluster.local:80"
puts ""

# Step 2: Generate the auth proxy YAML
auth_proxy = K8::Stateless::AuthProxy.new(service)
yaml_content = auth_proxy.to_yaml

puts "--- Generated YAML ---"
puts yaml_content
puts "--- End YAML ---"
puts ""

if dry_run
  puts "[DRY RUN] Skipping apply. Review the YAML above."
  exit
end

# Step 3: Apply to the cluster
puts "[*] Applying auth proxy to cluster..."
connection = K8::Connection.new(project, user, allow_anonymous: true)
kubectl = K8::Kubectl.new(connection)
kubectl.apply_yaml(yaml_content)
puts "[+] Auth proxy applied successfully."

# Step 4: Verify the deployment and service exist
puts ""
puts "[*] Checking deployment status..."
output = kubectl.call(["-n", project.namespace, "get", "deployment", "#{service.name}-auth-proxy", "-o", "wide"])
puts output

puts ""
puts "[*] Checking service status..."
output = kubectl.call(["-n", project.namespace, "get", "service", "#{service.name}-auth-proxy", "-o", "wide"])
puts output

puts ""
puts "[*] Checking pod status..."
output = kubectl.call(["-n", project.namespace, "get", "pods", "-l", "app=#{service.name}-auth-proxy"])
puts output

puts ""
puts "[*] Checking pod logs (last 20 lines)..."
begin
  output = kubectl.call(["-n", project.namespace, "logs", "-l", "app=#{service.name}-auth-proxy", "--tail=20"])
  puts output
rescue => e
  puts "[!] Could not fetch logs: #{e.message}"
end

# Step 5: Verify ingress is routing to auth-proxy
puts ""
puts "[*] Checking ingress configuration..."
begin
  output = kubectl.call(["-n", project.namespace, "get", "ingress", "-o", "wide"])
  puts output
rescue => e
  puts "[!] Could not fetch ingress: #{e.message}"
end
