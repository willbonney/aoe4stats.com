import { Chart } from "chart.js/auto";
import { MUI_COLORS, TW_STONE_800, TW_ZINC_100, generateDetailedRankYAxisAnnotations } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;
    let showRankBands = false;

    const chart = new Chart(ctx, {
      type: "line",
      data: {},
      options: {
        scales: {
          x: {
            display: false,
          },
          y: {},
        },
        responsive: true,
        plugins: {
          annotation: {
            annotations: {},
          },
          tooltip: {},
          legend: {
            position: "top",
          },
          title: {
            display: false,
            text: "Moving Average",
          },
        },
      },
    });

    this.chart = chart;

    const sortByDate = (unsorted) => unsorted.sort((a, b) => new Date(a.updated_at) - new Date(b.updated_at));

    const applyScaleStyles = (isDark) => {
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
      }
    };

    const updateAnnotations = () => {
      const allData = chart.data.datasets.flatMap((ds) => ds.data).filter((v) => v != null);
      if (allData.length === 0) {
        chart.options.plugins.annotation.annotations = {};
        return;
      }

      const dataMin = Math.min(...allData);
      const dataMax = Math.max(...allData);
      const padding = (dataMax - dataMin) * 0.05 || 20;

      // Clamp Y-axis to data range with padding
      chart.options.scales.y.min = Math.floor(dataMin - padding);
      chart.options.scales.y.max = Math.ceil(dataMax + padding);

      chart.options.plugins.annotation.annotations = generateDetailedRankYAxisAnnotations(
        showRankBands,
        chart.options.scales.y.min,
        chart.options.scales.y.max
      );
    };

    this.handleEvent("update-player", (event) => {
      const sorted = sortByDate(event.movingAverages);
      const isDark = localStorage.getItem("theme") === "dark";

      applyScaleStyles(isDark);

      // Clear existing datasets and add new ones
      chart.data.datasets = [
        {
          data: sorted.map(({ moving_average_10g }) => moving_average_10g),
          label: "10 Game",
          borderColor: MUI_COLORS[14],
          backgroundColor: MUI_COLORS[14],
          spanGaps: true,
        },
        {
          data: sorted.map(({ moving_average_20g }) => moving_average_20g),
          label: "20 Game",
          borderColor: MUI_COLORS[15],
          backgroundColor: MUI_COLORS[15],
          spanGaps: true,
        },
        {
          data: sorted.map(({ moving_average_30g }) => moving_average_30g),
          label: "30 Game",
          borderColor: MUI_COLORS[16],
          backgroundColor: MUI_COLORS[16],
          spanGaps: true,
        },
      ];

      chart.data.labels = sorted.map((m) => {
        const date = new Date(m.updated_at);
        const day = date.getDate();
        const month = date.toLocaleDateString(undefined, { month: "short" });
        const year = date.getFullYear().toString().slice(-2);
        return `${day}-${month}-${year}`.toUpperCase();
      });

      updateAnnotations();
      chart.update();
    });

    this.handleEvent("toggle-league-bands", (event) => {
      showRankBands = event.show;
      updateAnnotations();
      chart.update();
    });

    this.themeHandler = (e) => {
      const { isDark } = e.detail;
      applyScaleStyles(isDark);
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
