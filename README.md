> [!NOTE]
> 👉 We've also built [Jumpstart Pro](https://jumpstartrails.com) which is a version of Jumpstart that includes payments with Stripe & Braintree, team accounts, TailwindCSS, and much more.

# Jumpstart Rails Template

All your Rails apps should start off with a bunch of great defaults. It's like Laravel Spark, for Rails.

Want to see how it works? Check out [the Jumpstart walkthrough video](https://www.youtube.com/watch?v=ssOZpISfIfI):

[![Jumpstart Ruby on Rails Template Walkthrough](https://i.imgur.com/pZDPbc7l.png)](https://www.youtube.com/watch?v=ssOZpISfIfI)

## Getting Started

Jumpstart is a Rails template, so you pass it in as an option when creating a new app.

#### Requirements

You'll need the following installed to run the template successfully:

* Ruby 2.5 or higher
* bundler - `gem install bundler`
* rails - `gem install rails`
* Database - we recommend Postgres, but you can use MySQL, SQLite3, etc
* Redis - For ActionCable support
* ImageMagick or libvips for ActiveStorage variants
* Yarn - `brew install yarn` or [Install Yarn](https://yarnpkg.com/en/docs/install)
* Foreman (optional) - `gem install foreman` - helps run all your processes in development

#### Creating a new app

```bash
rails new myapp -d postgresql -m https://raw.githubusercontent.com/excid3/jumpstart/master/template.rb
```

Or if you have downloaded this repo, you can reference template.rb locally:

```bash
rails new myapp -d postgresql -m template.rb
```

❓Having trouble? Try adding `DISABLE_SPRING=1` before `rails new`. Spring will get confused if you create an app with the same name twice.

#### Running your app

```bash
bin/dev
```

You can also run them in separate terminals manually if you prefer.

A separate `Procfile` is generated for deploying to production on Heroku.

#### Authenticate with social networks

We use the encrypted Rails Credentials for app_id and app_secrets when it comes to omniauth authentication. Edit them as so:

```
EDITOR=vim rails credentials:edit
```

Make sure your file follow this structure:

```yml
secret_key_base: [your-key]
development:
  github:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
production:
  github:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
```

With the environment, the service and the app_id/app_secret. If this is done correctly, you should see login links
for the services you have added to the encrypted credentials using `EDITOR=vim rails credentials:edit`

#### Enabling Admin Panel
App uses `madmin` [gem](https://github.com/excid3/madmin), so you need to run the madmin generator:

```
rails g madmin:install
```

This will install Madmin and generate resources for each of the models it finds.
#### Redis set up
##### On OSX
```
brew update
brew install redis
brew services start redis
```
##### Ubuntu
```
sudo apt-get install redis-server
```

#### Cleaning up

```bash
rails db:drop
spring stop
cd ..
rm -rf myapp
```
