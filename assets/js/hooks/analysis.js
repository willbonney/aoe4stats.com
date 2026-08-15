import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import HtmlYLabelsPlugin from "./html_y_labels.js";
import { MUI_COLORS, TW_STONE_800, TW_ZINC_100, getLargeTooltipConfig } from "./shared.js";

const COMPACT_BREAKPOINT = 768;
const BAR_ROW_HEIGHT = 36;

const ALL_METRICS = [
  { key: "peak_proximity", label: "Peak Proximity", colorIndex: 13 },
  { key: "recovery", label: "Recovery", colorIndex: 9 },
  { key: "momentum", label: "Momentum", colorIndex: 16 },
  { key: "anti_tilt", label: "Anti-Tilt", colorIndex: 11 },
  { key: "pressure_performance", label: "Pressure", colorIndex: 2 },
  { key: "rating_efficiency", label: "Efficiency", colorIndex: 4 },
  { key: "versatility", label: "Versatility", colorIndex: 17 },
  { key: "underdog_success", label: "Underdog Power", colorIndex: 0 },
];

function isDarkTheme() {
  return localStorage.getItem("theme") === "dark";
}

function isCompact() {
  return window.innerWidth < COMPACT_BREAKPOINT;
}

function metricsFromAnalysis(analysis) {
  return ALL_METRICS.filter((m) => Object.hasOwn(analysis, m.key));
}

export default {
  mounted() {
    this.lastEvent = null;
    this.compact = isCompact();
    this.chart = this.createChart(this.compact);
    this.onThemeChanged = (e) => this.applyTheme(e.detail.isDark);

    window.addEventListener("themeChanged", this.onThemeChanged);

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
      if (this.compact) this.chart?.resize();
    });
    this.resizeObserver.observe(this.el.parentElement || this.el);

    this.handleEvent("update-analysis", (event) => {
      this.lastEvent = event;
      this.applyData(event);
    });
  },

  createChart(compact) {
    this.syncWrapHeight(compact, this.chart?.data?.labels?.length || 8);
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
              backgroundColor: [],
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
          layout: { padding: { right: 44, top: 10, bottom: 18 } },
          plugins: {
            legend: { display: false },
            title: { display: false },
            tooltip: { enabled: false },
            alwaysShowTooltip: {
              fontSize: 12,
              fontWeight: 600,
              fontFamily: 'system-ui, -apple-system, "Segoe UI", sans-serif',
              color: tickColor,
              valueFormatter: (value) => Number(value).toFixed(1),
            },
          },
          scales: {
            x: {
              min: 0,
              max: 100,
              grid: { display: false },
              border: { display: false },
              ticks: {
                color: tickColor,
                font: { size: 11, family: 'system-ui, -apple-system, "Segoe UI", sans-serif' },
              },
            },
            y: {
              grid: { display: false },
              border: { display: false },
              ticks: { display: false },
              afterFit(scale) {
                scale.width = 148;
              },
            },
          },
        },
      });
    }

    return new Chart(this.el, {
      type: "polarArea",
      data: {
        labels: [],
        datasets: [
          {
            label: "Performance Metrics",
            data: [],
            backgroundColor: [],
            borderColor: [],
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
            ticks: { stepSize: 20 },
            pointLabels: {
              display: true,
              centerPointLabels: true,
              font: { size: 22 },
            },
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...getLargeTooltipConfig(),
            callbacks: {
              label: (context) => `${context.raw.toFixed(1)}%`,
            },
          },
          title: { display: false },
        },
      },
    });
  },

  applyData(event) {
    const analysis = event?.analysis;
    if (!analysis || !this.chart) return;

    const metrics = metricsFromAnalysis(analysis);
    const colors = metrics.map((m) => MUI_COLORS[m.colorIndex]);

    this.syncWrapHeight(this.compact, metrics.length);
    this.chart.data.labels = metrics.map((m) => m.label);
    this.chart.data.datasets[0].data = metrics.map((m) => analysis[m.key]);

    if (this.compact) {
      this.chart.data.datasets[0].backgroundColor = colors;
    } else {
      this.chart.data.datasets[0].backgroundColor = colors.map((color) => `${color.slice(0, -4)}, 0.7)`);
      this.chart.data.datasets[0].borderColor = colors;
      this.applyTheme(isDarkTheme());
    }

    this.chart.update();
    this.setupHoverInteractions(metrics);
  },

  applyTheme(isDark) {
    if (!this.chart || this.compact || this.chart.config.type !== "polarArea") return;

    const color = isDark ? TW_ZINC_100 : TW_STONE_800;
    this.chart.options.scales.r = {
      ...this.chart.options.scales.r,
      grid: { color },
      angleLines: { color },
      pointLabels: {
        ...this.chart.options.scales.r.pointLabels,
        color,
        font: { size: 22 },
      },
      ticks: {
        ...this.chart.options.scales.r.ticks,
        color,
        backdropColor: isDark ? "rgba(39, 39, 42, 0.8)" : "rgba(255, 255, 255, 0.8)",
      },
    };
    this.chart.update();
  },

  setupHoverInteractions(metrics) {
    this.hoverAbort?.abort();
    this.hoverAbort = new AbortController();
    const { signal } = this.hoverAbort;

    const metricToChartIndex = Object.fromEntries(metrics.map((metric, index) => [metric.label, index]));

    document.querySelectorAll("#metric-descriptions [data-metric]").forEach((box) => {
      const chartIndex = metricToChartIndex[box.getAttribute("data-metric")];
      if (chartIndex === undefined) return;

      box.addEventListener(
        "mouseenter",
        () => {
          const activeElements = [{ datasetIndex: 0, index: chartIndex }];
          this.chart.setActiveElements(activeElements);
          this.chart.tooltip.setActiveElements(activeElements);
          this.chart.update();
        },
        { signal }
      );

      box.addEventListener(
        "mouseleave",
        () => {
          this.chart.setActiveElements([]);
          this.chart.tooltip.setActiveElements([]);
          this.chart.update();
        },
        { signal }
      );
    });
  },

  syncWrapHeight(compact, rowCount) {
    const wrap = this.el.parentElement;
    if (!wrap) return;
    if (compact) {
      wrap.style.height = `${Math.max(280, rowCount * BAR_ROW_HEIGHT + 40)}px`;
    } else {
      wrap.style.height = "";
    }
  },

  destroyed() {
    this.hoverAbort?.abort();
    this.media?.removeEventListener("change", this.onViewportChange);
    this.resizeObserver?.disconnect();
    window.removeEventListener("themeChanged", this.onThemeChanged);
    this.chart?.destroy();
  },
};
