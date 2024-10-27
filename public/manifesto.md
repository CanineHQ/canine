# Why does Canine exist?

As a cofounder of a previous start up, I saw first hand how the cost of hosting a web app could explode over time.

What I found weird was that costs grew with organizational complexity, not compute complexity, and often in area's I never expected.

As it turns out, the cost you pay to host <b>your app</b> is only a fraction of the total IT spend.

I'll walk through the history of our IT spend and see how it grew over time.

### At Launch
| Service | Spend (monthly) |
| -------- | ------- |
| Heroku | $100 |
| Google Maps | $50 |
| Sentry | FREE |
| Looker | $1000 |
| Redshift | $800 |
| FiveTran | $600 |
| Datadog | $100 |
| New Relic | $200 |
| **TOTAL** | **$2950** |

Interesting to note, the cost of hosting our app (Heroku) was a tiny portion of our IT spend. (Don't ask me why we were using both New Relic and Datadog, it was more out of laziness than anything else.)

By year 1, we had grown our team (40+), and added a few more tools to our tech stack.

### Year 1
| Service | Spend (monthly) |
| -------- | ------- |
| Heroku | $1000 |
| AWS | $1000 |
| Google Maps | $500 |
| Sentry | $300 |
| Looker | $5000 |
| DBT Cloud | $1000 |
| Databricks | $5000 |
| Redshift | $1500 |
| FiveTran | $2000 |
| Datadog | $1000 |
| New Relic | $800 |
| **TOTAL** | **$16800** |

It's one thing if the reason for the increase is because our product started needing more compute, but that was not the case for a lot of the things we were using. The famous [SSO tax hit us hard](https://sso.tax/), and about half our vendors grew by 20-50%. What's more, it was basically impossible to get any transparency in pricing. One year, our Heroku bill was 100k, the next year, it was 200k for practically the same usage, all of it negotiated over email, with no idea what kinds of discounts our peers were getting.

### Year 2, 3
Costs only grew from here. Peaking at a ~$1M in annual spend within 4 years.

A large chunk of the tools we were using have open source versions, or open source alternatives, but we could never justify hosting them ourselves since we really had no idea what to expect. Most open source installations were simple enough, normally just expecting a server that we can run them on. But what about health checks? What about monitoring? What about alerting? What about logging?

# So, why Canine?
Kubernetes is a powerful tool that can be used to do many things far beyond simple [web application development](https://medium.com/chick-fil-atech/observability-at-the-edge-b2385065ab6e). We learned to love Kubernetes, while also learning the hard way it can be excruciatingly easy to accidentally delete essential services like CoreDNS, and permanently bork your cluster. But for almost all web applications, you only need a tiny slice of what it has to offer: Ingress, Services, Deployments, Pods and CronJobs.

It sits entirely on top of your own Kubernetes cluster, and all of the YAML configurations are downloadable, in case you want to migrate away from Canine.

It also makes up for some of the defects that are missing from out-of-the-box Kubernetes that are absolutely essential for a software development team such as
* Accounts
* Deployment
* Simple one-off scripts
* Metrics dashboard

### Third party applications

But the best part is, on top of Kubernetes, Canine can run a lot more than just _your_ application. Thanks to Helm, basically every single open source software application can be easily hosted through Canine. This makes it trivially easy to, for instance, deploy a hosted version of Sentry!

Give Canine a whirl, on your (own system)[https://github.com/czhu12/canine], or a (hosted version)[https://canine.sh], completely free.

\* No VC money was raised in the building of this product
