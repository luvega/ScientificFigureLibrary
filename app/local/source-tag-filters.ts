const LOCAL_PROVIDER = "org.scientificfigurelibrary.local";
const FILTERS = [
  { id: "search-data-type", prefix: "数据类型:", empty: "全部数据类型" },
  { id: "search-plot-purpose", prefix: "作图目的:", empty: "全部作图目的" },
] as const;

/** Chinese classification labels come only from Published source metadata. */
export function createSourceTagFilters(document: Document, onChange: () => void) {
  const controls = FILTERS.map((filter) => ({
    ...filter,
    select: document.getElementById(filter.id) as HTMLSelectElement,
  }));
  const clear = document.getElementById("clear-source-filters") as HTMLButtonElement;
  const requiredTags = () => controls.map(({ select }) => select.value).filter(Boolean);
  const syncClear = () => { clear.disabled = requiredTags().length === 0; };
  for (const { select } of controls) select.addEventListener("change", () => { syncClear(); onChange(); });
  clear.addEventListener("click", () => {
    for (const { select } of controls) select.value = "";
    syncClear(); onChange();
  });
  function update(raw: unknown) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return;
    const snapshot = raw as { providerId?: unknown; tags?: unknown };
    if (snapshot.providerId !== LOCAL_PROVIDER || !Array.isArray(snapshot.tags)) return;
    const tags = snapshot.tags.flatMap((item) => {
      if (!item || typeof item !== "object" || Array.isArray(item)) return [];
      const value = (item as { value?: unknown }).value;
      return typeof value === "string" ? [value] : [];
    });
    for (const { select, prefix, empty } of controls) {
      const selected = select.value;
      const values = [...new Set(tags.filter((tag) => tag.startsWith(prefix) && tag.slice(prefix.length).trim()))];
      // Preserve a previously selected label until the user clears it, even after a Library change.
      if (selected && !values.includes(selected)) values.push(selected);
      values.sort((left, right) => left.localeCompare(right, "zh-CN"));
      select.replaceChildren(...["", ...values].map((value) => {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = value ? value.slice(prefix.length) : empty;
        return option;
      }));
      select.value = selected;
    }
    syncClear();
  }
  syncClear();
  return { update, requiredTags };
}
