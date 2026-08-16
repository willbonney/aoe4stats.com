import { Chart } from "chart.js/auto";
import HtmlYLabelsPlugin from "./html_y_labels.js";
import { TW_STONE_800, TW_ZINC_100 } from "./shared.js";

const BAR_ROW_HEIGHT = 32;
const LABEL_WIDTH = 152;
const FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

function isDarkTheme() {
  return localStorage.getItem("theme") === "dark";
}

function tickColor() {
  return isDarkTheme() ? TW_ZINC_100 : TW_STONE_800;
}

function parseRows(raw) {
  try {
    const rows = JSON.parse(raw || "[]");
    return Array.isArray(rows) ? rows : [];
  } catch {
    return [];
  }
}

function syncHeight(canvas, count) {
  const wrap = canvas?.parentElement;
  if (!wrap) return;
  const next = `${Math.max(240, count * BAR_ROW_HEIGHT + 48)}px`;
  if (wrap.style.height !== next) wrap.style.height = next;
}

function wrColor(winRate) {
  const dark = isDarkTheme();
  if (winRate == null) return dark ? "#71717a" : "#d1d5db";
  if (winRate < 39) return dark ? "#f87171" : "#b91c1c";
  if (winRate < 42) return dark ? "#f87171" : "#dc2626";
  if (winRate < 45) return dark ? "#f87171" : "#ef4444";
  if (winRate < 47) return dark ? "#fca5a5" : "#f87171";
  if (winRate < 49) return dark ? "#fecaca" : "#fca5a5";
  if (winRate < 50) return dark ? "#fecaca" : "#fecaca";
  if (winRate === 50) return dark ? "#a1a1aa" : "#e5e7eb";
  if (winRate < 51) return dark ? "#bbf7d0" : "#bbf7d0";
  if (winRate < 53) return dark ? "#86efac" : "#86efac";
  if (winRate < 55) return dark ? "#4ade80" : "#4ade80";
  if (winRate < 60) return dark ? "#4ade80" : "#22c55e";
  return dark ? "#22c55e" : "#15803d";
}

function rangeColor(range) {
  const dark = isDarkTheme();
  if (range >= 6) return dark ? "#7dd3fc" : "#1d4ed8";
  if (range >= 3) return dark ? "#38bdf8" : "#2563eb";
  return dark ? "#bae6fd" : "#93c5fd";
}

function formatGames(count) {
  if (count == null) return "n/a";
  return Number(count).toLocaleString();
}

const TOOLTIP_ATTR = "data-chart-html-tooltip";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function htmlTooltip(context) {
  const { chart, tooltip } = context;
  const wrap = chart.canvas?.parentElement;
  if (!wrap) return;

  wrap.style.position = wrap.style.position || "relative";

  let el = wrap.querySelector(`[${TOOLTIP_ATTR}]`);
  if (!el) {
    el = document.createElement("div");
    el.setAttribute(TOOLTIP_ATTR, "");
    el.className = "pointer-events-none absolute max-w-xs rounded-lg px-3 py-2 text-sm text-white shadow-lg";
    el.style.zIndex = "50";
    el.style.backgroundColor = "rgba(0, 0, 0, 0.92)";
    el.style.opacity = "0";
    wrap.appendChild(el);
    chart.$htmlTooltip = el;
  }

  if (tooltip.opacity === 0 || !tooltip.body?.length) {
    el.style.opacity = "0";
    return;
  }

  const title = tooltip.title?.[0] || "";
  const lines = tooltip.body.map((body) => body.lines.join(" "));
  el.innerHTML = `${
    title ? `<div class="font-semibold mb-0.5">${escapeHtml(title)}</div>` : ""
  }<div>${lines.map(escapeHtml).join("<br>")}</div>`;

  const minLeft = (chart.scales?.y?.right || 0) + 8;
  const left = tooltip.caretX;
  const top = tooltip.caretY;
  el.style.opacity = "1";
  el.style.left = `${left}px`;
  el.style.top = `${top}px`;

  const width = el.offsetWidth;
  const height = el.offsetHeight;
  let x = left + 16;
  if (x + width > wrap.clientWidth - 8) x = left - width - 16;
  if (x < minLeft) x = Math.min(minLeft, wrap.clientWidth - width - 8);
  let y = top - height / 2;
  if (y < 4) y = 4;
  if (y + height > wrap.clientHeight - 4) y = Math.max(4, wrap.clientHeight - height - 4);
  el.style.left = `${x}px`;
  el.style.top = `${y}px`;
}

