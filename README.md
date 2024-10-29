## Prerequisites

- **Node.js**: v20
- **Helm**: Install via Homebrew
  ```bash
  brew install helm
  ```
- **Ruby Gems**: Install dependencies
  ```bash
  bundle install
  ```
- [**Cloudflare Tunnel**](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/): For development testing with GitHub
  ```bash
    cloudflared tunnel run <YOUR TUNNEL NAME>
  ```
- **Docker**: Run locally
- **.env Configuration**: Set environment variable
  ```bash
  APP_HOST=canine.example.com
  OMNIAUTH_GITHUB_WEBHOOK_SECRET=1234567890
  OMNIAUTH_GITHUB_PUBLIC_KEY=1234567890
  OMNIAUTH_GITHUB_PRIVATE_KEY=1234567890
  ```
- **Enable git hooks**:
  ```bash
  git config --local include.path .gitconfig
  ```

## Running the app

Use the following command to start your application:

```bash
bin/dev
```

## TODOs

- [ ] Onboarding flow (connect github)
- [ ] we should have a feature to continuously poll stuff and figure out if they are still alive
- [ ] Healthchecks and whatnot
- [ ] Write the manifesto
- [ ] allow public network access flag is not currently doing anything

* I want a way to “stop” the processes, can maybe do this with a replicas=0 setting
* Rebulid metrics tabs so it works for both clusters & pods
  https://overcast.blog/zero-downtime-deployments-with-kubernetes-a-full-guide-71019397b924?gi=95ab85c45634

+<%# TODO (celina): when updating the value, it does not save %>

