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

  afterDatasetsDraw(chart, _, pluginOptions) {
    const { ctx } = chart;
    const chartType = chart.config.type;
    const color = pluginOptions?.color ?? "black"; // default to black

    ctx.save();
    ctx.font = "16px sans-serif";
    ctx.textAlign = "center";
    ctx.fontWeight = 900;

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
          ctx.fillStyle = color;
          ctx.fillText(formattedValue, x, y);
        }
      });
    });

    ctx.restore();
  },
};

export default AlwaysShowTooltipPlugin;
