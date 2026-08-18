import { Chart } from "chart.js/auto";
import { TW_STONE_800, TW_ZINC_100 } from "./shared.js";

function isDarkTheme() {
  return localStorage.getItem("theme") === "dark";
}

function tickColor() {
  return isDarkTheme() ? TW_ZINC_100 : TW_STONE_800;
}

function parsePoints(raw) {
  try {
    const points = JSON.parse(raw || "[]");
    return Array.isArray(points) ? points : [];
  } catch {
    return [];
  }
}

function fiftyLine() {
  return {
    fifty: {
      type: "line",
      yMin: 50,
      yMax: 50,
      borderColor: isDarkTheme() ? "rgba(244, 244, 245, 0.7)" : "rgba(41, 37, 36, 0.65)",
      borderWidth: 2,
      borderDash: [6, 4],
      drawTime: "beforeDatasetsDraw",
    },
  };
}

export default {
  mounted() {
    this.canvas = this.el.querySelector("[data-chart='meta']");
    this.images = {};
    this.chart = this.createChart();
    this.apply();
    this.themeHandler = () => this.apply();
    window.addEventListener("themeChanged", this.themeHandler);
  },

  updated() {
    this.apply();
  },

  destroyed() {
    window.removeEventListener("themeChanged", this.themeHandler);
    this.chart?.destroy();
  },

  createChart() {
    const color = tickColor();
    return new Chart(this.canvas, {
      type: "scatter",
      data: {
        datasets: [
          {
            data: [],
            pointRadius: 11,
            pointHoverRadius: 14,
            pointStyle: [],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          annotation: { annotations: fiftyLine() },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.92)",
            padding: 12,
            displayColors: false,
            callbacks: {
              title: (items) => items[0]?.raw?.label || "",
              label: (ctx) => {
                const row = ctx.raw;
                if (!row) return null;
                return [
                  `Win rate ${row.y.toFixed(2)}%`,
                  `Pick rate ${row.x.toFixed(2)}%`,
                  `${Number(row.games_count || 0).toLocaleString()} games`,
                ];
              },
            },
          },
        },
        scales: {
          x: {
            title: { display: true, text: "Pick rate", color, font: { size: 13 } },
            ticks: { color, callback: (value) => `${value}%` },
            grid: { color: isDarkTheme() ? "rgba(244,244,245,0.12)" : "rgba(41,37,36,0.12)" },
          },
          y: {
            title: { display: true, text: "Win rate", color, font: { size: 13 } },
            ticks: { color, callback: (value) => `${value}%` },
            grid: { color: isDarkTheme() ? "rgba(244,244,245,0.12)" : "rgba(41,37,36,0.12)" },
          },
        },
      },
    });
  },

  apply() {
    const points = parsePoints(this.el.dataset.points);
    const chart = this.chart;
    if (!chart) return;

    const styles = [];
    const data = points.map((point) => {
      styles.push(this.pointStyle(point));
      return {
        x: point.pick_rate,
        y: point.win_rate,
        label: point.label,
        games_count: point.games_count,
        image: point.image,
      };
    });

    chart.data.datasets[0].data = data;
    chart.data.datasets[0].pointStyle = styles;
    chart.options.plugins.annotation.annotations = fiftyLine();
    const color = tickColor();
    chart.options.scales.x.ticks.color = color;
    chart.options.scales.y.ticks.color = color;
    chart.options.scales.x.title.color = color;
    chart.options.scales.y.title.color = color;
    chart.update();
  },

  pointStyle(point) {
    if (!point.image) return "circle";
    if (this.images[point.image]) return this.images[point.image];

    const canvas = document.createElement("canvas");
    canvas.width = 32;
    canvas.height = 22;
    this.images[point.image] = canvas;

    const img = new Image();
    img.addEventListener(
      "load",
      () => {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, 32, 22);
        ctx.drawImage(img, 1, 1, 30, 20);
        ctx.strokeStyle = "#000";
        ctx.lineWidth = 1;
        ctx.strokeRect(0.5, 0.5, 31, 21);
        this.chart?.update("none");
      },
      { once: true }
    );
    img.src = `/images/${point.image}.png`;
    return canvas;
  },
};
