import { describe, expect, it } from "vitest";

import {
  CARDS_LOOKUP_SCHEMA_VERSION,
  SUPPORTED_CONDITION_KEYS,
  assertCardsLookupSchemaVersion,
  buildCardsLookupEnvelope,
  makeCardsLookupV1Response,
} from "./cardsLookupContract";

describe("cards lookup contract", () => {
  it("accepts exact schema version", () => {
    expect(() => {
      assertCardsLookupSchemaVersion(CARDS_LOOKUP_SCHEMA_VERSION);
    }).not.toThrow();
  });

  it("rejects unsupported schema version", () => {
    expect(() => {
      assertCardsLookupSchemaVersion("cards.lookup.v2");
    }).toThrowError(
      "Unsupported responseSchemaVersion \"cards.lookup.v2\". Supported version: cards.lookup.v1",
    );
  });

  it("returns envelope with payload candidates", () => {
    const envelope = buildCardsLookupEnvelope([
      {
        id: "base1-4",
        name: "Charizard",
        number: "4/102",
        imageUrl: "https://example.com/card.png",
        rarity: "Holo Rare",
        setCode: "base1",
        prices: {
          market: 349.99,
          conditions: {
            near_mint: "349.99",
          },
        },
      },
    ]);

    expect(envelope).toEqual({
      schemaVersion: "cards.lookup.v1",
      payload: {
        candidates: [
          {
            id: "base1-4",
            name: "Charizard",
            number: "4/102",
            imageUrl: "https://example.com/card.png",
            rarity: "Holo Rare",
            setCode: "base1",
            prices: {
              market: 349.99,
              conditions: {
                near_mint: "349.99",
              },
            },
          },
        ],
      },
    });
  });

  it("keeps backwards-compatible helper alias", () => {
    const candidates: [] = [];
    expect(makeCardsLookupV1Response(candidates)).toEqual(buildCardsLookupEnvelope(candidates));
  });

  it("keeps condition keys constrained to allowed values", () => {
    expect(SUPPORTED_CONDITION_KEYS).toEqual([
      "mint",
      "near_mint",
      "lightly_played",
      "moderately_played",
      "heavily_played",
      "damaged",
    ]);
  });
});
