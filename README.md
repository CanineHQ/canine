## Setup

- node 18
- bundle install
- cloudflared tunnel for development testing with github
- set up .env file
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
