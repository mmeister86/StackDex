import { describe, expect, it, vi } from "vitest";

import { CARDS_LOOKUP_SCHEMA_VERSION } from "./lib/cardsLookupContract";
import { lookupHandler } from "./cards";

describe("cards.lookup action handler", () => {
  it("loads convex-test package for future action integration tests", async () => {
    const mod = await import("convex-test");
    expect(mod).toBeTruthy();
  });

  it("enforces strict response schema version negotiation", async () => {
    const fetchCards = vi.fn();

    await expect(
      lookupHandler(
        {
          fetchCards,
        },
        {
          query: "charizard",
          recognizedTexts: ["charizard"],
          maxResults: 5,
          responseSchemaVersion: "cards.lookup.v2",
        },
      ),
    ).rejects.toThrowError(
      "Unsupported responseSchemaVersion \"cards.lookup.v2\". Supported version: cards.lookup.v1",
    );

    expect(fetchCards).not.toHaveBeenCalled();
  });

  it("returns versioned envelope with empty candidates", async () => {
    const fetchCards = vi.fn().mockResolvedValue([]);

    const result = await lookupHandler(
      {
        fetchCards,
      },
      {
        query: "no results",
        recognizedTexts: ["none"],
        maxResults: 5,
        responseSchemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
      },
    );

    expect(result).toEqual({
      schemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
      payload: {
        candidates: [],
      },
    });
  });

  it("forwards hints and lookup args to backend internals", async () => {
    const fetchCards = vi.fn().mockResolvedValue([]);

    await lookupHandler(
      {
        fetchCards,
      },
      {
        query: "charizard 4/102",
        recognizedTexts: ["charizard", "4/102"],
        maxResults: 5,
        responseSchemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
        hints: {
          normalizedQuery: "charizard 4/102",
          nameTokens: ["charizard"],
          possibleNumbers: ["4/102"],
          possibleSetCodes: ["base1"],
          possibleRarities: ["Holo Rare"],
          possibleLanguages: ["EN"],
        },
      },
    );

    expect(fetchCards).toHaveBeenCalledWith({
      query: "charizard 4/102",
      recognizedTexts: ["charizard", "4/102"],
      maxResults: 5,
      hints: {
        normalizedQuery: "charizard 4/102",
        nameTokens: ["charizard"],
        possibleNumbers: ["4/102"],
        possibleSetCodes: ["base1"],
        possibleRarities: ["Holo Rare"],
        possibleLanguages: ["EN"],
      },
    });
  });
});
