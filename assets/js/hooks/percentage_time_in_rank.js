import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import { MUI_COLORS } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;

    const data = {
      type: "doughnut",
      data: {
        datasets: [
          {
            data: [],
            backgroundColor: MUI_COLORS,
          },
        ],
      },
      plugins: [AlwaysShowTooltipPlugin],

      options: {
        responsive: true,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.raw.toFixed(0)}%`,
              afterBody: function (context) {
                if (!context || !context[0]) {
                  return [];
                }

                const label = context[0].label;

                if (label === "other" && chart.otherRanks) {
                  const otherRanks = Object.entries(chart.otherRanks)
                    .filter(([rank, percentage]) => percentage > 0)
                    .map(([rank, percentage]) => `${rank}: ${percentage.toFixed(1)}%`);

                  return ["", ...otherRanks];
                }
                return [];
              },
            },
            filter: function (tooltipItem) {
              const label = tooltipItem.label || "";
              return label.toLowerCase().includes("other");
            },
          },
          labels: {
            font: {
              size: 14,
            },
          },
          title: {
            display: false,
            text: "Percentage Time in Rank",
          },
          alwaysShowTooltip: {
            color: "white",
            fontSize: 14,
            fontWeight: 400,
            valueFormatter: (value) => `${value.toFixed(0)}%`,
            skipLabels: ["other"],
          },
        },
      },
    };

    const chart = new Chart(ctx, data);
    this.handleEvent("update-player", (event) => {
      const percentageTimeInRank = event.percentageTimeInRank;

      if (!percentageTimeInRank) {
        return;
      }

      const threshold = 3;
      let otherPercentage = 0;
      const otherRanks = {};
      const filteredData = Object.entries(percentageTimeInRank).reduce((acc, [rank, data]) => {
        if (data.percentage >= threshold) {
          acc[rank] = data;
        } else {
          otherPercentage += data.percentage;
          otherRanks[rank] = data.percentage;
        }
        return acc;
      }, {});

      if (otherPercentage > 0) {
        filteredData.other = {
          percentage: otherPercentage,
          color: MUI_COLORS[3],
        };
        chart.otherRanks = otherRanks;
      } else {
        chart.otherRanks = null;
      }

      const data = Object.values(filteredData).map((item) => item.percentage);
      const colors = Object.values(filteredData).map((item) => item.color);
      const labels = Object.keys(filteredData);

      chart.data.datasets[0].data = data;
      chart.data.datasets[0].backgroundColor = colors;
      chart.data.labels = labels;

      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-percentage-time-in-rank", null);
  },
};
