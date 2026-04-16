import { describe, expect, it } from "vitest";

import { normalizePokewalletQuery } from "./pokewalletQueryNormalizer";

describe("pokewallet query normalizer", () => {
  it("normalizes hyphenated mega card names", () => {
    expect(normalizePokewalletQuery("Mega-Gengar ex")).toBe("mega gengar ex");
  });

  it("normalizes multiple unicode dashes", () => {
    expect(normalizePokewalletQuery("Mega—Gengar‑ex")).toBe("mega gengar ex");
  });

  it("removes punctuation but keeps slashes", () => {
    expect(normalizePokewalletQuery("Mewtwo, ex! 12/165 (JP)")).toBe("mewtwo ex 12/165 jp");
  });

  it("compresses whitespace", () => {
    expect(normalizePokewalletQuery("  mega   gengar\t\nex  ")).toBe("mega gengar ex");
  });
});
