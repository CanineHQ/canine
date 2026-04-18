# Feature Flags

This project uses [Flipper](https://www.flippercloud.io/) for feature flag management.

## Available Features

### Cloud Development Environment (`cloud_dev_environment`)

Controls access to the Cloud Development Environment feature, which allows users to SSH into their running applications with Claude Code integration.

**Status**: Disabled by default

#### Enable Globally

Enable for all accounts:

```bash
bundle exec rake dev_environment:enable
```

#### Enable for Specific Account

Enable for a single account:

```bash
bundle exec rake dev_environment:enable_for_account[123]
```

Replace `123` with the account ID.

#### Disable Globally

```bash
bundle exec rake dev_environment:disable
```

#### Disable for Specific Account

```bash
bundle exec rake dev_environment:disable_for_account[123]
```

#### Check Status

```bash
bundle exec rake dev_environment:status
```

Output example:
```
✅ Cloud Development Environment is ENABLED globally

Enabled for 2 account(s):
  - Acme Corp (ID: 1)
  - Beta Testers (ID: 5)
```

## Using Flipper UI

Flipper includes a web UI for managing feature flags.

### Access Flipper UI

Mount the UI in `config/routes.rb` (admin only):

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount Flipper::UI.app(Flipper) => '/admin/flipper'
end
```

Then visit: `https://yourapp.com/admin/flipper`

### Enable via UI

1. Go to `/admin/flipper`
2. Click on `cloud_dev_environment` (or create it)
3. Choose enablement method:
   - **Boolean**: Enable for everyone
   - **Actors**: Enable for specific accounts
   - **Groups**: Enable for account groups (e.g., beta testers)
   - **Percentage of Actors**: Gradual rollout (e.g., 10% of accounts)

## Using Flipper in Code

### Check if Feature is Enabled

```ruby
# In controllers/views
if cloud_dev_environment_enabled?
  # Show feature
end

# Or directly
if Flipper.enabled?(:cloud_dev_environment, current_account)
  # Feature logic
end
```

### Enable/Disable Programmatically

```ruby
# Enable globally
Flipper.enable(:cloud_dev_environment)

# Enable for specific actor (account)
account = Account.find(1)
Flipper.enable_actor(:cloud_dev_environment, account)

# Enable for a group
Flipper.enable_group(:cloud_dev_environment, :beta_testers)

# Enable for percentage (e.g., 25% rollout)
Flipper.enable_percentage_of_actors(:cloud_dev_environment, 25)

# Disable
Flipper.disable(:cloud_dev_environment)
```

## Creating New Feature Flags

### 1. Add Helper Method

In `app/controllers/application_controller.rb`:

```ruby
def my_feature_enabled?
  Flipper.enabled?(:my_feature, current_account)
end
helper_method :my_feature_enabled?
```

### 2. Use in Views

```erb
<% if my_feature_enabled? %>
  <div>New feature content</div>
<% end %>
```

### 3. Use in Controllers

```ruby
before_action :check_my_feature

def check_my_feature
  unless my_feature_enabled?
    redirect_to root_path, alert: "Feature not available"
  end
end
```

### 4. Create Rake Tasks (Optional)

```ruby
# lib/tasks/my_feature.rake
namespace :my_feature do
  task enable: :environment do
    Flipper.enable(:my_feature)
  end

  task disable: :environment do
    Flipper.disable(:my_feature)
  end
end
```

## Best Practices

1. **Default to Disabled**: New features should be disabled by default
2. **Use Actors for Beta Testing**: Enable for specific accounts first
3. **Gradual Rollout**: Use percentage rollout for risky features
4. **Clean Up**: Remove feature flags once fully rolled out
5. **Document**: Add all feature flags to this document

## Rollout Strategy Example

For a major new feature:

1. **Week 1**: Enable for internal accounts (10%)
   ```bash
   Flipper.enable_percentage_of_actors(:my_feature, 10)
   ```

2. **Week 2**: Increase to beta testers (25%)
   ```bash
   Flipper.enable_percentage_of_actors(:my_feature, 25)
   ```

3. **Week 3**: Increase to half (50%)
   ```bash
   Flipper.enable_percentage_of_actors(:my_feature, 50)
   ```

4. **Week 4**: Full rollout (100%)
   ```bash
   Flipper.enable(:my_feature)
   ```

5. **Week 5+**: Remove flag from code if stable

## Troubleshooting

### Feature Not Working After Enabling

- Clear Rails cache: `Rails.cache.clear`
- Restart server
- Check Flipper adapter is configured correctly

### Percentage Rollout Not Working

- Ensure you're using `enable_percentage_of_actors` not `enable_percentage_of_time`
- Actor (account) must implement `flipper_id` method

### UI Not Accessible

- Check authentication middleware in routes
- Verify user has admin permissions
- Check Flipper gem versions are compatible

## More Resources

- [Flipper Documentation](https://www.flippercloud.io/docs)
- [Flipper GitHub](https://github.com/flippercloud/flipper)
- [Flipper UI Guide](https://www.flippercloud.io/docs/ui)
