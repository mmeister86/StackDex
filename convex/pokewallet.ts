import { internalAction } from "convex/server";
import { v } from "convex/values";

import type { CardCandidate } from "./lib/cardsLookupContract";
import { MissingPokewalletApiKeyError, PokewalletUpstreamError } from "./lib/pokewalletErrors";
import { normalizePokewalletLookupResponse } from "./lib/pokewalletNormalizer";
import type { PokewalletLookupArgs } from "./lib/pokewalletTypes";

const hintsValidator = v.optional(
  v.object({
    normalizedQuery: v.optional(v.string()),
    nameTokens: v.optional(v.array(v.string())),
    possibleNumbers: v.optional(v.array(v.string())),
  }),
);

const fetchCardsArgsValidator = {
  recognizedTexts: v.array(v.string()),
  query: v.string(),
  maxResults: v.number(),
  hints: hintsValidator,
};

export async function fetchPokewalletCandidates(args: PokewalletLookupArgs): Promise<CardCandidate[]> {
  const apiKey = process.env.POKEWALLET_API_KEY;
  if (!apiKey) {
    throw new MissingPokewalletApiKeyError();
  }

  const baseUrl = process.env.POKEWALLET_BASE_URL ?? "https://api.pokewallet.example";

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/v1/cards/lookup`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(args),
    });
  } catch (cause) {
    throw new PokewalletUpstreamError("Pokewallet upstream request failed before receiving a response.", {
      cause,
    });
  }

  if (!response.ok) {
    throw new PokewalletUpstreamError(`Pokewallet upstream request failed with status ${response.status}.`, {
      status: response.status,
    });
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch (cause) {
    throw new PokewalletUpstreamError("Pokewallet upstream returned non-JSON response.", {
      status: response.status,
      cause,
    });
  }

  return normalizePokewalletLookupResponse(body);
}

export const fetchCards = internalAction({
  args: fetchCardsArgsValidator,
  handler: async (_ctx, args) => {
    return fetchPokewalletCandidates(args);
  },
});
