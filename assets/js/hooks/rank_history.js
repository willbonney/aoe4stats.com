import { Chart } from "chart.js/auto";
import { MUI_COLORS, setScales } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;

    const totalDuration = 2500;
    const getDatasetLength = (ctx) => {
      if (ctx?.chart?.data?.datasets?.length > 0 && typeof ctx?.datasetIndex === "number") {
        return ctx.chart.data.datasets[ctx.datasetIndex].data.length;
      }
      return 100;
    };
    const data = {
      type: "line",
      data: {},
      options: {
        animation: {
          x: {
            easing: "easeOutQuad",
            type: "number",
            duration(ctx) {
              const datasetLength = getDatasetLength(ctx);
              return ((ctx.index / datasetLength) * totalDuration) / datasetLength;
            },
            delay(ctx) {
              const datasetLength = getDatasetLength(ctx);

              if (ctx.type !== "data" || ctx.xStarted) {
                return 0;
              }
              ctx.xStarted = true;
              return (ctx.index / datasetLength) * totalDuration;
            },
          },
          y: {
            type: "number",
            easing: "easeOutQuad",
            duration(ctx) {
              const datasetLength = getDatasetLength(ctx);
              return ((ctx.index / datasetLength) * totalDuration) / datasetLength;
            },
            from: NaN,
            delay(ctx) {
              const datasetLength = getDatasetLength(ctx);

              if (ctx.type !== "data" || ctx.yStarted) {
                return 0;
              }
              ctx.yStarted = true;
              return (ctx.index / datasetLength) * totalDuration;
            },
          },
        },
        responsive: true,
        layout: {
          padding: {
            right: 30,
          },
        },
        scales: {
          y: {
            reverse: true,
            min: 1,
            title: {
              display: true,
              text: "Rank",
            },
            ticks: {
              callback: function (value) {
                return `#${value.toFixed(0).toLocaleString()}`;
              },
            },
          },
        },
        plugins: {
          legend: {
            position: "top",
            display: false,
          },
          title: {
            display: false,
            text: "Rank History",
          },
        },
      },
    };

    const chart = new Chart(ctx, data);
    this.handleEvent("update-player", (event) => {
      setScales(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setScales(chart, isDark);
        chart.update();
      });

      if (!event.rankHistory || event.rankHistory.length === 0) {
        console.warn("No rank history data available");
        return;
      }

      const rankData = event.rankHistory.map(({ rank }) => rank).reverse();
      const maxRankValue = Math.max(...rankData);

      chart.data.datasets.push({
        data: rankData,
        label: "Rank",
        pointStyle: "circle",
        pointRadius: 10,
        pointHoverRadius: 15,
        fill: false,
        stepped: true,
        borderColor: MUI_COLORS[1],
        backgroundColor: MUI_COLORS[1],
      });
      chart.data.labels = event.rankHistory.map((m) => `Season ${m.season}`).reverse();

      chart.options.scales.y.max = 1.2 * maxRankValue;
      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-player", null);
  },
};

