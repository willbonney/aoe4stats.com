// League background colors (from utils.ex full_rating_to_color_map, semi-transparent)
export const LEAGUE_COLORS = {
  Bronze: "rgba(184, 115, 51, 0.35)", // #B87333
  Silver: "rgba(192, 192, 192, 0.35)", // #C0C0C0
  Gold: "rgba(255, 193, 37, 0.35)", // #FFC125
  Platinum: "rgba(230, 230, 230, 0.4)", // #E6E6E6
  Diamond: "rgba(135, 206, 250, 0.35)", // #87CEFA
  Conqueror: "rgba(255, 165, 0, 0.35)", // #FFA500
};

// League rating ranges [min, max] (matches utils.ex league_ranges)
export const LEAGUE_RATING_RANGES = {
  Bronze: { min: 0, max: 750, color: LEAGUE_COLORS.Bronze },
  Silver: { min: 750, max: 900, color: LEAGUE_COLORS.Silver },
  Gold: { min: 900, max: 1050, color: LEAGUE_COLORS.Gold },
  Platinum: { min: 1050, max: 1200, color: LEAGUE_COLORS.Platinum },
  Diamond: { min: 1200, max: 1400, color: LEAGUE_COLORS.Diamond },
  Conqueror: { min: 1400, max: 1600, color: LEAGUE_COLORS.Conqueror },
};

// Generate box annotations for league backgrounds on Y-axis (for rating charts)
// Only shows bands that overlap with the visible data range [dataMin, dataMax]
export function generateLeagueYAxisAnnotations(showLeagueBands = true, dataMin = 0, dataMax = 1600) {
  if (!showLeagueBands) return {};

  const annotations = {};

  Object.entries(LEAGUE_RATING_RANGES).forEach(([league, { min, max, color }]) => {
    // Only include bands that overlap with the data range
    if (max >= dataMin && min <= dataMax) {
      annotations[`league_${league.toLowerCase()}`] = {
        type: "box",
        yMin: min,
        yMax: max,
        backgroundColor: color,
        borderWidth: 0,
        drawTime: "beforeDatasetsDraw",
        z: -1,
      };
    }
  });

  return annotations;
}

export const MUI_COLORS = [
  // RED
  "rgba(233, 30, 99, 1)", // #E91E63
  "rgba(230, 74, 25, 1)", // #E64A19
  // ORANGE
  "rgba(255, 152, 0, 1)", // #FF9800
  "rgba(255, 171, 64, 1)", // #FFAB40
  // YELLOW
  "rgba(255, 193, 7, 1)", // #FFC107
  "rgba(255, 196, 0, 1)", // #FFC400
  "rgba(255, 235, 59, 1)", // #FFEB3B
  // YELLOW-GREEN
  "rgba(205, 220, 57, 1)", // #CDDC39
  "rgba(139, 195, 74, 1)", // #8BC34A
  // GREEN
  "rgba(76, 175, 80, 1)", // #4CAF50
  "rgba(0, 150, 136, 1)", // #009688
  // CYAN
  "rgba(0, 188, 212, 1)", // #00BCD4
  "rgba(3, 169, 244, 1)", // #03A9F4
  // BLUE
  "rgba(33, 150, 243, 1)", // #2196F3
  "rgba(63, 81, 181, 1)", // #3F51B5
  // INDIGO/PURPLE
  "rgba(103, 58, 183, 1)", // #673AB7
  "rgba(156, 39, 176, 1)", // #9C27B0
  // PINK/MAGENTA
  "rgba(255, 105, 180, 1)", // #FF69B4
  "rgba(255, 102, 204, 1)", // #FF66CC
  // NEUTRALS
  "rgba(121, 85, 72, 1)", // #795548 - Brown
  "rgba(96, 125, 139, 1)", // #607D8B - Blue Grey
  "rgba(69, 90, 100, 1)", // #455A64
  "rgba(55, 71, 79, 1)", // #37474F
  "rgba(38, 50, 56, 1)", // #263238
  "rgba(33, 33, 33, 1)", // #212121 - Black
];

