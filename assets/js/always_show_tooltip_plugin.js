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

  getContrastColor(backgroundColor) {
    let r = 0;
    let g = 0;
    let b = 0;
    const value = String(backgroundColor || "");

    if (value.startsWith("rgb")) {
      const parts = value.match(/[\d.]+/g) || [];
      r = Number(parts[0]);
      g = Number(parts[1]);
      b = Number(parts[2]);
    } else {
      const hex = value.replace("#", "");
      r = parseInt(hex.substr(0, 2), 16) || 0;
      g = parseInt(hex.substr(2, 2), 16) || 0;
      b = parseInt(hex.substr(4, 2), 16) || 0;
    }

    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? "#000000" : "#FFFFFF";
  },

  splitFlagLabel(label) {
    const chars = Array.from(String(label || ""));
    if (chars.length >= 2) {
      const first = chars[0].codePointAt(0);
      const second = chars[1].codePointAt(0);
      const isRegional = (code) => code >= 0x1f1e6 && code <= 0x1f1ff;
      if (isRegional(first) && isRegional(second)) {
        return { flag: chars[0] + chars[1], name: chars.slice(2).join("").trim() };
      }
    }
    return { flag: "", name: String(label || "") };
  },

  drawFlagWithBorder(ctx, flag, x, y, fontSize) {
    ctx.save();
    ctx.font = `${fontSize}px "Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji", sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const width = ctx.measureText(flag).width;
    const padX = 2;
    const padY = 1.5;
    const left = Math.round(x - width / 2 - padX) + 0.5;
    const top = Math.round(y - fontSize / 2 - padY) + 0.5;
    ctx.strokeStyle = "#000000";
    ctx.lineWidth = 1;
    ctx.strokeRect(left, top, width + padX * 2, fontSize + padY * 2);
    ctx.fillText(flag, x, y);
    ctx.restore();
  },

  drawFlagImage(ctx, img, x, y, width, height) {
    const left = Math.round(x) + 0.5;
    const top = Math.round(y) + 0.5;
    ctx.save();
    if (img?.complete && img.naturalWidth) {
      ctx.drawImage(img, left, top, width, height);
    }
    ctx.strokeStyle = "#000000";
    ctx.lineWidth = 1;
    ctx.strokeRect(left, top, width, height);
    ctx.restore();
  },

  afterDatasetsDraw(chart, _, pluginOptions) {
    if (pluginOptions?.disabled) return;

    const { ctx } = chart;
    const chartType = chart.config.type;
    const color = pluginOptions?.color ?? "black"; // default to black
    const minSliceRatio = pluginOptions?.minSliceRatio ?? 0;

    ctx.save();
    const fontFamily = pluginOptions?.fontFamily ?? "Zabal";
    ctx.font = `${pluginOptions?.fontWeight ?? 900} ${pluginOptions?.fontSize ?? 24}px ${fontFamily}`;
    ctx.textAlign = "center";

    chart.data.datasets.forEach((dataset, datasetIndex) => {
      const meta = chart.getDatasetMeta(datasetIndex);

      meta.data.forEach((element, index) => {
        const value = dataset.data[index];
        const formattedValue = pluginOptions?.valueFormatter(value) ?? String(value);
        if (!value) return;

        if (chartType === "bar") {
          const horizontal = chart.options.indexAxis === "y";
          ctx.fillStyle = color;
          if (horizontal) {
            ctx.textAlign = "left";
            ctx.textBaseline = "middle";
            ctx.fillText(formattedValue, element.x + 6, element.y);
          } else {
            const x = element.x;
            const y = (element.base + element.y) / 2;
            ctx.fillText(formattedValue, x, y);
          }
        }

        if (chartType === "line") {
          const { x, y } = element;
          ctx.fillStyle = color;
          ctx.fillText(formattedValue, x, y - 10);
        }

        if (chartType === "pie" || chartType === "doughnut") {
          const total = dataset.data.reduce((sum, n) => sum + (Number(n) || 0), 0);
          const ratio = total > 0 ? value / total : 0;
          if (minSliceRatio > 0 && ratio < minSliceRatio) return;

          const { x, y } = element.getCenterPoint();
          const backgroundColor = Array.isArray(dataset.backgroundColor)
            ? dataset.backgroundColor[index]
            : dataset.backgroundColor;
          const textColor = this.getContrastColor(backgroundColor);
          const label = chart.data.labels[index];
          const { flag, name } = this.splitFlagLabel(label);
          const flagCode = chart.$labelFlags?.[index];
          const flagImg = flagCode ? chart.$flagImages?.[flagCode.toLowerCase()] : null;
          const hasFlagImage = Boolean(flagImg?.complete && flagImg.naturalWidth);
          const baseSize = pluginOptions?.fontSize ?? 24;
          const fontSize = ratio > 0 && ratio < 0.06 ? Math.max(10, baseSize - 3) : baseSize;
          const displayName = hasFlagImage || flag ? name || label : label;

          ctx.font = `${pluginOptions?.fontWeight ?? 900} ${fontSize}px ${fontFamily}`;
          ctx.textBaseline = "middle";
          ctx.fillStyle = textColor;

          if (hasFlagImage || flag) {
            const flagW = hasFlagImage ? 22 : fontSize + 2;
            const flagH = hasFlagImage ? 16 : fontSize + 2;
            const nameWidth = ctx.measureText(displayName).width;
            const gap = 5;
            const flagBox = flagW + 2;
            const rowWidth = flagBox + gap + nameWidth;
            const rowLeft = x - rowWidth / 2;
            if (hasFlagImage) {
              this.drawFlagImage(ctx, flagImg, rowLeft, y - 8 - flagH / 2, flagW, flagH);
            } else {
              this.drawFlagWithBorder(ctx, flag, rowLeft + flagBox / 2, y - 8, flagH);
            }
            ctx.font = `${pluginOptions?.fontWeight ?? 900} ${fontSize}px ${fontFamily}`;
            ctx.textAlign = "left";
            ctx.fillStyle = textColor;
            ctx.fillText(displayName, rowLeft + flagBox + gap, y - 8);
            ctx.textAlign = "center";
            ctx.fillText(formattedValue, x, y + 10);
          } else {
            ctx.textAlign = "center";
            ctx.fillText(displayName, x, y - 8);
            ctx.fillText(formattedValue, x, y + 8);
          }
        }
      });
    });

    ctx.restore();
  },
};

export default AlwaysShowTooltipPlugin;
