import jsVectorMap from "jsvectormap";
import "../vendor/jsvectormap-world.js";
import { COUNTRY_UTILS } from "./shared.js";

const CODE_ALIASES = {
  UK: "GB",
  EN: "GB",
};

function isDarkTheme() {
  if (localStorage.getItem("theme") === "dark") return true;
  if (localStorage.getItem("theme") === "light") return false;
  return document.documentElement.classList.contains("dark");
}

function normalizeValues(byCountry) {
  const values = {};

  Object.entries(byCountry || {}).forEach(([code, percentage]) => {
    if (!code || code === "unknown" || code === "other") return;
    const iso = CODE_ALIASES[code.toUpperCase()] || code.toUpperCase();
    const numeric = Number(percentage);
    if (Number.isNaN(numeric)) return;
    values[iso] = (values[iso] || 0) + numeric;
  });

  return values;
}

export default {
  mounted() {
    this.values = {};
    this.desktop = window.matchMedia("(min-width: 768px)");
    this.onTheme = () => {
      if (this.desktop.matches) this.renderMap(this.values);
    };
    this.onViewport = () => {
      if (this.desktop.matches) this.renderMap(this.values);
      else this.teardownMap();
    };

    window.addEventListener("themeChanged", this.onTheme);
    this.desktop.addEventListener("change", this.onViewport);

    this.handleEvent("update-opponents-by-country", (event) => {
      this.values = normalizeValues(event.byCountry);
      if (this.desktop.matches) this.renderMap(this.values);
    });

    if (this.el.dataset.countries) {
      try {
        this.values = normalizeValues(JSON.parse(this.el.dataset.countries));
      } catch (_error) {
        // wait for the LiveView event
      }
    }

    if (this.desktop.matches && Object.keys(this.values).length > 0) {
      this.renderMap(this.values);
    }
  },

  teardownMap() {
    if (this.map) {
      try {
        this.map.destroy();
      } catch (_error) {
        // first paint or a previous destroy already cleared the instance
      }
      this.map = null;
    }
    this.el.innerHTML = "";
  },

  renderMap(values) {
    this.values = values || {};
    this.teardownMap();

    const dark = isDarkTheme();

    this.map = new jsVectorMap({
      selector: this.el,
      map: "world",
      backgroundColor: "transparent",
      draggable: true,
      zoomButtons: true,
      zoomOnScroll: false,
      showTooltip: true,
      regionStyle: {
        initial: {
          fill: dark ? "#3f3f46" : "#e4e4e7",
          fillOpacity: 1,
          stroke: dark ? "#18181b" : "#ffffff",
          strokeWidth: 0.4,
        },
        hover: {
          fillOpacity: 0.85,
          cursor: "pointer",
        },
      },
      visualizeData: {
        scale: dark ? ["#1e3a8a", "#7dd3fc"] : ["#bfdbfe", "#1e3a8a"],
        values: this.values,
      },
      onRegionTooltipShow: (_event, tooltip, code) => {
        const name = COUNTRY_UTILS.getName(code);
        const percentage = this.values[code];
        tooltip.text(
          percentage != null ? `${name}: ${percentage.toFixed(1)}%` : `${name}: 0%`
        );
      },
    });
  },

  destroyed() {
    window.removeEventListener("themeChanged", this.onTheme);
    this.desktop?.removeEventListener("change", this.onViewport);
    this.teardownMap();
  },
};
