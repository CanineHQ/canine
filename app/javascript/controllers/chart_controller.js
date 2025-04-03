import { Controller } from "@hotwired/stimulus"
import ApexCharts from 'apexcharts';

const PADDING = 0.1; // 10% padding on the y-axis
export default class extends Controller {
  static values = {
    config: Object
  }

  connect() {
    const title = this.configValue.title
    const chart = new ApexCharts(this.element, {
      chart: {
        foreColor: '#fff',
        type: 'area',
        height: 400,
        background: "transparent",
        toolbar: {
          show: false
        },
        zoom: {
          enabled: false
        }
      },
      stroke: {
        curve: 'smooth',
        width: 2
      },
      colors: ["#6366f1", "#38bdf8", "#9ca3af"],
      grid: {
        borderColor: '#1f2937',
        strokeDashArray: 4,
        xaxis: {
          lines: {
            show: true
          }
        },
        yaxis: {
          lines: {
            show: true
          }
        }
      },
      dataLabels: {
        enabled: false
      },
      markers: {
        size: 0,
        hover: {
          size: 0
        }
      },
      tooltip: {
        theme: 'dark',
        style: {
          background: '#1f2937'
        },
        x: {
          show: true,
          name: title,
          format: 'h:mm:ss TT'
        }
      },
      series: this.configValue.data.map(series => ({
        name: series.name,
        data: series.values.map(d => this.value(d))
      })),
      xaxis: {
        type: 'datetime',
        categories: this.configValue.data[0].values.map(d => d.x),
        labels: {
          style: {
            colors: '#9ca3af'
          },
          format: 'h:mm:ss TT',
          datetimeUTC: false
        },
        axisBorder: {
          show: false
        },
        axisTicks: {
          show: false
        }
      },
      yaxis: {
        labels: {
          style: {
            colors: '#9ca3af'
          },
          formatter: (value) => {
            if (this.configValue.metric_display === "percentage") {
              return value + '%'
            }
            return value + this.unit()
          }
        },
        min: this.suggestedMinY(),
        max: this.suggestedMaxY(),
      }
    })
    chart.render();
  }

  value(point) {
    if (this.configValue.metric_display === "percentage") {
      return Math.round(100.0 * point.value / point.total * 10) / 10
    }
    return this.formatBytes(point.value);
  }

  formatBytes(bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    let value = bytes;
    let unitIndex = 0;
    
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024.0;
      unitIndex++;
    }
    
    return Math.round(value * 10) / 10;
  }

  unit() {
    if (this.configValue.metric_display === "percentage") {
      return '%';
    }
    const bytes = this.configValue.data[0]?.values[0]?.value || 0;
    let units;
    if (this.configValue.metric_type === "cpu") {
      units = ['m'];
    } else {
      units = ['B', 'KB', 'MB', 'GB'];
    }
    let value = bytes;
    let unitIndex = 0;
    
    while (value >= 1024 && unitIndex < units.length - 1) {
      value = value / 1024.0;
      unitIndex++;
    }
    
    return units[unitIndex];
  }

  suggestedMinY() {
    // Go over all the data and find the minimum y value
    const values = this.configValue.data.flatMap(d => d.values.map(this.value.bind(this)))
    let min = Infinity;
    values.forEach(d => {
      if (d < min) {
        min = d;
      }
    });
    return Math.round(Math.max(min - (min * PADDING), 0))
  }

  suggestedMaxY() {
    // Go over all the data and find the maximum y value
    const values = this.configValue.data.flatMap(d => d.values.map(this.value.bind(this)))
    let max = -Infinity;
    values.forEach(d => {
      if (d > max) {
        max = d;
      }
    });
    return Math.round(max + (max * PADDING))
  }
}