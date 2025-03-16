Chartkick.options = {
  height: "400px",
  colors: [ "#4f46e5", "#06b6d4", "#10b981", "#f59e0b", "#ef4444" ],
  dataset: {
    fill: true,
    borderColor: 'rgba(75, 192, 192, 1)',
    backgroundColor: 'rgba(75, 192, 192, 0.2)',
    tension: 0.1,
    pointRadius: 0,
    pointHoverBorderColor: 'rgba(75, 192, 192, 1)',
    pointHoverBackgroundColor: 'rgba(75, 192, 192, 0.2)'
  },
  library: {
    font: {
      family: "'DM Sans', sans-serif"
    },
    plugins: {
      legend: {
        labels: {
          color: "#e5e7eb"  # Light gray text for labels
        }
      }
    },
    scales: {
      x: {
        ticks: { color: "#e5e7eb" },
        grid: { color: "#374151" },
        title: {
          display: true,
          color: "#e5e7eb"  # Light gray for x-axis title
        }
      },
      y: {
        ticks: { color: "#e5e7eb" },
        grid: { color: "#374151" },
        title: {
          display: true,
          color: "#e5e7eb"  # Light gray for y-axis title
        }
      }
    },
    elements: {
      point: {
        backgroundColor: "#fff"
      }
    }
  }
}
