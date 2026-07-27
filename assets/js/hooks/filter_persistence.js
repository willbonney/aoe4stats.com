const STORAGE_KEY = "civs_by_map_filters";

export default {
  mounted() {
    // Register save handler before any events are pushed
    this.handleEvent("save-filters", (filters) => {
      this.saveFilters(filters);
    });

    // Always notify the LiveView (even with empty prefs) so it can finish loading
    this.pushFiltersToServer();
  },

  // After disconnect/reconnect the LiveView process often remounts with defaults,
  // but this DOM hook is not remounted — only reconnected() runs.
  reconnected() {
    this.pushFiltersToServer();
  },

  pushFiltersToServer() {
    const savedFilters = this.loadFilters();
    this.pushEvent("load-filters", savedFilters || {});
  },

  loadFilters() {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (!saved) return null;

      const parsed = JSON.parse(saved);
      if (!parsed || typeof parsed !== "object") return null;

      return parsed;
    } catch (err) {
      console.error("Failed to load filters from localStorage:", err);
      return null;
    }
  },

  saveFilters(filters) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(filters));
    } catch (err) {
      console.error("Failed to save filters to localStorage:", err);
    }
  },
};
