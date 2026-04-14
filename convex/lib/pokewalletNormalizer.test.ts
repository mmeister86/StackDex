import { describe, expect, it } from "vitest";

import { normalizePokewalletLookupResponse } from "./pokewalletNormalizer";

describe("pokewallet normalizer", () => {
  it("normalizes market and allowed condition keys", () => {
    const candidates = normalizePokewalletLookupResponse({
      results: [
        {
          id: "base1-4",
          name: "Charizard",
          number: "4/102",
          image_url: "https://example.com/card.png",
          rarity: "Holo Rare",
          set_code: "base1",
          prices: {
            market: "349.99",
            conditions: {
              NearMint: 340,
              lightlyPlayed: "280.5",
              hp: 100,
              "Moderately Played": "220.00",
            },
          },
        },
      ],
    });

    expect(candidates).toEqual([
      {
        id: "base1-4",
        name: "Charizard",
        number: "4/102",
        imageUrl: "https://example.com/card.png",
        rarity: "Holo Rare",
        setCode: "base1",
        prices: {
          market: "349.99",
          conditions: {
            near_mint: 340,
            lightly_played: "280.5",
            moderately_played: "220.00",
            heavily_played: 100,
          },
        },
      },
    ]);
  });

  it("maps alternate provider fields to parser-compatible candidate fields", () => {
    const candidates = normalizePokewalletLookupResponse({
      data: [
        {
          card_id: "xy7-54",
          card_name: "Gardevoir",
          card_number: "54/98",
          image: {
            small: "https://example.com/gardevoir-small.png",
          },
          rarity_label: "Rare Holo",
          set: {
            code: "xy7",
          },
          market: 52.25,
          condition_prices: {
            "Near-Mint": "51.00",
            dmg: 9,
          },
        },
      ],
    });

    expect(candidates).toEqual([
      {
        id: "xy7-54",
        name: "Gardevoir",
        number: "54/98",
        imageUrl: "https://example.com/gardevoir-small.png",
        rarity: "Rare Holo",
        setCode: "xy7",
        prices: {
          market: 52.25,
          conditions: {
            near_mint: "51.00",
            damaged: 9,
          },
        },
      },
    ]);
  });

  it("supports cards list and defaults prices", () => {
    const candidates = normalizePokewalletLookupResponse({
      cards: [
        {
          id: 25,
          name: "Pikachu",
          number: 58,
          imageUrl: "https://example.com/pika.png",
          rarity: "Common",
          setCode: "base1",
        },
      ],
    });

    expect(candidates).toEqual([
      {
        id: "25",
        name: "Pikachu",
        number: "58",
        imageUrl: "https://example.com/pika.png",
        rarity: "Common",
        setCode: "base1",
        prices: {
          market: 0,
          conditions: {},
        },
      },
    ]);
  });

  it("returns empty array for malformed payload", () => {
    expect(normalizePokewalletLookupResponse({ invalid: true })).toEqual([]);
    expect(normalizePokewalletLookupResponse(null)).toEqual([]);
  });

  it("drops malformed candidates", () => {
    const candidates = normalizePokewalletLookupResponse({
      results: [
        { id: "missing-fields" },
        {
          id: "ok",
          name: "Bulbasaur",
          number: "1/102",
          imageUrl: "https://example.com/bulba.png",
          rarity: "Common",
          setCode: "base1",
          prices: {
            market: 12.5,
            conditions: {
              mint: 20,
              foo: 5,
            },
          },
        },
      ],
    });

    expect(candidates).toEqual([
      {
        id: "ok",
        name: "Bulbasaur",
        number: "1/102",
        imageUrl: "https://example.com/bulba.png",
        rarity: "Common",
        setCode: "base1",
        prices: {
          market: 12.5,
          conditions: {
            mint: 20,
          },
        },
      },
    ]);
  });
});
