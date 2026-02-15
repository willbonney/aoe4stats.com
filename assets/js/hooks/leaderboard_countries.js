import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import { COUNTRY_UTILS, getDistributedColors, MUI_COLORS } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;
    const data = {
      type: "doughnut",
      data: {
        datasets: [
          {
            data: [],
            backgroundColor: MUI_COLORS.slice(0, 19),
          },
        ],
        hoverOffset: 4,
        borderJoinStyle: "bevel",
      },
      plugins: [AlwaysShowTooltipPlugin],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          tooltip: {
            callbacks: {
              label: (context) => `${context.formattedValue}%`,
              afterBody: function (context) {
                if (!context || !context[0]) {
                  return [];
                }

                const label = context[0].label;

                if (label === "Other" && chart.otherCountries) {
                  const otherCountries = Object.entries(chart.otherCountries)
                    .sort(([, a], [, b]) => b - a)
                    .map(([country, value]) => `${COUNTRY_UTILS.getDisplayName(country)}: ${value}%`);

                  return ["", ...otherCountries];
                }
                return [];
              },
            },
            backgroundColor: "rgba(0, 0, 0, 0.9)",
            titleColor: "white",
            bodyColor: "white",
            borderColor: "rgba(255, 255, 255, 0.2)",
            borderWidth: 1,
            cornerRadius: 8,
            displayColors: false,
            padding: 16,
            bodyFont: {
              size: 14,
            },
            titleFont: {
              size: 16,
              weight: "bold",
            },
            filter: function (tooltipItem) {
              const label = tooltipItem.label || "";
              return label.toLowerCase().includes("other");
            },
          },
          labels: {
            font: {
              size: 12,
            },
          },
          legend: {
            position: "right",
            display: false,
            labels: {
              font: {
                size: 12,
              },
              padding: 10,
              usePointStyle: true,
            },
          },
          title: {
            display: false,
            text: "Conqueror Players by Country",
          },
          alwaysShowTooltip: {
            fontSize: 14,
            fontWeight: 400,
            valueFormatter: (value) => `${value.toFixed(1)}%`,
            skipLabels: ["other"],
          },
        },
      },
    };

    const chart = new Chart(ctx, data);

    this.handleEvent("update-leaderboard-countries", (event) => {
      const threshold = 2;
      let otherValue = 0;
      const otherCountries = {};
      const filteredData = Object.entries(event.byCountry).reduce((acc, [country, value]) => {
        if (value >= threshold) {
          acc[country] = value;
        } else {
          otherValue += value;
          if (!otherCountries[country]) {
            otherCountries[country] = value;
          } else {
            otherCountries[country] += value;
          }
        }
        return acc;
      }, {});

      if (otherValue > 0) {
        filteredData.other = otherValue;
      }

      const colorCount = Object.keys(filteredData).length;
      chart.data.datasets[0].backgroundColor = getDistributedColors(colorCount);

      chart.data.datasets[0].data = Object.values(filteredData);
      chart.data.labels = Object.keys(filteredData).map((country) =>
        country === "other" ? "Other" : COUNTRY_UTILS.getDisplayName(country)
      );

      chart.otherCountries = otherCountries;

      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-leaderboard-countries", null);
  },
};
