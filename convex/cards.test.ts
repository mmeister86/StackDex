import { describe, expect, it, vi } from "vitest";

import { CARDS_LOOKUP_SCHEMA_VERSION } from "./lib/cardsLookupContract";
import { lookupHandler } from "./cards";

describe("cards.lookup action handler", () => {
  it("loads convex-test package for future action integration tests", async () => {
    const mod = await import("convex-test");
    expect(mod).toBeTruthy();
  });

  it("enforces strict response schema version negotiation", async () => {
    const fetchPrimaryCards = vi.fn();
    const fetchFallbackCards = vi.fn();

    await expect(
      lookupHandler(
        {
          fetchPrimaryCards,
          fetchFallbackCards,
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

    expect(fetchPrimaryCards).not.toHaveBeenCalled();
    expect(fetchFallbackCards).not.toHaveBeenCalled();
  });

  it("returns versioned envelope with empty candidates when both providers return nothing", async () => {
    const fetchPrimaryCards = vi.fn().mockResolvedValue([]);
    const fetchFallbackCards = vi.fn().mockResolvedValue([]);

    const result = await lookupHandler(
      {
        fetchPrimaryCards,
        fetchFallbackCards,
      },
      {
        query: "no results",
        recognizedTexts: ["none"],
        maxResults: 5,
        responseSchemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
      },
    );

    expect(fetchPrimaryCards).toHaveBeenCalledTimes(1);
    expect(fetchFallbackCards).toHaveBeenCalledTimes(1);
    expect(result).toEqual({
      schemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
      payload: {
        candidates: [],
      },
    });
  });

  it("forwards hints and lookup args to primary backend", async () => {
    const fetchPrimaryCards = vi.fn().mockResolvedValue([
      {
        id: "base1-4",
        name: "Charizard",
        prices: {
          market: 1,
          conditions: {},
        },
      },
    ]);
    const fetchFallbackCards = vi.fn();

    await lookupHandler(
      {
        fetchPrimaryCards,
        fetchFallbackCards,
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

    expect(fetchPrimaryCards).toHaveBeenCalledWith({
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
    expect(fetchFallbackCards).not.toHaveBeenCalled();
  });

  it("uses fallback backend when primary result is empty", async () => {
    const fetchPrimaryCards = vi.fn().mockResolvedValue([]);
    const fetchFallbackCards = vi.fn().mockResolvedValue([
      {
        id: "base1-25",
        name: "Pikachu",
        prices: {
          market: 9,
          conditions: {},
        },
      },
    ]);

    const result = await lookupHandler(
      {
        fetchPrimaryCards,
        fetchFallbackCards,
      },
      {
        query: "pikachu",
        recognizedTexts: ["pikachu"],
        maxResults: 3,
        responseSchemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
      },
    );

    expect(fetchPrimaryCards).toHaveBeenCalledTimes(1);
    expect(fetchFallbackCards).toHaveBeenCalledTimes(1);
    expect(result.payload.candidates).toEqual([
      {
        id: "base1-25",
        name: "Pikachu",
        prices: {
          market: 9,
          conditions: {},
        },
      },
    ]);
  });

  it("uses fallback backend when primary provider throws", async () => {
    const fetchPrimaryCards = vi.fn().mockRejectedValue(new Error("primary unavailable"));
    const fetchFallbackCards = vi.fn().mockResolvedValue([
      {
        id: "base1-6",
        name: "Ninetales",
        prices: {
          market: 2,
          conditions: {},
        },
      },
    ]);

    const result = await lookupHandler(
      {
        fetchPrimaryCards,
        fetchFallbackCards,
      },
      {
        query: "ninetales",
        recognizedTexts: ["ninetales"],
        maxResults: 3,
        responseSchemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
      },
    );

    expect(fetchPrimaryCards).toHaveBeenCalledTimes(1);
    expect(fetchFallbackCards).toHaveBeenCalledTimes(1);
    expect(result.payload.candidates[0]?.id).toBe("base1-6");
  });
});
