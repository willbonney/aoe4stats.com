// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import * as topbar from "../vendor/topbar.cjs";
import toggleThemeHook from "../vendor/toggle_theme";
// from https://medium.com/@lionel.aimerie/integrating-chart-js-into-elixir-phoenix-for-visual-impact-9a3991f0690f
import { Chart } from "chart.js/auto";
import annotationPlugin from "chartjs-plugin-annotation";
import AlwaysShowTooltipPlugin from "./always_show_tooltip_plugin.js";

Chart.register(annotationPlugin);

const MUI_COLORS = [
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

const TW_STONE_800 = "rgb(41, 37, 36)";
const TW_ZINC_100 = "rgba(244, 244, 245,0.5)";

// Function to distribute colors evenly across the spectrum
const getDistributedColors = (count) => {
  const colorCount = MUI_COLORS.length;
  const colors = [];
  for (let i = 0; i < count; i++) {
    const index = Math.floor((i * colorCount) / count);
    colors.push(MUI_COLORS[index]);
  }
  return colors;
};

const getMinutesFromBucket = (bucket) => {
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

const setScales = (chart, isDark) => {
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

const setFiftyPercentLine = (chart, isDark) => {
  chart.options.plugins.annotation = {
    annotations: {
      line1: {
        type: "line",
        yMin: 50,
        yMax: 50,
        borderColor: isDark ? TW_ZINC_100 : TW_STONE_800,
        borderWidth: 5,
        borderDash: [10, 5], // [dash length, gap length]
        pointRadius: 0,
        hidden: true,
      },
    },
  };
  chart.update();
};

const hooks = {};
hooks.OpponentsByCountry = {
  mounted() {
    const regionNamesInEnglish = new Intl.DisplayNames(["en"], {
      type: "region",
    });

    // Function to convert country code to flag emoji
    const getCountryFlag = (countryCode) => {
      const codePoints = countryCode
        .toUpperCase()
        .split("")
        .map((char) => 127397 + char.charCodeAt());
      return String.fromCodePoint(...codePoints);
    };

    const ctx = this.el;
    const data = {
      type: "doughnut",
      data: {
        datasets: [
          {
            data: [],
            // Use all MUI_COLORS excluding neutrals (indices 0-18)
            backgroundColor: MUI_COLORS.slice(0, 19),
          },
        ],
        hoverOffset: 4,
        borderJoinStyle: "bevel",
      },
      plugins: [AlwaysShowTooltipPlugin],
      options: {
        responsive: true,
        plugins: {
          tooltip: {
            callbacks: {
              label: (context) => `${context.formattedValue}%`,
              afterBody: function (context) {
                if (!context || !context[0]) {
                  return [];
                }
                
                const label = context[0].label;

                if (label === "Other" && chart.otherCountries) {
                  // Get the other countries data
                  const otherCountries = Object.entries(chart.otherCountries).map(
                    ([country, percentage]) => `${getCountryFlag(country)} ${country.toUpperCase()}: ${percentage}%`
                  );

                  // Return each country on its own line
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
            bodyFont: {
              size: 14,
            },
            titleFont: {
              size: 16,
              weight: "bold",
            },
            filter: function(tooltipItem) {
              // Only show tooltip for "Other" category
              const label = tooltipItem.label || '';
              return label.toLowerCase().includes('other');
            },
          },
          legend: {
            position: "top",
            display: false,
          },
          title: {
            display: false,
            text: "Opponents by Country",
          },
          alwaysShowTooltip: {
            valueFormatter: (value) => `${value.toFixed(0)}%`,
            skipLabels: ['other'],
          },
        },
      },
    };
    const chart = new Chart(ctx, data);
    this.handleEvent("update-opponents-by-country", (event) => {
      const threshold = 3; // Percentage threshold for "Other" category
      let otherPercentage = 0;
      const otherCountries = {};
      const filteredData = Object.entries(event.byCountry).reduce((acc, [country, percentage]) => {
        if (percentage >= threshold) {
          acc[country] = percentage;
        } else {
          otherPercentage += percentage;
          // create map with percentages of other countries
          if (!otherCountries[country]) {
            otherCountries[country] = percentage;
          } else {
            otherCountries[country] += percentage;
          }
        }
        return acc;
      }, {});

      if (otherPercentage > 0) {
        filteredData.other = otherPercentage;
      }

      // Distribute colors evenly based on number of countries
      const colorCount = Object.keys(filteredData).length;
      chart.data.datasets[0].backgroundColor = getDistributedColors(colorCount);

      chart.data.datasets[0].data = Object.values(filteredData);
      chart.data.labels = Object.keys(filteredData).map((country) =>
        country === "other" ? "Other" : getCountryFlag(country) + " " + regionNamesInEnglish.of(country.toUpperCase())
      );

      // Store other countries data for tooltip
      chart.otherCountries = otherCountries;

      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-opponents-by-country", null);
  },
};

hooks.MovingAverages = {
  mounted() {
    const ctx = this.el;
    const data = {
      type: "line",
      data: {},
      options: {
        scales: {
          x: {
            display: false,
          },
        },
        responsive: true,
        plugins: {
          tooltip: {
            // backgroundColor: "white",
            // bodyColor: "black",
            // bodyFont: {
            //   size: 16,
            // },
            // titleFont: {
            // // callbacks: {
            // //   label: function (context) {
            // //     return `${context.formattedValue}%`;
            // //   },
            // },
          },
          legend: {
            position: "top",
          },
          title: {
            display: false,
            text: "Moving Average",
          },
        },
      },
    };
    const sortByDate = (unsorted) => unsorted.sort((a, b) => new Date(a.updated_at) - new Date(b.updated_at));
    const chart = new Chart(ctx, data);

    this.handleEvent("update-player", (event) => {
      const sorted = sortByDate(event.movingAverages);
      setScales(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setScales(chart, isDark);
        chart.update();
      });

      chart.data.datasets.push(
        {
          data: sortByDate(sorted).map(({ moving_average_5g }) => moving_average_5g),
          label: "5 Game",
          borderColor: MUI_COLORS[11],
          backgroundColor: MUI_COLORS[11],
        },
        {
          data: sortByDate(sorted).map(({ moving_average_10g }) => moving_average_10g),
          label: "10 Game",
          borderColor: MUI_COLORS[13],
          backgroundColor: MUI_COLORS[13],
        },
        {
          data: sortByDate(sorted).map(({ moving_average_20g }) => moving_average_20g),
          label: "20 Game",
          borderColor: MUI_COLORS[14],
          backgroundColor: MUI_COLORS[14],
        }
      );
      chart.data.labels = sorted.map((m) =>
        (() => {
          const date = new Date(m.updated_at);
          const day = date.getDate();
          const month = date.toLocaleDateString(undefined, { month: "short" });
          const year = date.getFullYear().toString().slice(-2);
          return `${day}-${month}-${year}`.toUpperCase();
        })()
      );
      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-player", null);
  },
};

// const duration = (ctx) =>
// const delay =
hooks.RankHistory = {
  mounted() {
    const ctx = this.el;

    const totalDuration = 2500;
    const getDatasetLength = (ctx) => {
      if (ctx?.chart?.data?.datasets?.length > 0 && typeof ctx?.datasetIndex === "number") {
        return ctx.chart.data.datasets[ctx.datasetIndex].data.length;
      }
      return 100;
    };
    const data = {
      type: "line",
      data: {},
      options: {
        animation: {
          x: {
            easing: "easeOutQuad",
            type: "number",
            duration(ctx) {
              const datasetLength = getDatasetLength(ctx);
              return ((ctx.index / datasetLength) * totalDuration) / datasetLength;
            },
            delay(ctx) {
              const datasetLength = getDatasetLength(ctx);

              if (ctx.type !== "data" || ctx.xStarted) {
                return 0;
              }
              ctx.xStarted = true;
              return (ctx.index / datasetLength) * totalDuration;
            },
          },
          y: {
            type: "number",
            easing: "easeOutQuad",
            duration(ctx) {
              const datasetLength = getDatasetLength(ctx);
              return ((ctx.index / datasetLength) * totalDuration) / datasetLength;
            },
            from: NaN,
            delay(ctx) {
              const datasetLength = getDatasetLength(ctx);

              if (ctx.type !== "data" || ctx.yStarted) {
                return 0;
              }
              ctx.yStarted = true;
              return (ctx.index / datasetLength) * totalDuration;
            },
          },
        },
        responsive: true,
        layout: {
          padding: {
            right: 30,
          },
        },
        scales: {
          y: {
            reverse: true,
            min: 1,
            title: {
              display: true,
              text: "Rank",
            },
            ticks: {
              callback: function (value) {
                return `#${value.toFixed(0).toLocaleString()}`;
              },
            },
          },
        },
        plugins: {
          legend: {
            position: "top",
            display: false,
          },
          title: {
            display: false,
            text: "Rank History",
          },
        },
      },
    };

    const chart = new Chart(ctx, data);
    this.handleEvent("update-player", (event) => {
      setScales(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setScales(chart, isDark);
        chart.update();
      });

      const rankData = event.rankHistory.map(({ rank }) => rank).reverse();
      const maxRankValue = Math.max(...rankData);

      chart.data.datasets.push({
        data: rankData,
        label: "Rank",
        pointStyle: "circle",
        pointRadius: 10,
        pointHoverRadius: 15,
        fill: false,
        stepped: true,
        borderColor: MUI_COLORS[1],
        backgroundColor: MUI_COLORS[1],
      });
      chart.data.labels = event.rankHistory.map((m) => `Season ${m.season}`).reverse();

      chart.options.scales.y.max = 1.2 * maxRankValue;
      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-player", null);
  },
};

hooks.WrsByGameLength = {
  mounted() {
    const ctx = this.el;
    const data = {
      type: "bar",
      data: {},
      // plugins: [annotationPlugin],

      options: {
        responsive: true,
        scales: {
          y: {
            title: {
              display: true,
              text: "Win %",
            },
            beginAtZero: true,
          },
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.formattedValue}%`,
            },
          },
          title: {
            display: false,
            text: "WRs by Game Length",
          },
        },
      },
    };

    const chart = new Chart(ctx, data);

    this.handleEvent("update-wrs", (event) => {
      setScales(chart, localStorage.getItem("theme") === "dark");
      setFiftyPercentLine(chart, localStorage.getItem("theme") === "dark");

      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setScales(chart, isDark);
        setFiftyPercentLine(chart, isDark);
      });

      const split = Object.entries(event.byLength);

      const sortedSplit = split.sort((a, b) => getMinutesFromBucket(a[0]).order - getMinutesFromBucket(b[0]).order);
      console.log(sortedSplit);

      chart.data.datasets.push({
        data: sortedSplit.map(([length, wr]) => wr),
        label: "Win Rate",
        borderColor: MUI_COLORS.slice(0, sortedSplit.length),
        backgroundColor: MUI_COLORS.map((color) => `${color.slice(0, -4)}, 0.8)`).slice(0, sortedSplit.length),
        borderWidth: 1,
        barThickness: 50,
      });
      chart.data.labels = sortedSplit.map(([length]) => getMinutesFromBucket(length).label);
      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-wrs", null);
  },
};

hooks.PercentageTimeInRank = {
  mounted() {
    const ctx = this.el;
    
    const data = {
      type: "doughnut",
      data: {
        datasets: [
          {
            data: [],
            backgroundColor: MUI_COLORS,
          },
        ],
      },
      plugins: [AlwaysShowTooltipPlugin],

      options: {

        responsive: true,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.raw.toFixed(0)}%`,
              afterBody: function (context) {
                if (!context || !context[0]) {
                  return [];
                }
                
                const label = context[0].label;

                if (label === "other" && chart.otherRanks) {
                  // Get the other ranks data, filtering out 0% entries
                  const otherRanks = Object.entries(chart.otherRanks)
                    .filter(([rank, percentage]) => percentage > 0)
                    .map(([rank, percentage]) => `${rank}: ${percentage.toFixed(1)}%`);

                  // Return each rank on its own line
                  return ["", ...otherRanks];
                }
                return [];
              },
            },
            filter: function(tooltipItem) {
              // Only show tooltip for "Other" category
              const label = tooltipItem.label || '';
              return label.toLowerCase().includes('other');
            },
          },
          labels: {
            font: {
              size: 14,
            },
          },
          title: {
            display: false,
            text: "Percentage Time in Rank",
          },
          alwaysShowTooltip: {
            color: 'white', // Set tooltip text color,
            valueFormatter: (value) => `${value.toFixed(0)}%`,
            skipLabels: ['other'],
          },
        },
      },
    };

    const chart = new Chart(ctx, data);
    this.handleEvent("update-player", (event) => {
      const percentageTimeInRank = event.percentageTimeInRank;
      
      // Apply threshold filtering similar to OpponentsByCountry
      const threshold = 3;
      let otherPercentage = 0;
      const otherRanks = {};
      const filteredData = Object.entries(percentageTimeInRank).reduce((acc, [rank, data]) => {
        if (data.percentage >= threshold) {
          acc[rank] = data;
        } else {
          otherPercentage += data.percentage;
          // Store other ranks data for potential tooltip use
          otherRanks[rank] = data.percentage;
        }
        return acc;
      }, {});

      if (otherPercentage > 0) {
        filteredData.other = {
          percentage: otherPercentage,
          color: MUI_COLORS[3] // Use MUI_COLORS[3] for "Other" category
        };
        // Store other ranks data on chart for tooltip use
        chart.otherRanks = otherRanks;
      } else {
        chart.otherRanks = null;
      }
      
      // Extract data and colors from the filtered structure
      const data = Object.values(filteredData).map(item => item.percentage);
      const colors = Object.values(filteredData).map(item => item.color);
      const labels = Object.keys(filteredData);
      
      chart.data.datasets[0].data = data;
      chart.data.datasets[0].backgroundColor = colors;
      chart.data.labels = labels;

      chart.update();
    });
  },
  beforeUnmount() {
    this.handleEvent("update-percentage-time-in-rank", null);
  },
};

hooks.Analysis = {
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
            callbacks: {
              label: (context) => `${context.raw.toFixed(1)}%`
            
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
            size: 18
          }
        },
        ticks: {
          ...chart.options.scales.r.ticks,
          color: color,
          backdropColor: isDark ? 'rgba(39, 39, 42, 0.8)' : 'rgba(255, 255, 255, 0.8)',
        },
      };
      chart.update();
    };
    
    // Set up hover interactions between metric boxes and chart segments
    const setupHoverInteractions = () => {
      const metricBoxes = document.querySelectorAll("#metric-descriptions [data-metric]");
      
      metricBoxes.forEach((box, index) => {
        box.addEventListener("mouseenter", () => {
          // Trigger hover on the corresponding chart segment
          const activeElements = [{
            datasetIndex: 0,
            index: index,
          }];
          chart.setActiveElements(activeElements);
          chart.tooltip.setActiveElements(activeElements);
          chart.update();
        });
        
        box.addEventListener("mouseleave", () => {
          // Clear hover state
          chart.setActiveElements([]);
          chart.tooltip.setActiveElements([]);
          chart.update();
        });
      });
    };
    
    this.handleEvent("update-analysis", (event) => {
      const analysis = event.analysis;
      
      // Define the metric labels and order
      const metrics = [
        { key: "consistency", label: "Consistency" },
        { key: "recovery", label: "Recovery" },
        { key: "momentum", label: "Momentum" },
        { key: "anti_tilt", label: "Anti-Tilt" },
        { key: "pressure_performance", label: "Pressure" },
        { key: "rating_efficiency", label: "Efficiency" },
        { key: "versatility", label: "Versatility" },
      ];
      
      // Extract data and labels in the correct order
      chart.data.labels = metrics.map((m) => m.label);
      chart.data.datasets[0].data = metrics.map((m) => analysis[m.key] || 50.0);
      
      // Set initial theme
      setPolarScales(chart, localStorage.getItem("theme") === "dark");
      
      // Listen for theme changes
      window.addEventListener("themeChanged", (e) => {
        const { isDark } = e.detail;
        setPolarScales(chart, isDark);
      });
      
      chart.update();
      
      setTimeout(setupHoverInteractions, 100);
    });
  },
  beforeUnmount() {
    this.handleEvent("update-analysis", null);
  },
};

hooks.DarkThemeToggle = toggleThemeHook;

// *****
// *****
// *****

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: hooks,
});
// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#273649" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// *****
// *****
// *****

// from https://fly.io/phoenix-files/copy-to-clipboard-with-phoenix-liveview/

window.addEventListener("phx:copy", (event) => {
  let text = event.target.value;

  navigator.clipboard
    .writeText(text)
    .then(() => {})
    .catch((err) => {});
});
