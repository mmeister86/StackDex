import { actionGeneric } from "convex/server";
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
    possibleSetCodes: v.optional(v.array(v.string())),
    possibleRarities: v.optional(v.array(v.string())),
    possibleLanguages: v.optional(v.array(v.string())),
  }),
);

const fetchCardsArgsValidator = {
  recognizedTexts: v.array(v.string()),
  query: v.string(),
  maxResults: v.number(),
  hints: hintsValidator,
};

function pickLookupQuery(args: PokewalletLookupArgs): string | null {
  const candidateQueries = [
    args.query,
    args.hints?.normalizedQuery,
    args.recognizedTexts.join(" "),
  ];

  for (const rawQuery of candidateQueries) {
    const query = rawQuery?.trim();
    if (query) {
      return query;
    }
  }

  return null;
}

export async function fetchPokewalletCandidates(args: PokewalletLookupArgs): Promise<CardCandidate[]> {
  const apiKey = process.env.POKEWALLET_API_KEY;
  if (!apiKey) {
    throw new MissingPokewalletApiKeyError();
  }

  const query = pickLookupQuery(args);
  if (!query) {
    return [];
  }

  const baseUrl = process.env.POKEWALLET_BASE_URL ?? "https://api.pokewallet.io";
  const endpoint = new URL("/search", baseUrl);
  endpoint.searchParams.set("q", query);
  endpoint.searchParams.set("limit", String(Math.min(Math.max(Math.round(args.maxResults), 1), 100)));

  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "X-API-Key": apiKey,
      },
    });
  } catch (cause) {
    throw new PokewalletUpstreamError("Pokewallet upstream request failed before receiving a response.", {
      cause,
    });
  }

  if (!response.ok) {
    const upstreamMessage = await response.text().catch(() => "");
    throw new PokewalletUpstreamError(`Pokewallet upstream request failed with status ${response.status}.`, {
      status: response.status,
      cause: upstreamMessage ? new Error(upstreamMessage) : undefined,
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

export const fetchCards = actionGeneric({
  args: fetchCardsArgsValidator,
  handler: async (_ctx, args) => {
    return fetchPokewalletCandidates(args);
  },
});
