import assert from "node:assert/strict";
import test from "node:test";
import definitions from "../../shared/data/items.json";
import names from "../../client/data/item_names_ru.json";

test("every authoritative item definition has a Russian display name", () => {
  assert.deepEqual(Object.keys(names).sort(), Object.keys(definitions).sort());
  assert.ok(Object.values(names).every((name) => /[А-Яа-яЁё]/.test(name)));
});
