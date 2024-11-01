![alt text](https://github.com/czhu12/canine/blob/main/public/images/logo-full.png?raw=true)

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