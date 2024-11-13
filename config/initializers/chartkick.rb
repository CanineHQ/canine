Chartkick.options = {
  height: "400px",
  colors: [ "#4f46e5", "#06b6d4", "#10b981", "#f59e0b", "#ef4444" ],
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
