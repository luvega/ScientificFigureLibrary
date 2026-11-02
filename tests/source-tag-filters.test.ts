import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { JSDOM } from "jsdom";
import { createSourceTagFilters } from "../app/local/source-tag-filters.ts";

test("Local classification dropdowns use source labels and submit an exact AND pair; clearing restores all", async () => {
  const html = await fs.readFile(path.resolve(import.meta.dirname, "../app/local-app.html"), "utf8");
  const dom = new JSDOM(html);
  try {
    const document = dom.window.document;
    const type = document.getElementById("search-data-type") as HTMLSelectElement;
    const purpose = document.getElementById("search-plot-purpose") as HTMLSelectElement;
    const clear = document.getElementById("clear-source-filters") as HTMLButtonElement;
    const requests: string[][] = [];
    const filters = createSourceTagFilters(document, () => requests.push(filters.requiredTags()));
    filters.update({ providerId: "org.scientificfigurelibrary.local", tags: [
      { value: "数据类型:表达矩阵", count: 2 }, { value: "作图目的:比较表达模式", count: 1 },
      { value: "数据类型:全新类型", count: 1 }, { value: "data-type:numeric_matrix", count: 2 },
      { value: "purpose:matrix_pattern", count: 1 }, { value: "表达矩阵", count: 4 },
      { value: "数据类型:", count: 1 }, { value: "数据类型:表达矩阵", count: 2 },
    ] });
    assert.deepEqual([...type.options].map(option => option.textContent).sort(), ["全部数据类型", "全新类型", "表达矩阵"].sort());
    assert.deepEqual([...purpose.options].map(option => option.textContent), ["全部作图目的", "比较表达模式"]);
    assert.deepEqual(filters.requiredTags(), []);
    assert.equal(clear.disabled, true);
    type.value = "数据类型:表达矩阵";
    type.dispatchEvent(new dom.window.Event("change"));
    purpose.value = "作图目的:比较表达模式";
    purpose.dispatchEvent(new dom.window.Event("change"));
    assert.deepEqual(requests.at(-1), ["数据类型:表达矩阵", "作图目的:比较表达模式"]);
    assert.equal(clear.disabled, false);
    // Paginated responses omit facets; they must not shrink or reset either control.
    filters.update(undefined);
    assert.equal(type.options.length, 3);
    assert.deepEqual(filters.requiredTags(), requests.at(-1));
    clear.click();
    assert.deepEqual(requests.at(-1), []);
    assert.equal(type.value, "");
    assert.equal(purpose.value, "");
    assert.equal(clear.disabled, true);
    filters.update({ providerId: "other-provider", tags: [{ value: "数据类型:不应加入", count: 1 }] });
    assert.equal(type.options.length, 3);
    filters.update({ providerId: "org.scientificfigurelibrary.local", tags: [] });
    assert.equal(type.options.length, 1);
    assert.equal(purpose.options.length, 1);
  } finally { dom.window.close(); }
});