export const COUNTRY_UTILS = {
  regionNames: new Intl.DisplayNames(["en"], { type: "region" }),

  getFlag: (countryCode) => {
    if (countryCode === "unknown") return "🏳️";
    const codePoints = countryCode
      .toUpperCase()
      .split("")
      .map((char) => 127397 + char.charCodeAt());
    return String.fromCodePoint(...codePoints);
  },

  getName: (countryCode) => {
    if (countryCode === "unknown") return "Unknown";
    try {
      return COUNTRY_UTILS.regionNames.of(countryCode.toUpperCase());
    } catch {
      return countryCode.toUpperCase();
    }
  },

  getDisplayName: (countryCode) => {
    return `${COUNTRY_UTILS.getFlag(countryCode)} ${COUNTRY_UTILS.getName(countryCode)}`;
  },
};

export const TW_STONE_800 = "rgb(41, 37, 36)";
export const TW_ZINC_100 = "rgba(244, 244, 245,0.5)";

export const getDistributedColors = (count) => {
  const colorCount = MUI_COLORS.length;
  const colors = [];
  for (let i = 0; i < count; i++) {
    const index = Math.floor((i * colorCount) / count);
    colors.push(MUI_COLORS[index]);
  }
  return colors;
};

export const getMinutesFromBucket = (bucket) => {
  const bucketLabels = {
    _lt_600: "< 10 Minutes",
    _600_to_899: "10-15 Minutes",
    _900_to_1199: "15-20 Minutes",
    _1200_to_1499: "20-25 Minutes",
    _1500_to_1799: "25-30 Minutes",
    _1800_to_2699: "30-45 Minutes",
    _2700_to_3599: "45-60 Minutes",
    _gte3600: "> 60 Minutes",
  };

  const bucketOrder = Object.keys(bucketLabels);

  return { label: bucketLabels[bucket], order: bucketOrder.indexOf(bucket) };
};

export const setScales = (chart, isDark) => {
  chart.options.scales = {
    y: {
      ...chart.options.scales?.y,
      grid: {
        ...chart.options.scales?.y?.grid,
        color: isDark ? TW_ZINC_100 : TW_STONE_800,
        borderColor: isDark ? TW_ZINC_100 : TW_STONE_800,
      },
      ticks: {
        ...chart.options.scales?.y?.ticks,
        color: isDark ? TW_ZINC_100 : TW_STONE_800,
        borderColor: isDark ? TW_ZINC_100 : TW_STONE_800,
      },
    },
    x: chart.options.scales?.x,
  };
  chart.update();
};

export const setFiftyPercentLine = (chart, isDark) => {
  chart.options.plugins.annotation = {
    annotations: {
      line1: {
        type: "line",
        yMin: 50,
        yMax: 50,
        borderColor: isDark ? TW_ZINC_100 : TW_STONE_800,
        borderWidth: 5,
        borderDash: [10, 5],
        pointRadius: 0,
        hidden: true,
      },
    },
  };
  chart.update();
};

// Enhanced tooltip configuration with larger fonts and UI elements
export const getLargeTooltipConfig = (customConfig = {}) => {
  return {
    enabled: true,
    backgroundColor: "rgba(0, 0, 0, 0.9)",
    titleColor: "#ffffff",
    bodyColor: "#ffffff",
    borderColor: "#ffffff",
    borderWidth: 2,
    cornerRadius: 8,
    padding: 16,
    titleFont: {
      size: 18,
      weight: "bold",
      family: "Zabal",
    },
    bodyFont: {
      size: 16,
      weight: "normal",
      family: "Zabal",
    },
    footerFont: {
      size: 14,
      weight: "normal",
      family: "Zabal",
    },
    displayColors: true,
    boxWidth: 20,
    boxHeight: 20,
    usePointStyle: true,
    ...customConfig,
  };
};

// Enhanced always-show tooltip configuration with larger fonts
export const getLargeAlwaysShowTooltipConfig = (customConfig = {}) => {
  return {
    fontSize: 24,
    fontWeight: 900,
    color: customConfig.color || "black",
    valueFormatter: customConfig.valueFormatter || ((value) => String(value)),
    ...customConfig,
  };
};
