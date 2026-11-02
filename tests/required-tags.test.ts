import assert from "node:assert/strict";
import test from "node:test";
import { matchesRequiredTags, normalizeRequiredTags, RequiredTagsSchema } from "../src/search-tags.ts";

test("required tags use exact case-sensitive AND matching without changing source metadata", () => {
  const source = [" purpose:matrix_pattern ", "data-type:numeric_matrix", "cafe\u0301", "中文"];
  const original = [...source];
  assert.deepEqual(normalizeRequiredTags([" 中文 ", "", "中文", "cafe\u0301", "café"]), ["café", "中文"]);
  assert.equal(matchesRequiredTags(source, ["purpose:matrix_pattern", "data-type:numeric_matrix", "café"]), true);
  assert.equal(matchesRequiredTags(source, ["purpose:matrix_pattern", "missing"]), false);
  assert.equal(matchesRequiredTags(source, ["Purpose:matrix_pattern"]), false);
  assert.equal(matchesRequiredTags(source, ["matrix_pattern"]), false);
  assert.equal(matchesRequiredTags(undefined, ["中文"]), false);
  assert.equal(matchesRequiredTags(undefined, []), true);
  assert.equal(matchesRequiredTags(undefined, [" "]), true);
  assert.deepEqual(source, original);
  assert.deepEqual(RequiredTagsSchema.parse([" z ", "a", "a"]), ["a", "z"]);
  assert.equal(RequiredTagsSchema.safeParse([1]).success, false);
  assert.equal(RequiredTagsSchema.safeParse(["x".repeat(201)]).success, false);
  assert.equal(RequiredTagsSchema.safeParse(Array(101).fill("a")).success, false);
});
