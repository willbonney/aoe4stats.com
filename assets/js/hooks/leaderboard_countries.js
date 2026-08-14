import { Chart } from "chart.js/auto";
import AlwaysShowTooltipPlugin from "../always_show_tooltip_plugin.js";
import { COUNTRY_UTILS, getDistributedColors, MUI_COLORS, TW_STONE_800, TW_ZINC_100 } from "./shared.js";

const COMPACT_BREAKPOINT = 768;
const BAR_ROW_HEIGHT = 34;

function isDarkTheme() {
  return localStorage.getItem("theme") === "dark";
}

function isCompact(el) {
  return (el.parentElement?.clientWidth || el.clientWidth) < COMPACT_BREAKPOINT;
}

function prepareCountryData(byCountry) {
  const threshold = 2;
  let otherValue = 0;
  const otherCountries = {};
  const filtered = [];

  Object.entries(byCountry || {}).forEach(([country, value]) => {
    if (value >= threshold) {
      filtered.push([country, value]);
    } else {
      otherValue += value;
      otherCountries[country] = (otherCountries[country] || 0) + value;
    }
  });

  filtered.sort((a, b) => b[1] - a[1]);

  if (otherValue > 0) {
    filtered.push(["other", otherValue]);
  }

  return {
    labels: filtered.map(([country]) =>
      country === "other" ? "Other" : COUNTRY_UTILS.getDisplayName(country)
    ),
    values: filtered.map(([, value]) => value),
    otherCountries,
  };
}

export default {
  mounted() {
    this.lastEvent = null;
    this.compact = isCompact(this.el);
    this.chart = this.createChart(this.compact);

    this.resizeObserver = new ResizeObserver(() => {
      const compact = isCompact(this.el);
      if (compact !== this.compact) {
        this.compact = compact;
        this.chart?.destroy();
        this.chart = this.createChart(compact);
        if (this.lastEvent) this.applyData(this.lastEvent);
      } else {
        this.chart?.resize();
      }
    });
    this.resizeObserver.observe(this.el.parentElement || this.el);

    this.handleEvent("update-leaderboard-countries", (event) => {
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
        plugins: [AlwaysShowTooltipPlugin],
        data: {
          labels: [],
          datasets: [
            {
              data: [],
              backgroundColor: MUI_COLORS.slice(0, 19),
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
          layout: {
            padding: { right: 44, top: 4, bottom: 4 },
          },
          plugins: {
            legend: { display: false },
            title: { display: false },
            tooltip: { enabled: false },
            alwaysShowTooltip: {
              fontSize: 12,
              fontWeight: 600,
              color: tickColor,
              valueFormatter: (value) => `${value.toFixed(1)}%`,
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
                font: { size: 11 },
                callback: (value) => `${value}%`,
              },
            },
            y: {
              grid: { display: false },
              border: { display: false },
              ticks: {
                color: tickColor,
                font: { size: 15 },
                autoSkip: false,
                callback(value) {
                  const label = this.getLabelForValue(value);
                  return label.length > 18 ? `${label.slice(0, 17)}…` : label;
                },
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
        datasets: [
          {
            data: [],
            backgroundColor: MUI_COLORS.slice(0, 19),
          },
        ],
        hoverOffset: 4,
        borderJoinStyle: "bevel",
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: 16,
        },
        plugins: {
          tooltip: {
            callbacks: {
              label: (context) => `${context.formattedValue}%`,
              afterBody: (context) => {
                if (!context?.[0]) return [];
                const label = context[0].label;
                if (label === "Other" && this.chart?.otherCountries) {
                  const otherCountries = Object.entries(this.chart.otherCountries)
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
            bodyFont: { size: 14 },
            titleFont: { size: 16, weight: "bold" },
            filter: (tooltipItem) => (tooltipItem.label || "").toLowerCase().includes("other"),
          },
          legend: { display: false },
          title: { display: false },
          alwaysShowTooltip: {
            fontSize: 14,
            fontWeight: 400,
            valueFormatter: (value) => `${value.toFixed(1)}%`,
            skipLabels: ["other"],
            minSliceRatio: 0.06,
          },
        },
      },
    });
  },

  applyData(event) {
    const { labels, values, otherCountries } = prepareCountryData(event.byCountry);
    const chart = this.chart;
    if (!chart) return;

    this.syncWrapHeight(this.compact, labels.length);

    chart.data.labels = labels;
    chart.data.datasets[0].data = values;
    chart.data.datasets[0].backgroundColor = getDistributedColors(labels.length);
    chart.otherCountries = otherCountries;
    chart.update();
  },

  syncWrapHeight(compact, rowCount) {
    const wrap = this.el.parentElement;
    if (!wrap) return;
    if (compact) {
      wrap.style.height = `${Math.max(260, rowCount * BAR_ROW_HEIGHT + 16)}px`;
    } else {
      wrap.style.height = "";
    }
  },

  destroyed() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    this.chart?.destroy();
  },
};
