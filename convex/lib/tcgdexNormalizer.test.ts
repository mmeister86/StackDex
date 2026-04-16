import { describe, expect, it } from "vitest";

import { normalizeTcgdexCardResponse, normalizeTcgdexCardsResponse } from "./tcgdexNormalizer";

describe("tcgdex normalizer", () => {
  it("normalizes card list payload to lookup candidates", () => {
    const candidates = normalizeTcgdexCardsResponse([
      {
        id: "swsh3-136",
        localId: "136",
        name: "Furret",
        image: "https://assets.tcgdex.net/en/swsh/swsh3/136",
        rarity: "Uncommon",
        set: {
          id: "swsh3",
        },
      },
    ]);

    expect(candidates).toEqual([
      {
        id: "swsh3-136",
        number: "136",
        name: "Furret",
        imageUrl: "https://assets.tcgdex.net/en/swsh/swsh3/136",
        rarity: "Uncommon",
        setCode: "swsh3",
        prices: {
          market: 0,
          conditions: {},
        },
      },
    ]);
  });

  it("extracts market from tcgplayer pricing", () => {
    const candidate = normalizeTcgdexCardResponse({
      id: "swsh3-136",
      localId: "136",
      name: "Furret",
      rarity: "Uncommon",
      pricing: {
        tcgplayer: {
          normal: {
            marketPrice: 0.09,
          },
        },
      },
    });

    expect(candidate).toEqual({
      id: "swsh3-136",
      number: "136",
      name: "Furret",
      rarity: "Uncommon",
      prices: {
        market: 0.09,
        conditions: {},
      },
    });
  });

  it("falls back to cardmarket pricing when tcgplayer data is missing", () => {
    const candidate = normalizeTcgdexCardResponse({
      id: "xy7-54",
      localId: "54",
      name: "Gardevoir",
      pricing: {
        cardmarket: {
          trend: 4.5,
        },
      },
    });

    expect(candidate).toEqual({
      id: "xy7-54",
      number: "54",
      name: "Gardevoir",
      prices: {
        market: 4.5,
        conditions: {},
      },
    });
  });

  it("returns null/empty for malformed payloads", () => {
    expect(normalizeTcgdexCardsResponse({ cards: [] })).toEqual([]);
    expect(normalizeTcgdexCardResponse({ name: "Missing id" })).toBeNull();
  });
});
