const STORAGE_KEY = "civs_by_map_filters";

export default {
  mounted() {
    const savedFilters = this.loadFilters();
    if (savedFilters) {
      this.pushEvent("load-filters", savedFilters);
    }

    this.handleEvent("save-filters", (filters) => {
      this.saveFilters(filters);
    });
  },

  loadFilters() {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      return saved ? JSON.parse(saved) : null;
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
