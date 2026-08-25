const LABEL_ATTR = "data-chart-polar-labels";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function ensureLayer(wrap) {
  wrap.style.position = wrap.style.position || "relative";

  let layer = wrap.querySelector(`[${LABEL_ATTR}]`);
  if (!layer) {
    layer = document.createElement("div");
    layer.setAttribute(LABEL_ATTR, "");
    layer.className = "pointer-events-none absolute inset-0 z-10 overflow-visible";
    wrap.appendChild(layer);
  }
  return layer;
}

function formatScore(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n.toFixed(1) : "";
}

const HtmlPolarLabelsPlugin = {
  id: "htmlPolarLabels",

  afterDraw(chart) {
    if (chart.config.type !== "polarArea") return;

    const canvas = chart.canvas;
    const wrap = canvas?.parentElement;
    const scale = chart.scales?.r;
    if (!wrap || !scale) return;

    const items = scale._pointLabelItems || [];
    const labels = chart.data.labels || [];
    if (!labels.length || items.length !== labels.length) {
      chart.$htmlPolarLabelsLayer?.replaceChildren();
      chart.$polarLabelsHtml = "";
      return;
    }

    const layer = ensureLayer(wrap);
    chart.$htmlPolarLabelsLayer = layer;

    const dark = localStorage.getItem("theme") === "dark";
    const nameClass = dark ? "text-zinc-100" : "text-stone-800";
    const values = chart.data.datasets?.[0]?.data || [];
    const colors = chart.$polarColors || [];
    const active = new Set(chart.getActiveElements().map((el) => el.index));
    const hasActive = active.size > 0;
    const ox = canvas.offsetLeft;
    const oy = canvas.offsetTop;

    const html = labels
      .map((label, index) => {
        const item = items[index];
        if (!item?.visible) return "";

        const score = formatScore(values[index]);
        const color = colors[index] || (dark ? "#f4f4f5" : "#292524");
        const dimmed = hasActive && !active.has(index);
        const opacity = dimmed ? "opacity-40" : "opacity-100";
        const align = item.textAlign === "left" ? "left" : item.textAlign === "right" ? "right" : "center";

        return `<div data-polar-label="${index}" class="absolute ${nameClass} ${opacity} leading-tight transition-opacity duration-150" style="left:${ox + item.x}px;top:${oy + item.y}px;transform:translate(${align === "center" ? "-50%" : align === "right" ? "-100%" : "0"},0);text-align:${align}">
          <div class="text-[15px] font-semibold tracking-tight antialiased whitespace-nowrap">${escapeHtml(label)}</div>
          ${score ? `<div class="font-zabal font-black text-[15px] tabular-nums leading-none mt-0.5 whitespace-nowrap" style="color:${escapeHtml(color)}">${escapeHtml(score)}</div>` : ""}
        </div>`;
      })
      .join("");

    if (chart.$polarLabelsHtml === html) return;
    chart.$polarLabelsHtml = html;
    layer.innerHTML = html;
  },

  afterDestroy(chart) {
    chart.$polarLabelsHtml = "";
    chart.$htmlPolarLabelsLayer?.remove();
    chart.canvas?.parentElement?.querySelector(`[${LABEL_ATTR}]`)?.remove();
  },
};

export default HtmlPolarLabelsPlugin;
