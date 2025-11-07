import { Chart } from "chart.js/auto";
import { MUI_COLORS, setScales } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;
    const data = {
      type: "line",
      data: {},
      options: {
        scales: {
          x: {
            display: false,
          },
        },
        responsive: true,
        plugins: {
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
    };
    const sortByDate = (unsorted) => unsorted.sort((a, b) => new Date(a.updated_at) - new Date(b.updated_at));
    const chart = new Chart(ctx, data);

    this.handleEvent("update-player", (event) => {
      const sorted = sortByDate(event.movingAverages);
      setScales(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setScales(chart, isDark);
        chart.update();
      });

      chart.data.datasets.push(
        {
          data: sortByDate(sorted).map(({ moving_average_5g }) => moving_average_5g),
          label: "5 Game",
          borderColor: MUI_COLORS[14],
          backgroundColor: MUI_COLORS[14],
          spanGaps: true,
        },
        {
          data: sortByDate(sorted).map(({ moving_average_10g }) => moving_average_10g),
          label: "10 Game",
          borderColor: MUI_COLORS[15],
          backgroundColor: MUI_COLORS[15],
          spanGaps: true,
        },
        {
          data: sortByDate(sorted).map(({ moving_average_20g }) => moving_average_20g),
          label: "20 Game",
          borderColor: MUI_COLORS[14],
          backgroundColor: MUI_COLORS[14],
          spanGaps: true,
        }
      );
      chart.data.labels = sorted.map((m) =>
        (() => {
          const date = new Date(m.updated_at);
          const day = date.getDate();
          const month = date.toLocaleDateString(undefined, { month: "short" });
          const year = date.getFullYear().toString().slice(-2);
          return `${day}-${month}-${year}`.toUpperCase();
        })()
      );
      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-player", null);
  },
};

