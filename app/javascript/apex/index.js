
import ApexCharts from "apexcharts";
const ORDERED_COLORS = [
  "#a25772",
  "#3e5eff"
];


class Apex {
  constructor(seriesData) {
    this.seriesData = seriesData;
  }

  options(id, series, formatters = {}) {
    const yAxesFormatter = formatters.yAxis ? formatters.yAxis : (value) => value;
    const toolTipFormatter = formatters.tooltip ? formatters.tooltip : (value) => value
    return {
      chart: {
        events: {
          mounted: (c) => c.windowResizeHandler(),
        },
        type: "line",
        height: 120,
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
        background: "transparent",
        id,
        group: "metrics",
      },
      theme: {
        mode: 'dark',
      },
      stroke: {
        width: 2,
      },
      yaxis: {
        labels: {
          formatter: yAxesFormatter
        },
      },
      tooltip: {
        y: {
          formatter: toolTipFormatter
        },
      },
      series
    }
  };

  createSeriesData(data, index) {
    return [{
      name: data.name,
      data: data.data,
      color: ORDERED_COLORS[index],
    }];
  }

  apexMetricContainer(length) {
    const container = document.getElementById("apex-metrics");
    container.innerHTML = "";
    for (let i = 0; i < length; i++) {
      const id = "chart-" + i;
      container.innerHTML += `<div id="${id}"></div>`;
    }
  }

  render() {
    var charts = []
    this.apexMetricContainer(this.seriesData.length);
    this.seriesData.map((series, index) => {
      var id = "chart-" + index;
      const labelFormatter = series.formatters ? series.formatters : {};
      const chartOptions = this.options(id, this.createSeriesData(series, index), labelFormatter);
      const chart = new window.ApexCharts(document.querySelector("#" + id), chartOptions);
      chart.render();
      charts.push(chart)
    });
    return charts
  }
}
window.Apex = Apex;
export default Apex;