function tooltipOptions({ filter, ...callbacks }) {
  return {
    enabled: false,
    external: htmlTooltip,
    filter,
    callbacks,
  };
}

function applyScaleTheme(chart) {
  const color = tickColor();
  if (chart.options.scales?.x) {
    chart.options.scales.x.ticks = { ...chart.options.scales.x.ticks, color };
    chart.options.scales.x.grid = {
      ...chart.options.scales.x.grid,
      color: isDarkTheme() ? "rgba(244, 244, 245, 0.12)" : "rgba(41, 37, 36, 0.12)",
    };
    if (chart.options.scales.x.title) {
      chart.options.scales.x.title.color = color;
    }
  }
}

function fiftyLine() {
  return {
    fifty: {
      type: "line",
      xMin: 0,
      xMax: 0,
      borderColor: isDarkTheme() ? "rgba(244, 244, 245, 0.7)" : "rgba(41, 37, 36, 0.65)",
      borderWidth: 2,
      borderDash: [6, 4],
      drawTime: "beforeDatasetsDraw",
    },
  };
}

function fiftyLineAt(value) {
  return {
    fifty: {
      type: "line",
      xMin: value,
      xMax: value,
      borderColor: isDarkTheme() ? "rgba(244, 244, 245, 0.7)" : "rgba(41, 37, 36, 0.65)",
      borderWidth: 2,
      borderDash: [6, 4],
      drawTime: "beforeDatasetsDraw",
    },
  };
}

