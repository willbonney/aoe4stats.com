import { Chart } from "chart.js/auto";
import { MUI_COLORS, TW_STONE_800, TW_ZINC_100, getLargeTooltipConfig } from "./shared.js";

export default {
  mounted() {
    const ctx = this.el;

    const data = {
      type: "polarArea",
      data: {
        labels: [],
        datasets: [
          {
            label: "Performance Metrics",
            data: [],
            backgroundColor: [
              MUI_COLORS[0],
              MUI_COLORS[1],
              MUI_COLORS[2],
              MUI_COLORS[5],
              MUI_COLORS[7],
              MUI_COLORS[8],
              MUI_COLORS[9],
            ].map((color) => `${color.slice(0, -4)}, 0.7)`),
            borderColor: [
              MUI_COLORS[0],
              MUI_COLORS[1],
              MUI_COLORS[2],
              MUI_COLORS[5],
              MUI_COLORS[7],
              MUI_COLORS[8],
              MUI_COLORS[9],
            ],
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        scales: {
          r: {
            min: 0,
            max: 100,
            ticks: {
              stepSize: 20,
            },
            pointLabels: {
              display: true,
              centerPointLabels: true,
              font: {
                size: 14,
              },
            },
          },
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            ...getLargeTooltipConfig(),
            callbacks: {
              label: (context) => `${context.raw.toFixed(1)}%`,
            },
          },
          title: {
            display: false,
            text: "Performance Analysis",
          },
        },
      },
    };

    const chart = new Chart(ctx, data);

    const setPolarScales = (chart, isDark) => {
      const color = isDark ? TW_ZINC_100 : TW_STONE_800;
      chart.options.scales.r = {
        ...chart.options.scales.r,
        grid: {
          color: color,
        },
        angleLines: {
          color: color,
        },
        pointLabels: {
          ...chart.options.scales.r.pointLabels,
          color: color,
          font: {
            size: 22,
          },
        },
        ticks: {
          ...chart.options.scales.r.ticks,
          color: color,
          backdropColor: isDark ? "rgba(39, 39, 42, 0.8)" : "rgba(255, 255, 255, 0.8)",
        },
      };
      chart.update();
    };

    const setupHoverInteractions = (metricsWithData) => {
      const metricBoxes = document.querySelectorAll("#metric-descriptions [data-metric]");

      const metricToChartIndex = {};
      metricsWithData.forEach((metric, index) => {
        metricToChartIndex[metric.label] = index;
      });

      metricBoxes.forEach((box) => {
        const metricName = box.getAttribute("data-metric");
        const chartIndex = metricToChartIndex[metricName];

        if (chartIndex !== undefined) {
          box.addEventListener("mouseenter", () => {
            const activeElements = [
              {
                datasetIndex: 0,
                index: chartIndex,
              },
            ];
            chart.setActiveElements(activeElements);
            chart.tooltip.setActiveElements(activeElements);
            chart.update();
          });

          box.addEventListener("mouseleave", () => {
            chart.setActiveElements([]);
            chart.tooltip.setActiveElements([]);
            chart.update();
          });
        }
      });
    };

    this.handleEvent("update-analysis", (event) => {
      const analysis = event.analysis;

      const allMetrics = [
        { key: "peak_proximity", label: "Peak Proximity", colorIndex: 13 },
        { key: "recovery", label: "Recovery", colorIndex: 9 },
        { key: "momentum", label: "Momentum", colorIndex: 16 },
        { key: "anti_tilt", label: "Anti-Tilt", colorIndex: 11 },
        { key: "pressure_performance", label: "Pressure", colorIndex: 2 },
        { key: "rating_efficiency", label: "Efficiency", colorIndex: 4 },
        { key: "versatility", label: "Versatility", colorIndex: 17 },
        { key: "underdog_success", label: "Underdog Power", colorIndex: 0 },
      ];

      const metrics = allMetrics.filter((m) => analysis.hasOwnProperty(m.key));

      chart.data.labels = metrics.map((m) => m.label);
      chart.data.datasets[0].data = metrics.map((m) => analysis[m.key]);

      const colors = metrics.map((m) => MUI_COLORS[m.colorIndex]);
      chart.data.datasets[0].backgroundColor = colors.map((color) => `${color.slice(0, -4)}, 0.7)`);
      chart.data.datasets[0].borderColor = colors;

      setPolarScales(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setPolarScales(chart, isDark);
      });

      chart.update();

      setTimeout(() => setupHoverInteractions(metrics), 100);
    });
  },
  beforeUnmount() {
    this.handleEvent("update-analysis", null);
  },
};
