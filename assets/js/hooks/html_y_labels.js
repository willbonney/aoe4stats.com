const LABEL_ATTR = "data-chart-y-labels";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

const HtmlYLabelsPlugin = {
  id: "htmlYLabels",

  afterDraw(chart) {
    const canvas = chart.canvas;
    const wrap = canvas?.parentElement;
    const yScale = chart.scales?.y;
    if (!wrap || !yScale) return;

    wrap.style.position = wrap.style.position || "relative";

    let layer = wrap.querySelector(`[${LABEL_ATTR}]`);
    if (!layer) {
      layer = document.createElement("div");
      layer.setAttribute(LABEL_ATTR, "");
      layer.className = "pointer-events-none absolute inset-0 overflow-visible";
      wrap.appendChild(layer);
    }

    chart.$htmlYLabelsLayer = layer;

    const dark = localStorage.getItem("theme") === "dark";
    const textClass = dark ? "text-zinc-100" : "text-stone-800";
    const labels = chart.data.labels || [];

    layer.innerHTML = labels
      .map((label, index) => {
        const top = yScale.getPixelForTick(index);
        return `<div class="absolute ${textClass} text-[15px] leading-5 font-medium truncate" style="top:${top}px;left:0;width:${Math.max(yScale.width - 8, 0)}px;transform:translateY(-50%);text-align:right;padding-right:8px">${escapeHtml(label)}</div>`;
      })
      .join("");
  },

  afterDestroy(chart) {
    chart.$htmlYLabelsLayer?.remove();
    chart.canvas?.parentElement?.querySelector(`[${LABEL_ATTR}]`)?.remove();
  },
};

export default HtmlYLabelsPlugin;
