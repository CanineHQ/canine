import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart"]
  static values = {
    prices: Object
  }

  connect() {
    this.computed = {
      team: {
        'team-size': 1,
      },
      web: {
        'web-cpu': 0.5,
        'web-memory': 0.5,
        'web-instances': 1,
      },
      worker: {
        'worker-cpu': 0.5,
        'worker-memory': 0.5,
        'worker-instances': 0,
      },
    }

    // Initialize sliders and pricing on page load
    this.calculateAll();
  }

  renderChart(breakdowns) {
    const data = breakdowns.map(b => {
      const { service, breakdown } = b;
      if (breakdown.error) {
        return null;
      }
      const serviceName = this.pricesValue[service].name;
      const color = this.pricesValue[service].color;
      return {
        breakdown,
        serviceName,
        color,
      }
    }).filter(b => b !== null);

    let chartStatus = Chart.getChart("price-chart");
    if (chartStatus != undefined) {
      chartStatus.destroy();
    }
    Chart.defaults.color = '#fff';

    new Chart(this.chartTarget, {
      type: 'bar',
      data: {
        labels: data.map(b => b.serviceName),
        datasets: [{
          label: 'Cost',
          backgroundColor: data.map(b => b.color),
          borderColor: data.map(b => b.color),
          borderWidth: 1,
          data: data.map(b => this.cost(b.breakdown)),
        }]
      },
      options: {
        plugins: {
          datalabels: {
            anchor: 'end',
            align: 'top',
            offset: 4,
            formatter: function(value) {
              return '$' + value;
            },
            font: {
              weight: 'bold',
              size: 14
            }
          },
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function (context) {
                return '$' + context.formattedValue;
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            suggestedMax: Math.max(...data.map(b => this.cost(b.breakdown))) * 1.2,
            ticks: {
              callback: function (value) {
                return '$' + value;
              }
            }
          }
        }
      },
      plugins: [ChartDataLabels]
    });
  }

  instanceSize(tiers, cpuNeeded, memoryNeeded) {
    for (let i = 0; i < tiers.length; i++) {
      if (cpuNeeded <= tiers[i].cpu && memoryNeeded <= tiers[i].memory) {
        return { instanceNeeded: tiers[i], i }
      }
    }
    return { instanceNeeded: null, i: -1 }
  }

  calculateBreakdown(service) {
    const prices = this.pricesValue[service]
    const costs = []
    costs.push({ text: "Team", cost: prices.seat * this.computed.team['team-size'] })

    const webCpuNeeded = this.computed.web['web-cpu']
    const webMemoryNeeded = this.computed.web['web-memory']
    const { instanceNeeded: webInstanceNeeded, i: webInstanceIndex } = this.instanceSize(prices.tiers, webCpuNeeded, webMemoryNeeded)
    const webReplicas = this.computed.web['web-instances']

    if (webInstanceNeeded) {
      costs.push({
        text: `Web - ${webInstanceNeeded.name} (${webReplicas}x)`,
        cost: prices.tiers[webInstanceIndex].price * webReplicas,
      })
    } else {
      return {
        error: 'Contact Sales',
      }
    }

    const workerCpuNeeded = this.computed.worker['worker-cpu']
    const workerMemoryNeeded = this.computed.worker['worker-memory']
    const { instanceNeeded: workerInstanceNeeded, i: workerInstanceIndex } = this.instanceSize(prices.tiers, workerCpuNeeded, workerMemoryNeeded)
    const workerReplicas = this.computed.worker['worker-instances']

    if (workerInstanceNeeded) {
      costs.push({
        text: `Worker - ${workerInstanceNeeded.name} (${workerReplicas}x)`,
        cost: prices.tiers[workerInstanceIndex].price * workerReplicas,
      })
    } else {
      return {
        error: 'Contact Sales',
      }
    }

    return costs
  }

  calculateAll() {
    const services = ["heroku", "render", "digitalocean", "hetzner"];
    const breakdowns = services.map(service => {
      const breakdown = this.calculateBreakdown(service);
      this.place(this.render(service, breakdown), `${service.toLowerCase()}-breakdown`);
      return { breakdown, service }
    });
    this.renderChart(breakdowns);
  }

  place(html, id) {
    const el = document.createElement('div')
    el.classList.add('border-t', 'border-slate-700', 'py-4')
    el.innerHTML = html
    const container = document.getElementById(id);
    container.innerHTML = '';
    container.appendChild(el);
  }

  cost(breakdown) {
    return breakdown.reduce((sum, b) => sum + (typeof b.cost === 'number' ? b.cost : 0), 0);
  }
  render(service, breakdown) {
    const serviceName = this.pricesValue[service].name
    if (breakdown.error) {
      return `
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center">
          <span class="font-medium">${serviceName}</span>
        </div>
        <div class="text-red-400 font-semibold total-cost">${breakdown.error}</div>
      </div>
      `
    }
    const total = this.cost(breakdown);
    const header = `
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center">
          <span class="font-medium">${serviceName}</span>
        </div>
        <div class="text-emerald-400 font-semibold total-cost">${total == 0 ? 'FREE' : `$${total}.00`}</div>
      </div>
    `
    return header + breakdown.map(row => {
      return `
        <div class="grid grid-cols-2 gap-2 text-sm mb-1">
          <div class="text-sm text-slate-400 mb-1">${row.text}</div>
          <div class="text-right web-cost">${row.cost == 0 ? '—' : `$${row.cost}`}</div>
        </div>
      `
    }).join('');
  }

  sliderChanged(event) {
    const type = event.target.dataset.type;
    const service = event.target.dataset.service;
    this._set(`${service}.${type}`, event.target.value, this.computed)
    document.getElementById(`${type}-value`).innerHTML = event.target.value
    this.calculateAll();
  }

  _set(key, value, object) {
    // Split the key by dots to handle nested properties
    const keys = key.split('.');
    const lastKey = keys.pop();
    const lastObj = keys.reduce((obj, k) => {
      // Create nested object if it doesn't exist
      if (!obj[k]) obj[k] = {};
      return obj[k];
    }, object);

    // Set the final value
    lastObj[lastKey] = value;
    return object;
  }
}
