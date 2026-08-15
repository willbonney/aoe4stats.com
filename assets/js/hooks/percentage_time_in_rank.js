import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import HtmlYLabelsPlugin from "./html_y_labels.js";
import { MUI_COLORS, TW_STONE_800, TW_ZINC_100 } from "./shared.js";

const COMPACT_BREAKPOINT = 768;
const BAR_ROW_HEIGHT = 36;

function isDarkTheme() {
  return localStorage.getItem("theme") === "dark";
}

function isCompact() {
  return window.innerWidth < COMPACT_BREAKPOINT;
}

function prepareRankData(percentageTimeInRank) {
  const threshold = 3;
  let otherPercentage = 0;
  const otherRanks = {};
  const filtered = [];

  Object.entries(percentageTimeInRank || {}).forEach(([rank, data]) => {
    if (data.percentage >= threshold) {
      filtered.push({ rank, percentage: data.percentage, color: data.color });
    } else {
      otherPercentage += data.percentage;
      otherRanks[rank] = data.percentage;
    }
  });

  filtered.sort((a, b) => b.percentage - a.percentage);

  if (otherPercentage > 0) {
    filtered.push({ rank: "other", percentage: otherPercentage, color: MUI_COLORS[3] });
  }

  return {
    labels: filtered.map((item) => (item.rank === "other" ? "Other" : item.rank)),
    values: filtered.map((item) => item.percentage),
    colors: filtered.map((item) => item.color),
    otherRanks,
  };
}

export default {
  mounted() {
    this.lastEvent = null;
    this.compact = isCompact();
    this.chart = this.createChart(this.compact);

    this.onViewportChange = () => {
      const compact = isCompact();
      if (compact === this.compact) return;
      this.compact = compact;
      this.chart?.destroy();
      this.chart = this.createChart(compact);
      if (this.lastEvent) this.applyData(this.lastEvent);
    };
    this.media = window.matchMedia(`(max-width: ${COMPACT_BREAKPOINT - 1}px)`);
    this.media.addEventListener("change", this.onViewportChange);

    this.resizeObserver = new ResizeObserver(() => {
      this.chart?.resize();
    });
    this.resizeObserver.observe(this.el.parentElement || this.el);

    this.handleEvent("update-player", (event) => {
      this.lastEvent = event;
      this.applyData(event);
    });
  },

  createChart(compact) {
    this.syncWrapHeight(compact, this.chart?.data?.labels?.length || 6);
    const tickColor = isDarkTheme() ? TW_ZINC_100 : TW_STONE_800;

    if (compact) {
      return new Chart(this.el, {
        type: "bar",
        plugins: [AlwaysShowTooltipPlugin, HtmlYLabelsPlugin],
        data: {
          labels: [],
          datasets: [
            {
              data: [],
              backgroundColor: MUI_COLORS,
              borderWidth: 0,
              borderRadius: 0,
              barPercentage: 0.75,
              categoryPercentage: 0.85,
            },
          ],
        },
        options: {
          indexAxis: "y",
          responsive: true,
          maintainAspectRatio: false,
          layout: { padding: { right: 44, top: 4, bottom: 4 } },
          plugins: {
            legend: { display: false },
            title: { display: false },
            tooltip: { enabled: false },
            alwaysShowTooltip: {
              fontSize: 12,
              fontWeight: 600,
              fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif',
              color: tickColor,
              valueFormatter: (value) => `${value.toFixed(0)}%`,
            },
          },
          scales: {
            x: {
              beginAtZero: true,
              grace: "14%",
              grid: { display: false },
              border: { display: false },
              ticks: {
                color: tickColor,
                font: { size: 11, family: 'system-ui, -apple-system, "Segoe UI", sans-serif' },
                callback: (value) => `${value}%`,
              },
            },
            y: {
              grid: { display: false },
              border: { display: false },
              ticks: { display: false },
              afterFit(scale) {
                scale.width = 120;
              },
            },
          },
        },
      });
    }

    return new Chart(this.el, {
      type: "doughnut",
      plugins: [AlwaysShowTooltipPlugin],
      data: {
        labels: [],
        datasets: [{ data: [], backgroundColor: MUI_COLORS }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (context) => `${context.raw.toFixed(0)}%`,
              afterBody: (context) => {
                if (!context?.[0] || context[0].label !== "Other" || !this.chart?.otherRanks) {
                  return [];
                }
                return [
                  "",
                  ...Object.entries(this.chart.otherRanks)
                    .filter(([, percentage]) => percentage > 0)
                    .map(([rank, percentage]) => `${rank}: ${percentage.toFixed(1)}%`),
                ];
              },
            },
            filter: (tooltipItem) => (tooltipItem.label || "").toLowerCase().includes("other"),
          },
          title: { display: false },
          alwaysShowTooltip: {
            color: "white",
            fontSize: 14,
            fontWeight: 400,
            valueFormatter: (value) => `${value.toFixed(0)}%`,
            skipLabels: ["other"],
          },
        },
      },
    });
  },

  applyData(event) {
    if (!event?.percentageTimeInRank || !this.chart) return;

    const { labels, values, colors, otherRanks } = prepareRankData(event.percentageTimeInRank);
    this.syncWrapHeight(this.compact, labels.length);
    this.chart.data.labels = labels;
    this.chart.data.datasets[0].data = values;
    this.chart.data.datasets[0].backgroundColor = colors;
    this.chart.otherRanks = otherRanks;
    this.chart.update();
  },

  syncWrapHeight(compact, rowCount) {
    const wrap = this.el.parentElement;
    if (!wrap) return;
    if (compact) {
      wrap.style.height = `${Math.max(220, rowCount * BAR_ROW_HEIGHT + 16)}px`;
    } else {
      wrap.style.height = "";
    }
  },

  destroyed() {
    this.media?.removeEventListener("change", this.onViewportChange);
    if (this.resizeObserver) this.resizeObserver.disconnect();
    this.chart?.destroy();
  },
};
