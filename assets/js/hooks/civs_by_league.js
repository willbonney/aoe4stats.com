import { Chart } from "chart.js/auto";
import { TW_STONE_800, TW_ZINC_100 } from "./shared.js";

// Generate box annotations for league backgrounds
function generateLeagueBoxAnnotations(labels, isDark = false) {
  const annotations = {};

  // League colors with transparency for light mode, opaque for dark mode
  const leagueColors = {
    Bronze: isDark ? "rgba(184, 115, 51, 0.8)" : "rgba(184, 115, 51, 0.35)",
    Silver: isDark ? "rgba(192, 192, 192, 0.8)" : "rgba(192, 192, 192, 0.35)",
    Gold: isDark ? "rgba(255, 193, 37, 0.8)" : "rgba(255, 193, 37, 0.35)",
    Platinum: isDark ? "rgba(230, 230, 230, 0.8)" : "rgba(230, 230, 230, 0.4)",
    Diamond: isDark ? "rgba(135, 206, 250, 0.8)" : "rgba(135, 206, 250, 0.35)",
    Conqueror: isDark ? "rgba(255, 165, 0, 0.8)" : "rgba(255, 165, 0, 0.35)",
  };

  labels.forEach((label, index) => {
    const color = leagueColors[label];
    if (color) {
      annotations[`league_${label.toLowerCase()}`] = {
        type: "box",
        xMin: index - 0.5,
        xMax: index + 0.5,
        backgroundColor: color,
        borderWidth: 0,
        drawTime: "beforeDatasetsDraw",
        z: -1,
      };
    }
  });

  return annotations;
}

// Generate 50% reference line annotation
function generate50PercentLine(isDark) {
  return {
    line1: {
      type: "line",
      yMin: 50,
      yMax: 50,
      borderColor: TW_STONE_800,
      borderWidth: 2,
      borderDash: [10, 5],
      drawTime: "beforeDatasetsDraw",
      z: 0,
    },
  };
}

// Apply theme-aware scale styling without calling update
function applyScaleStyles(chart, isDark) {
  const color = isDark ? TW_ZINC_100 : TW_STONE_800;

  if (chart.options.scales.y) {
    chart.options.scales.y.grid = {
      ...chart.options.scales.y.grid,
      color: color,
    };
    chart.options.scales.y.ticks = {
      ...chart.options.scales.y.ticks,
      color: color,
    };
    chart.options.scales.y.title = {
      ...chart.options.scales.y.title,
      color: color,
    };
  }

  if (chart.options.scales.x) {
    chart.options.scales.x.grid = {
      ...chart.options.scales.x.grid,
      color: color,
    };
    chart.options.scales.x.ticks = {
      ...chart.options.scales.x.ticks,
      color: color,
    };
    chart.options.scales.x.title = {
      ...chart.options.scales.x.title,
      color: color,
    };
  }
}
Chart.defaults.plugins.tooltip.titleFont = () => ({ size: 16, lineHeight: 1.2, weight: 800 });
Chart.defaults.plugins.tooltip.bodyFont = () => ({ size: 16, lineHeight: 1.2, weight: 400 });

export default {
  mounted() {
    const ctx = this.el;
    let currentLabels = [];

    const chart = new Chart(ctx, {
      defaults: {
        global: {
          font: {
            size: 16,
          },
        },
      },
      type: "line",
      data: {
        labels: [],
        datasets: [],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        interaction: {
          mode: "index",
          intersect: false,
        },
        scales: {
          y: {
            ticks: {
              callback: (val) => `${val}%`,
              font: {
                size: 16,
              },
            },
            title: {
              display: false,
              text: "Win Rate %",
            },
          },
          x: {
            offset: true,
            ticks: {
              font: {
                size: 16,
              },
            },
            title: {
              display: false,
              text: "League",
            },
            grid: {
              display: false,
            },
          },
        },
        plugins: {
          annotation: {
            annotations: {},
          },
          legend: {
            display: false,
            position: "bottom",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              padding: 16,
              font: {
                size: 11,
              },
              boxWidth: 8,
              boxHeight: 8,
            },
          },
          tooltip: {
            font: {
              size: 16,
            },
            callbacks: {
              label: (context) => {
                const value = context.parsed.y;
                if (value == null) return null;
                return `${context.dataset.label}: ${value.toFixed(2)}%`;
              },
            },
          },
          title: {
            display: false,
          },
        },
      },
    });

    // Store reference for cleanup
    this.chart = chart;

    this.handleEvent("update-civs-by-league", (event) => {
      const isDark = localStorage.getItem("theme") === "dark";

      // Update data
      chart.data.labels = event.labels;
      currentLabels = event.labels;

      chart.data.datasets = event.datasets.map((ds) => ({
        ...ds,
        pointStyle: "circle",
        pointBorderColor: ds.borderColor,
        pointBackgroundColor: ds.backgroundColor,
      }));

      // Build all annotations together
      const leagueAnnotations = generateLeagueBoxAnnotations(event.labels, isDark);
      const lineAnnotation = generate50PercentLine(isDark);

      chart.options.plugins.annotation.annotations = {
        ...leagueAnnotations,
        ...lineAnnotation,
      };

      // Apply theme-aware scale styles
      applyScaleStyles(chart, isDark);

      // Clamp Y axis between min and max values with some padding
      const allValues = event.datasets.flatMap((d) => d.data).filter((v) => v != null);

      if (allValues.length > 0) {
        const min = Math.min(...allValues);
        const max = Math.max(...allValues);
        const range = max - min;
        const padding = Math.max(range * 0.1, 1);
        chart.options.scales.y.min = Math.floor(min - padding);
        chart.options.scales.y.max = Math.ceil(max + padding);
      }

      // Single update call
      chart.update();
    });

    // Handle theme changes
    this.themeHandler = (e) => {
      const { isDark } = e.detail;

      // Update 50% line color for new theme
      const leagueAnnotations = generateLeagueBoxAnnotations(currentLabels, isDark);
      const lineAnnotation = generate50PercentLine(isDark);

      chart.options.plugins.annotation.annotations = {
        ...leagueAnnotations,
        ...lineAnnotation,
      };

      // Apply theme-aware scale styles
      applyScaleStyles(chart, isDark);

      // Single update call
      chart.update();
    };

    window.addEventListener("themeChanged", this.themeHandler);
  },

  destroyed() {
    if (this.themeHandler) {
      window.removeEventListener("themeChanged", this.themeHandler);
    }
    if (this.chart) {
      this.chart.destroy();
    }
  },
};
