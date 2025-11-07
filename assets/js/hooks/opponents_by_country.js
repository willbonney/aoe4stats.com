import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import { MUI_COLORS, COUNTRY_UTILS, getDistributedColors } from "./shared.js";

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
                    .map(([country, percentage]) => `${COUNTRY_UTILS.getDisplayName(country)}: ${percentage}%`);

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
          legend: {
            position: "top",
            display: false,
          },
          title: {
            display: false,
            text: "Opponents by Country",
          },
          alwaysShowTooltip: {
            valueFormatter: (value) => `${value.toFixed(0)}%`,
            skipLabels: ["other"],
          },
        },
      },
    };
    const chart = new Chart(ctx, data);
    this.handleEvent("update-opponents-by-country", (event) => {
      const threshold = 3;
      let otherPercentage = 0;
      const otherCountries = {};
      const filteredData = Object.entries(event.byCountry).reduce((acc, [country, percentage]) => {
        if (percentage >= threshold) {
          acc[country] = percentage;
        } else {
          otherPercentage += percentage;
          if (!otherCountries[country]) {
            otherCountries[country] = percentage;
          } else {
            otherCountries[country] += percentage;
          }
        }
        return acc;
      }, {});

      if (otherPercentage > 0) {
        filteredData.other = otherPercentage;
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
    this.handleEvent("update-opponents-by-country", null);
  },
};