export default {
  mounted() {
    this.favoredCanvas = this.el.querySelector("#civs-by-map-favored");
    this.varianceCanvas = this.el.querySelector("#civs-by-map-variance");
    this.favoredChart = this.createFavoredChart();
    this.varianceChart = this.createVarianceChart();
    this.apply();

    this.themeHandler = () => {
      this.apply();
    };
    window.addEventListener("themeChanged", this.themeHandler);

    this.resizeObserver = new ResizeObserver(() => {
      this.favoredChart?.resize();
      this.varianceChart?.resize();
    });
    this.resizeObserver.observe(this.el);
  },

  updated() {
    this.apply();
  },

  destroyed() {
    window.removeEventListener("themeChanged", this.themeHandler);
    this.resizeObserver?.disconnect();
    this.favoredChart?.$htmlTooltip?.remove();
    this.varianceChart?.$htmlTooltip?.remove();
    this.favoredChart?.destroy();
    this.varianceChart?.destroy();
  },

  apply() {
    this.applyFavored(parseRows(this.el.dataset.favored));
    this.applyVariance(parseRows(this.el.dataset.variance));
  },

  createFavoredChart() {
    return new Chart(this.favoredCanvas, {
      type: "bar",
      plugins: [HtmlYLabelsPlugin],
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
        interaction: { mode: "index", intersect: false, axis: "y" },
        plugins: {
          legend: { display: false },
          title: { display: false },
          annotation: { annotations: fiftyLine() },
          tooltip: tooltipOptions({
            label: (ctx) => {
              const row = this.favoredRows?.[ctx.dataIndex];
              if (!row) return null;
              const sign = row.delta > 0 ? "+" : "";
              return `${row.win_rate.toFixed(2)}% (${formatGames(row.games_count)} games) · ${sign}${row.delta.toFixed(2)} vs 50%`;
            },
          }),
        },
        scales: {
          x: {
            min: -3,
            max: 3,
            grid: { display: true },
            border: { display: false },
            ticks: {
              color: tickColor(),
              font: { size: 12, family: FONT },
              callback: (value) => `${(50 + value).toFixed(0)}%`,
            },
            title: {
              display: true,
              text: "Win rate",
              color: tickColor(),
              font: { size: 12, family: FONT },
            },
          },
          y: {
            grid: { display: false },
            border: { display: false },
            ticks: { display: false },
            afterFit(scale) {
              scale.width = LABEL_WIDTH;
            },
          },
        },
      },
    });
  },

  createVarianceChart() {
    return new Chart(this.varianceCanvas, {
      type: "bar",
      plugins: [HtmlYLabelsPlugin],
      data: {
        labels: [],
        datasets: [
          {
            label: "Range",
            data: [],
            backgroundColor: [],
            borderWidth: 0,
            borderRadius: 0,
            grouped: false,
            barPercentage: 0.55,
            categoryPercentage: 0.8,
          },
          {
            label: "Average",
            data: [],
            order: 1,
            grouped: false,
            backgroundColor: "#1c1917",
            borderWidth: 0,
            borderRadius: 0,
            barPercentage: 0.85,
            categoryPercentage: 0.85,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        clip: false,
        interaction: { mode: "index", intersect: false, axis: "y" },
        plugins: {
          legend: { display: false },
          title: { display: false },
          annotation: { annotations: fiftyLineAt(50) },
          tooltip: tooltipOptions({
            filter: (item) => item.datasetIndex === 0,
            label: (ctx) => {
              const row = this.varianceRows?.[ctx.dataIndex];
              if (!row) return null;
              return `${row.min.toFixed(2)}%–${row.max.toFixed(2)}% (avg ${row.avg.toFixed(2)}%, range ${row.range.toFixed(2)}) · best ${row.max_map}, worst ${row.min_map}`;
            },
          }),
        },
        scales: {
          x: {
            grid: { display: true },
            border: { display: false },
            ticks: {
              color: tickColor(),
              font: { size: 12, family: FONT },
              callback: (value) => `${value}%`,
            },
            title: {
              display: true,
              text: "Win rate range",
              color: tickColor(),
              font: { size: 12, family: FONT },
            },
          },
          y: {
            grid: { display: false },
            border: { display: false },
            ticks: { display: false },
            afterFit(scale) {
              scale.width = LABEL_WIDTH;
            },
          },
        },
      },
    });
  },

  applyFavored(rows) {
    this.favoredRows = rows;
    const chart = this.favoredChart;
    if (!chart) return;

    syncHeight(this.favoredCanvas, rows.length || 4);
    const deltas = rows.map((row) => row.delta);
    const maxAbs = Math.max(3, Math.ceil(Math.max(0, ...deltas.map((value) => Math.abs(value))) + 0.25));

    chart.data.labels = rows.map((row) => row.label);
    chart.$htmlYLabelImages = rows.map((row) => (row.image ? `/images/${row.image}.png` : null));
    chart.data.datasets[0].data = deltas;
    chart.data.datasets[0].backgroundColor = rows.map((row) => wrColor(row.win_rate));
    chart.options.scales.x.min = -maxAbs;
    chart.options.scales.x.max = maxAbs;
    chart.options.plugins.annotation.annotations = fiftyLine();
    applyScaleTheme(chart);
    chart.update();
  },

  applyVariance(rows) {
    this.varianceRows = rows;
    const chart = this.varianceChart;
    if (!chart) return;

    syncHeight(this.varianceCanvas, rows.length || 4);
    const values = rows.flatMap((row) => [row.min, row.max]);
    const min = values.length ? Math.min(...values) : 45;
    const max = values.length ? Math.max(...values) : 55;
    const pad = Math.max(1, (max - min) * 0.15);

    chart.data.labels = rows.map((row) => row.label);
    chart.$htmlYLabelImages = rows.map((row) => (row.image ? `/images/${row.image}.png` : null));
    chart.data.datasets[0].data = rows.map((row) => [row.min, row.max]);
    chart.data.datasets[0].backgroundColor = rows.map((row) => rangeColor(row.range));
    chart.data.datasets[1].data = rows.map((row) => [row.avg - 0.14, row.avg + 0.14]);
    chart.data.datasets[1].backgroundColor = isDarkTheme() ? "#fafaf9" : "#1c1917";
    chart.options.scales.x.min = Math.floor(min - pad);
    chart.options.scales.x.max = Math.ceil(max + pad);
    chart.options.plugins.annotation.annotations = fiftyLineAt(50);
    applyScaleTheme(chart);
    chart.update();
  },
};
