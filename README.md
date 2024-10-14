## TODO

- [ ] Onboarding flow
- [ ] we should have a feature to continuously poll stuff and figure out if they are still alive
- [ ] Healthchecks and whatnot

## Setup

- node 18
- brew install helm
- bundle install
- cloudflared tunnel for development testing with github
- set up .env file
- run docker locally
- TODO: beef up readme

```bash
APP_HOST=canine.example.com
OMNIAUTH_GITHUB_WEBHOOK_SECRET=1234567890
OMNIAUTH_GITHUB_PUBLIC_KEY=1234567890
OMNIAUTH_GITHUB_PRIVATE_KEY=1234567890
```

#### Running

To run your application, you'll use the `bin/dev` command:

```bash
bin/dev
```
