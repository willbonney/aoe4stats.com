import { Chart } from "chart.js/auto";
import { MUI_COLORS, setScales, setFiftyPercentLine, getMinutesFromBucket } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;
    const data = {
      type: "bar",
      data: {},
      options: {
        responsive: true,
        scales: {
          y: {
            title: {
              display: true,
              text: "Win %",
            },
            beginAtZero: true,
          },
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.formattedValue}%`,
            },
          },
          title: {
            display: false,
            text: "WRs by Game Length",
          },
        },
      },
    };

    const chart = new Chart(ctx, data);

    this.handleEvent("update-wrs", (event) => {
      setScales(chart, localStorage.getItem("theme") === "dark");
      setFiftyPercentLine(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setScales(chart, isDark);
        setFiftyPercentLine(chart, isDark);
      });

      const split = Object.entries(event.byLength);

      const sortedSplit = split.sort((a, b) => getMinutesFromBucket(a[0]).order - getMinutesFromBucket(b[0]).order);
      console.log(sortedSplit);

      chart.data.datasets.push({
        data: sortedSplit.map(([length, wr]) => wr),
        label: "Win Rate",
        borderColor: MUI_COLORS.slice(0, sortedSplit.length),
        backgroundColor: MUI_COLORS.map((color) => `${color.slice(0, -4)}, 0.8)`).slice(0, sortedSplit.length),
        borderWidth: 1,
        barThickness: 50,
      });
      chart.data.labels = sortedSplit.map(([length]) => getMinutesFromBucket(length).label);
      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-wrs", null);
  },
};

