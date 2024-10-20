## TODO

- [ ] Onboarding flow
- [ ] we should have a feature to continuously poll stuff and figure out if they are still alive
- [ ] Healthchecks and whatnot
- [ ] Write the manifesto
- [ ] allow public network access flag is not currently doing anything
* Make it show which git SHA is currently deployed on the homepage
    * Or if there is currently a deploy happening
* I want a way to “stop” the processes, can maybe do this with a replicas=0 setting
* All the times need to show relative times, not absolute. It’s too hard to understand absolute times.
* Whenever something is pushed, and deployed, we need to kill all one off containers because they are no longer running the correct source code
* “Pending” should have some kind of active spinner animation just for the feels
* Rebulid metrics tabs so it works for both clusters & pods

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
