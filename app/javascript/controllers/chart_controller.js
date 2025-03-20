import { Controller } from "@hotwired/stimulus"
import ApexCharts from 'apexcharts';

export default class extends Controller {
  static values = {
    config: Object
  }

  connect() {
    const chart = new ApexCharts(this.element, {
      chart: {
        type: 'area',
        height: 400,
        background: "transparent",
        toolbar: {
          show: true,
          tools: {
              download: true,
              zoom: false,
              zoomin: false,
              zoomout: false,
              pan: false,
              reset: false,
          },
        },
      },
      colors: ["#167bff"],
      fill: {
          type: "solid",
          opacity: 0.6,
      },
      dataLabels: {
        enabled: false,
      },
      legend: {
          show: true,
          position: "top",
      },

      series: [{
        name: 'sales',
        data: this.configValue.data.map(d => d.y)
      }],
      xaxis: {
        categories: this.configValue.data.map(d => new Date(d.x)),
        labels: {
          labels: {
            format: 'dd/MM',
          }
        }
      }
    })
    chart.render();

  }
}