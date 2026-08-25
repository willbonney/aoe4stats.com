import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import HtmlYLabelsPlugin from "./html_y_labels.js";
import HtmlPolarLabelsPlugin from "./html_polar_labels.js";
import { TW_STONE_800, TW_ZINC_100, getLargeTooltipConfig } from "./shared.js";

const COMPACT_BREAKPOINT = 768;
const BAR_ROW_HEIGHT = 36;
const UI_FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

const ALL_METRICS = [
  { key: "peak_proximity", label: "Peak Proximity", color: "rgba(33, 150, 243, 1)" },
  { key: "recovery", label: "Recovery", color: "rgba(76, 175, 80, 1)" },
  { key: "momentum", label: "Momentum", color: "rgba(156, 39, 176, 1)" },
  { key: "anti_tilt", label: "Anti-Tilt", color: "rgba(0, 188, 212, 1)" },
  { key: "pressure_performance", label: "Pressure", color: "rgba(255, 112, 67, 1)" },
  { key: "rating_efficiency", label: "Efficiency", color: "rgba(255, 193, 7, 1)" },
  { key: "versatility", label: "Versatility", color: "rgba(240, 98, 146, 1)" },
  { key: "underdog_success", label: "Underdog Power", color: "rgba(244, 67, 54, 1)" },
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

function parseRgb(color) {
  const parts = String(color).match(/[\d.]+/g) || ["0", "0", "0"];
  return { r: Number(parts[0]), g: Number(parts[1]), b: Number(parts[2]) };
}

function rgba({ r, g, b }, a) {
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

function mixWithWhite({ r, g, b }, amount) {
  return {
    r: Math.round(r + (255 - r) * amount),
    g: Math.round(g + (255 - g) * amount),
    b: Math.round(b + (255 - b) * amount),
  };
}

function polarAreaGradient(chart, color, hover = false) {
  const scale = chart.scales?.r;
  const rgb = parseRgb(color);
  if (!scale?.drawingArea) return rgba(rgb, hover ? 0.92 : 0.78);

  const gradient = chart.ctx.createRadialGradient(
    scale.xCenter,
    scale.yCenter,
    0,
    scale.xCenter,
    scale.yCenter,
    scale.drawingArea
  );
  const inner = hover ? 0.42 : 0.58;
  const midAlpha = hover ? 0.86 : 0.72;
  gradient.addColorStop(0, rgba(mixWithWhite(rgb, inner), hover ? 0.5 : 0.38));
  gradient.addColorStop(0.32, rgba(mixWithWhite(rgb, 0.12), midAlpha));
  gradient.addColorStop(0.68, rgba(rgb, hover ? 0.96 : 0.9));
  gradient.addColorStop(1, rgba(rgb, 1));
  return gradient;
}

function horizontalBarGradient(ctx, color) {
  const chart = ctx.chart;
  const rgb = parseRgb(color);
  const el = chart.getDatasetMeta(ctx.datasetIndex)?.data?.[ctx.dataIndex];
  if (!el) return rgba(rgb, 0.88);

  const x0 = Math.min(el.base, el.x);
  const x1 = Math.max(el.base, el.x);
  if (!(x1 > x0)) return rgba(rgb, 0.88);

  const gradient = chart.ctx.createLinearGradient(x0, 0, x1, 0);
  gradient.addColorStop(0, rgba(mixWithWhite(rgb, 0.4), 0.5));
  gradient.addColorStop(0.55, rgba(rgb, 0.84));
  gradient.addColorStop(1, rgba(rgb, 0.98));
  return gradient;
}

function chartPixelRatio() {
  return Math.max(window.devicePixelRatio || 1, 2);
}

function gridStroke(isDark) {
  return isDark ? "rgba(244, 244, 245, 0.26)" : "rgba(41, 37, 36, 0.18)";
}

function sliceBorder(isDark) {
  return isDark ? "rgba(24, 24, 27, 0.92)" : "rgba(255, 255, 255, 0.95)";
}

function tickBackdrop(isDark) {
  return isDark ? "rgba(24, 24, 27, 0.78)" : "rgba(255, 255, 255, 0.82)";
}

const PolarBackdropPlugin = {
  id: "polarBackdrop",
  beforeDraw(chart) {
    if (chart.config.type !== "polarArea") return;
    const scale = chart.scales?.r;
    if (!scale?.drawingArea) return;

    const { ctx } = chart;
    const isDark = isDarkTheme();
    ctx.save();
    ctx.beginPath();
    ctx.arc(scale.xCenter, scale.yCenter, scale.drawingArea, 0, Math.PI * 2);
    const fill = ctx.createRadialGradient(
      scale.xCenter,
      scale.yCenter,
      0,
      scale.xCenter,
      scale.yCenter,
      scale.drawingArea
    );
    if (isDark) {
      fill.addColorStop(0, "rgba(255, 255, 255, 0.045)");
      fill.addColorStop(1, "rgba(255, 255, 255, 0)");
    } else {
      fill.addColorStop(0, "rgba(15, 23, 42, 0.045)");
      fill.addColorStop(1, "rgba(15, 23, 42, 0)");
    }
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.restore();
  },
  afterDatasetsDraw(chart) {
    if (chart.config.type !== "polarArea") return;
    const scale = chart.scales?.r;
    if (!scale?.drawingArea) return;

    const { ctx } = chart;
    const isDark = isDarkTheme();
    ctx.save();
    ctx.beginPath();
    ctx.arc(scale.xCenter, scale.yCenter, scale.drawingArea, 0, Math.PI * 2);
    ctx.strokeStyle = isDark ? "rgba(244, 244, 245, 0.42)" : "rgba(41, 37, 36, 0.32)";
    ctx.lineWidth = 1.25;
    ctx.stroke();
    ctx.restore();
  },
};

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
              borderRadius: 6,
              barPercentage: 0.75,
              categoryPercentage: 0.85,
            },
          ],
        },
        options: {
          indexAxis: "y",
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: chartPixelRatio(),
          layout: { padding: { right: 44, top: 10, bottom: 18 } },
          plugins: {
            legend: { display: false },
            title: { display: false },
            tooltip: { enabled: false },
            alwaysShowTooltip: {
              fontSize: 12,
              fontWeight: 600,
              fontFamily: UI_FONT,
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
                font: { size: 11, family: UI_FONT },
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

    const dark = isDarkTheme();

    return new Chart(this.el, {
      type: "polarArea",
      plugins: [PolarBackdropPlugin, HtmlPolarLabelsPlugin],
      data: {
        labels: [],
        datasets: [
          {
            label: "Performance Metrics",
            data: [],
            backgroundColor: [],
            borderColor: sliceBorder(dark),
            borderWidth: 2.5,
            hoverOffset: 8,
            hoverBorderWidth: 2.5,
          },
        ],
      },
      options: {
        responsive: true,
        devicePixelRatio: chartPixelRatio(),
        animation: {
          animateRotate: true,
          animateScale: true,
          duration: 650,
          easing: "easeOutQuart",
        },
        layout: { padding: 8 },
        scales: {
          r: {
            min: 0,
            max: 100,
            startAngle: 0,
            grid: {
              color: gridStroke(dark),
              circular: true,
              lineWidth: 1,
            },
            angleLines: { display: false },
            ticks: {
              stepSize: 20,
              color: dark ? "rgba(244, 244, 245, 0.7)" : "rgba(41, 37, 36, 0.55)",
              backdropColor: tickBackdrop(dark),
              backdropPadding: 4,
              font: { size: 11, family: UI_FONT, weight: "500" },
              z: 1,
            },
            pointLabels: {
              display: true,
              centerPointLabels: true,
              color: "rgba(0,0,0,0)",
              padding: 16,
              font: { size: 15, weight: "600", family: UI_FONT },
              callback(label, index) {
                const value = this.chart?.data?.datasets?.[0]?.data?.[index];
                const score = Number.isFinite(Number(value)) ? Number(value).toFixed(1) : "00.0";
                return [label, score];
              },
            },
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...getLargeTooltipConfig(),
            callbacks: {
              label: (context) => `${Number(context.raw).toFixed(1)}`,
              labelColor: (context) => {
                const color = context.chart.$polarColors?.[context.dataIndex] || sliceBorder(isDarkTheme());
                return { borderColor: color, backgroundColor: color };
              },
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
    const colors = metrics.map((m) => m.color);

    this.syncWrapHeight(this.compact, metrics.length);
    this.chart.data.labels = metrics.map((m) => m.label);
    this.chart.data.datasets[0].data = metrics.map((m) => analysis[m.key]);
    this.chart.$polarColors = colors;

    if (this.compact) {
      this.chart.data.datasets[0].backgroundColor = (ctx) => {
        const color = colors[ctx.dataIndex];
        return color ? horizontalBarGradient(ctx, color) : "rgba(0,0,0,0)";
      };
    } else {
      this.chart.data.datasets[0].backgroundColor = (ctx) => {
        const color = colors[ctx.dataIndex];
        return color ? polarAreaGradient(ctx.chart, color) : "rgba(0,0,0,0)";
      };
      this.chart.data.datasets[0].hoverBackgroundColor = (ctx) => {
        const color = colors[ctx.dataIndex];
        return color ? polarAreaGradient(ctx.chart, color, true) : "rgba(0,0,0,0)";
      };
      this.chart.data.datasets[0].borderColor = sliceBorder(isDarkTheme());
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
      grid: {
        ...this.chart.options.scales.r.grid,
        color: gridStroke(isDark),
        circular: true,
        lineWidth: 1,
      },
      angleLines: { display: false, color },
      pointLabels: {
        ...this.chart.options.scales.r.pointLabels,
        color: "rgba(0,0,0,0)",
        display: true,
        centerPointLabels: true,
        padding: 16,
        font: { size: 15, weight: "600", family: UI_FONT },
      },
      ticks: {
        ...this.chart.options.scales.r.ticks,
        color: isDark ? "rgba(244, 244, 245, 0.7)" : "rgba(41, 37, 36, 0.55)",
        backdropColor: tickBackdrop(isDark),
        backdropPadding: 4,
        font: { size: 11, family: UI_FONT, weight: "500" },
        z: 1,
      },
    };
    this.chart.data.datasets[0].borderColor = sliceBorder(isDark);
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
