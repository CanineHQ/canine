import ApexCharts from "apexcharts";
const ORDERED_COLORS = [
  "#a25772",
  "#3e5eff"
];


class Apex {
  constructor(element, datasets) {
    this.element = element;
    this.datasets = datasets;
    this.xAxis = this.datasets.map(d => d.metrics.map(m => new Date(m.created_at))).flat().sort();
  }

  options() {
    return {
      chart: {
        events: {
          mounted: (c) => c.windowResizeHandler(),
        },
        type: "line",
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
        group: "metrics",
      },
      theme: {
        mode: 'dark',
      },
      stroke: {
        width: 2,
      },
      xaxis: {
        categories: this.xAxis,
      },
      series: this.datasets.map((dataset) => {
        let data = dataset.metrics
        if (dataset.type === "size") {
          data = data.map(m => m.value)
        } else {
          data = data.map(m => m.value)
        }
        return {
          name: dataset.name,
          data,
        }
      })
    }
  };

  createSeriesData(data, index) {
    return [{
      name: data.name,
      data: data.data,
      color: ORDERED_COLORS[index],
    }];
  }

  render() {
    var chart = new ApexCharts(this.element, this.options());
    chart.render()
    return chart;
  }
}
export default Apex;
