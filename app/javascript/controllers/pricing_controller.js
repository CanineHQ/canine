import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "teamSize", "teamSizeValue",
    "webCpu", "webCpuValue", "webCpuShared", "webCpuDedicated",
    "webMemory", "webMemoryValue",
    "webInstances", "webInstancesValue",
    "webEgress", "webEgressValue",
    "workerCpu", "workerCpuValue", "workerCpuShared", "workerCpuDedicated",
    "workerMemory", "workerMemoryValue",
    "workerInstances", "workerInstancesValue",
    "provider"
  ]

  static values = {
    providers: Array
  }

  connect() {
    // Initialize sliders and pricing on page load
    this.updatePricing()
  }

  // Handle slider input changes
  teamSizeTargetInput() {
    this.teamSizeValueTarget.textContent = this.teamSizeTarget.value
    this.updatePricing()
  }

  webCpuTargetInput() {
    this.webCpuValueTarget.textContent = this.webCpuTarget.value
    this.updatePricing()
  }

  webMemoryTargetInput() {
    this.webMemoryValueTarget.textContent = this.webMemoryTarget.value
    this.updatePricing()
  }

  webInstancesTargetInput() {
    this.webInstancesValueTarget.textContent = this.webInstancesTarget.value
    this.updatePricing()
  }

  webEgressTargetInput() {
    this.webEgressValueTarget.textContent = this.webEgressTarget.value
    this.updatePricing()
  }

  workerCpuTargetInput() {
    this.workerCpuValueTarget.textContent = this.workerCpuTarget.value
    this.updatePricing()
  }

  workerMemoryTargetInput() {
    this.workerMemoryValueTarget.textContent = this.workerMemoryTarget.value
    this.updatePricing()
  }

  workerInstancesTargetInput() {
    this.workerInstancesValueTarget.textContent = this.workerInstancesTarget.value
    this.updatePricing()
  }

  // Toggle CPU mode between shared and dedicated
  toggleWebCpuMode(event) {
    const isShared = event.currentTarget === this.webCpuSharedTarget
    
    if (isShared) {
      this.webCpuSharedTarget.classList.add('bg-emerald-500')
      this.webCpuSharedTarget.classList.remove('bg-slate-700')
      this.webCpuDedicatedTarget.classList.add('bg-slate-700')
      this.webCpuDedicatedTarget.classList.remove('bg-emerald-500')
    } else {
      this.webCpuDedicatedTarget.classList.add('bg-emerald-500')
      this.webCpuDedicatedTarget.classList.remove('bg-slate-700')
      this.webCpuSharedTarget.classList.add('bg-slate-700')
      this.webCpuSharedTarget.classList.remove('bg-emerald-500')
    }
    
    this.updatePricing()
  }

  // Toggle worker CPU mode
  toggleWorkerCpuMode(event) {
    const isShared = event.currentTarget === this.workerCpuSharedTarget
    
    if (isShared) {
      this.workerCpuSharedTarget.classList.add('bg-emerald-500')
      this.workerCpuSharedTarget.classList.remove('bg-slate-700')
      this.workerCpuDedicatedTarget.classList.add('bg-slate-700')
      this.workerCpuDedicatedTarget.classList.remove('bg-emerald-500')
    } else {
      this.workerCpuDedicatedTarget.classList.add('bg-emerald-500')
      this.workerCpuDedicatedTarget.classList.remove('bg-slate-700')
      this.workerCpuSharedTarget.classList.add('bg-slate-700')
      this.workerCpuSharedTarget.classList.remove('bg-emerald-500')
    }
    
    this.updatePricing()
  }

  // Get all configuration values
  getConfig() {
    return {
      teamSize: parseInt(this.teamSizeTarget.value),
      webCpu: parseFloat(this.webCpuTarget.value),
      webMemory: parseFloat(this.webMemoryTarget.value),
      webInstances: parseInt(this.webInstancesTarget.value),
      webEgress: parseInt(this.webEgressTarget.value),
      workerCpu: parseFloat(this.workerCpuTarget.value),
      workerMemory: parseFloat(this.workerMemoryTarget.value),
      workerInstances: parseInt(this.workerInstancesTarget.value),
      isWebCpuShared: this.webCpuSharedTarget.classList.contains('bg-emerald-500'),
      isWorkerCpuShared: this.workerCpuSharedTarget.classList.contains('bg-emerald-500')
    }
  }

  // Calculate pricing for all providers
  updatePricing() {
    const config = this.getConfig()
    
    // Calculate pricing for each provider
    const results = this.calculateAllProviderPricing(config)
    
    // Update UI with calculated prices
    this.updateUI(results)
    
    // Highlight the cheapest option
    this.highlightCheapestProvider(results)
  }

  // Calculate pricing for all providers
  calculateAllProviderPricing(config) {
    return {
      railway: this.calculateRailwayPricing(config),
      heroku: this.calculateHerokuPricing(config),
      fly: this.calculateFlyPricing(config),
      render: this.calculateRenderPricing(config)
    }
  }

  // Calculate Railway pricing
  calculateRailwayPricing(config) {
    const cpuCost = config.webCpu * (config.isWebCpuShared ? 20 : 30) * config.webInstances
    const memoryCost = config.webMemory * 20 * config.webInstances
    const egressCost = config.webEgress * 0.5
    const workerCpuCost = config.workerCpu * (config.isWorkerCpuShared ? 20 : 30) * config.workerInstances
    const workerMemoryCost = config.workerMemory * 20 * config.workerInstances
    
    const total = cpuCost + memoryCost + egressCost + workerCpuCost + workerMemoryCost
    
    return {
      webCpuCost: cpuCost,
      webMemoryCost: memoryCost,
      webEgressCost: egressCost,
      workerCpuCost: workerCpuCost,
      workerMemoryCost: workerMemoryCost,
      total: total
    }
  }

  // Calculate Heroku pricing
  calculateHerokuPricing(config) {
    const webCost = config.webInstances * 250
    const workerCost = config.workerInstances * 50
    const total = webCost + workerCost
    
    return {
      webCost: webCost,
      workerCost: workerCost,
      total: total
    }
  }

  // Calculate Fly pricing
  calculateFlyPricing(config) {
    const cpuCost = config.webInstances * (config.isWebCpuShared ? 14.24 : 28.48)
    const egressCost = config.webEgress * 0.02
    const workerCost = config.workerInstances * (config.isWorkerCpuShared ? 7.12 : 14.24)
    const total = cpuCost + egressCost + workerCost
    
    return {
      webCpuCost: cpuCost,
      webEgressCost: egressCost,
      workerCost: workerCost,
      total: total
    }
  }

  // Calculate Render pricing
  calculateRenderPricing(config) {
    const webCost = config.webInstances * 43.80
    const egressCost = config.webEgress * 4.375
    const workerCost = config.workerInstances * 25
    const total = webCost + egressCost + workerCost
    
    return {
      webCost: webCost,
      webEgressCost: egressCost,
      workerCost: workerCost,
      total: total
    }
  }

  // Update UI with calculated prices
  updateUI(results) {
    // Update Railway UI
    this.updateProviderUI('railway', results.railway)
    
    // Update Heroku UI
    this.updateProviderUI('heroku', results.heroku)
    
    // Update Fly UI
    this.updateProviderUI('fly', results.fly)
    
    // Update Render UI
    this.updateProviderUI('render', results.render)
  }

  // Update UI for a specific provider
  updateProviderUI(provider, pricing) {
    const providerElement = this.findProviderElement(provider)
    
    if (!providerElement) return
    
    // Update total cost
    const totalElement = providerElement.querySelector('.total-cost')
    if (totalElement) {
      totalElement.textContent = `$${pricing.total.toFixed(2)}`
    }
    
    // Update individual cost components based on provider
    if (provider === 'railway') {
      this.updateElementText(providerElement, '.webCpuCost', pricing.webCpuCost)
      this.updateElementText(providerElement, '.webMemoryCost', pricing.webMemoryCost)
      this.updateElementText(providerElement, '.webEgressCost', pricing.webEgressCost)
      this.updateElementText(providerElement, '.workerCpuCost', pricing.workerCpuCost)
      this.updateElementText(providerElement, '.workerMemoryCost', pricing.workerMemoryCost)
    } else if (provider === 'heroku') {
      this.updateElementText(providerElement, '.webCost', pricing.webCost)
      this.updateElementText(providerElement, '.workerCost', pricing.workerCost)
    } else if (provider === 'fly') {
      this.updateElementText(providerElement, '.webCpuCost', pricing.webCpuCost)
      this.updateElementText(providerElement, '.webEgressCost', pricing.webEgressCost)
      this.updateElementText(providerElement, '.workerCost', pricing.workerCost)
    } else if (provider === 'render') {
      this.updateElementText(providerElement, '.webCost', pricing.webCost)
      this.updateElementText(providerElement, '.webEgressCost', pricing.webEgressCost)
      this.updateElementText(providerElement, '.workerCost', pricing.workerCost)
    }
  }

  // Helper to update element text with formatted price
  updateElementText(parent, selector, value) {
    const element = parent.querySelector(selector)
    if (element) {
      element.textContent = `$${value.toFixed(2)}`
    }
  }

  // Find provider element by name
  findProviderElement(provider) {
    return this.providerTargets.find(el => el.dataset.provider === provider)
  }

  // Highlight the cheapest provider
  highlightCheapestProvider(results) {
    const providers = Object.keys(results)
    const totals = providers.map(provider => results[provider].total)
    
    // Find the cheapest provider
    const minTotal = Math.min(...totals)
    const cheapestProviderIndex = totals.indexOf(minTotal)
    const cheapestProvider = providers[cheapestProviderIndex]
    
    // Remove highlight from all providers
    this.providerTargets.forEach(provider => {
      const totalElement = provider.querySelector('.total-cost')
      if (totalElement) {
        totalElement.classList.remove('text-green-300', 'font-bold')
        totalElement.classList.add('text-emerald-400')
      }
    })
    
    // Add highlight to cheapest provider
    const cheapestElement = this.findProviderElement(cheapestProvider)
    if (cheapestElement) {
      const totalElement = cheapestElement.querySelector('.total-cost')
      if (totalElement) {
        totalElement.classList.remove('text-emerald-400')
        totalElement.classList.add('text-green-300', 'font-bold')
      }
    }
  }
}
