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
      layer.className = "pointer-events-none absolute inset-0 z-10 overflow-visible";
      wrap.appendChild(layer);
    }

    chart.$htmlYLabelsLayer = layer;

    const dark = localStorage.getItem("theme") === "dark";
    const textClass = dark ? "text-zinc-100" : "text-stone-800";
    const labels = chart.data.labels || [];
    const images = chart.$htmlYLabelImages || [];

    const hasImages = images.some(Boolean);
    const align = hasImages ? "justify-start" : "justify-end";
    const pad = hasImages ? "padding-left:8px;padding-right:8px" : "padding-right:8px";

    layer.innerHTML = labels
      .map((label, index) => {
        const top = yScale.getPixelForTick(index);
        const image = images[index];
        const flag = image
          ? `<img src="${escapeHtml(image)}" alt="" class="w-8 h-5 shrink-0 object-cover" style="border:1px solid #000" />`
          : "";
        return `<div class="absolute ${textClass} text-[15px] leading-5 font-medium flex items-center ${align} gap-1.5" style="top:${top}px;left:0;width:${Math.max(yScale.width - 8, 0)}px;transform:translateY(-50%);${pad}">${flag}<span class="truncate">${escapeHtml(label)}</span></div>`;
      })
      .join("");
  },

  afterDestroy(chart) {
    chart.$htmlYLabelsLayer?.remove();
    chart.canvas?.parentElement?.querySelector(`[${LABEL_ATTR}]`)?.remove();
  },
};

export default HtmlYLabelsPlugin;
