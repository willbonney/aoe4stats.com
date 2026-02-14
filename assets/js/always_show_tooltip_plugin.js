// https://gist.github.com/mxsxs2/8de4e5b3f798b833fb6a59e07ea6e72b

/**
 * Chart.js plugin to display always-visible tooltips (data values) on chart elements.
 *
 * Supports bar, line, pie, and doughnut charts. Skips values that are 0 or null.
 * Tooltip text is centered inside each chart element:
 * - Bars: vertically centered in the bar
 * - Lines: slightly above each point
 * - Pie/Doughnut: centered in each arc
 *
 * Plugin options can be set via `chartOptions.plugins.alwaysShowTooltip`, for example:
 * ```js
 * plugins: {
 *   alwaysShowTooltip: {
 *     color: 'white', // sets the tooltip text color
 *   }
 * }
 * ```
 */

const AlwaysShowTooltipPlugin = {
  id: "alwaysShowTooltip",

  // Helper function to determine if background is light or dark
  getContrastColor(backgroundColor) {
    // Convert hex to RGB
    const hex = backgroundColor.replace("#", "");
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);

    // Calculate luminance
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    // Return black for light backgrounds, white for dark backgrounds
    return luminance > 0.5 ? "#000000" : "#FFFFFF";
  },

  afterDatasetsDraw(chart, _, pluginOptions) {
    const { ctx } = chart;
    const chartType = chart.config.type;
    const color = pluginOptions?.color ?? "black"; // default to black

    ctx.save();
    ctx.font = `${pluginOptions?.fontSize ?? 24}px Zabal`;
    ctx.textAlign = "center";
    ctx.fontWeight = `${pluginOptions?.fontWeight ?? 900}`;

    chart.data.datasets.forEach((dataset, datasetIndex) => {
      const meta = chart.getDatasetMeta(datasetIndex);

      meta.data.forEach((element, index) => {
        const value = dataset.data[index];
        const formattedValue = pluginOptions?.valueFormatter(value) ?? String(value);
        if (!value) return;

        if (chartType === "bar") {
          const x = element.x;
          const y = (element.base + element.y) / 2;
          ctx.fillStyle = color;
          ctx.fillText(formattedValue, x, y);
        }

        if (chartType === "line") {
          const { x, y } = element;
          ctx.fillStyle = color;
          ctx.fillText(formattedValue, x, y - 10);
        }

        if (chartType === "pie" || chartType === "doughnut") {
          const { x, y } = element.getCenterPoint();

          // Get the background color for this segment
          const backgroundColor = dataset.backgroundColor[index];

          // Determine appropriate text color based on background
          const textColor = this.getContrastColor(backgroundColor);
          ctx.fillStyle = textColor;

          // For pie/doughnut charts, show both label and percentage
          const label = chart.data.labels[index];
          const percentage = formattedValue;

          // Draw label above the percentage
          ctx.fillText(label, x, y - 8);
          ctx.fillText(percentage, x, y + 8);
        }
      });
    });

    ctx.restore();
  },
};

export default AlwaysShowTooltipPlugin;
