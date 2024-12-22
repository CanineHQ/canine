# Why does Canine exist?

As a cofounder of a previous start up, I saw first hand how the cost of hosting a web app could explode over time.

What I found weird was that costs grew with organizational complexity, not compute complexity, and often in area's I never expected.

As it turns out, the cost you pay to host <b>your app</b> is only a fraction of the total IT spend.

I'll walk through the history of our IT spend and see how it grew over time. (These are all based on my memory, and may not be 100% accurate, but hopefully they tell the story well enough.)

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
| **TOTAL** | **$2850** |

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
| **TOTAL** | **$19100** |

It's one thing if the reason for the increase is because our product started needing more compute, but that was not the case for a lot of the things we were using. The famous [SSO tax hit us hard](https://sso.tax/), and about half our vendors grew by 20-50%. What's more, it was basically impossible to get any transparency in pricing. One year, our Heroku bill was 100k, the next year, it was 200k for practically the same usage, all of it negotiated over email, with no idea what kinds of discounts our peers were getting.

### Year 2, 3...
Costs only grew from here. Peaking at a ~$1M in annual spend within 4 years.

A large chunk of the tools we were using have open source versions, or open source alternatives, but we could never justify hosting them ourselves since we really had no idea what to expect. Most open source installations were simple enough, normally just expecting a server that we can run them on. But what about health checks? What about monitoring? What about alerting? What about logging? There must be something better.

### Year 4:
We started our migration to move off some of our more expensive infrastructure providers, and quick discovered that it's not that easy. I won't go into the full details, but just to give you an idea, one task that took a few weeks to resolve was chasing down and upgrading all the integrations that pinned our production IP's for security reasons, that we aren't able to take with us to the new infrastructure. The net result was that we cut costs by over 70% but it was a major, major project.

# So, why Canine?

## Reason #1: Kubernetes scales, but is hard to manage

Kubernetes is amazing. The same platform can be run on single node, and then scaled to [tens of thousands](https://thenewstack.io/scaling-to-10000-kubernetes-clusters-without-missing-a-beat/). It can run a single [Raspberry Pi](https://faun.pub/single-node-kubernetes-on-a-raspberry-pi-cb93a4300305) to a [massively distributed edge clusters](https://medium.com/chick-fil-atech/observability-at-the-edge-b2385065ab6e). It's supported by [basically](https://www.digitalocean.com/products/kubernetes) [every](https://www.linode.com/lp/kubernetes/) [single](https://www.vultr.com/kubernetes/) [cloud](https://aws.amazon.com/eks/) [provider](https://cloud.google.com/kubernetes-engine) in a (mostly) standardized way. I learned to love Kubernetes, while also learning the hard way it can be excruciatingly easy to accidentally delete essential services like CoreDNS, and totally bork your cluster. Kubernetes is notorious for being difficult and over complex for startups and small teams, who are normally steered to more out of the box solutions. I also learned the hard way that eventually, many of these solutions don't scale, **especially when it comes to cost**, and moving off the infrstructure is a nightmare.

Canine is an attempt to allow one-man teams to adopt Kubernetes. But for almost all web applications, you only need a tiny slice of what it has to offer: Ingress, Services, Deployments, Pods and CronJobs. Canine tries to expose just this slice.

It sits entirely on top of your own Kubernetes cluster, and all of the YAML configurations are downloadable, in case you want to migrate away from Canine.

It also makes up for some of the defects that are missing from out-of-the-box Kubernetes that are absolutely essential for a software development team such as
* Accounts
* Deployment
* Simple one-off scripts
* Metrics dashboard

## Reason #2: The rich ecosystem of third party applications

Helm is a package manager for Kubernetes that makes it trivial to host third party applications. Thanks to Helm, basically every single open source software application can be easily hosted through Canine. This makes it trivially easy to, for instance, deploy a hosted version of Sentry! See the full list of supported applications [here](https://artifacthub.io/).

Give Canine a whirl, on your [own system](https://github.com/czhu12/canine), or a [hosted version](https://canine.sh), completely free.

Cheers,
<img src="/images/signature.png" style="height: 60px; transform: rotate(-7deg); margin:0;" />


<sub>
_\* No VC money was raised in the building of this product_
</sub>
