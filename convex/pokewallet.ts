import { actionGeneric } from "convex/server";
import { v } from "convex/values";

import type { CardCandidate } from "./lib/cardsLookupContract";
import { MissingPokewalletApiKeyError, PokewalletUpstreamError } from "./lib/pokewalletErrors";
import { normalizePokewalletLookupResponse } from "./lib/pokewalletNormalizer";
import { normalizePokewalletQuery } from "./lib/pokewalletQueryNormalizer";
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

function buildLookupQueries(args: PokewalletLookupArgs): string[] {
  const lookupQuery = pickLookupQuery(args);
  if (!lookupQuery) {
    return [];
  }

  const queries: string[] = [];
  const seen = new Set<string>();

  const appendQuery = (value: string) => {
    const query = value.trim();
    if (!query || seen.has(query)) {
      return;
    }
    seen.add(query);
    queries.push(query);
  };

  appendQuery(lookupQuery);
  appendQuery(normalizePokewalletQuery(lookupQuery));

  return queries;
}

export async function fetchPokewalletCandidates(args: PokewalletLookupArgs): Promise<CardCandidate[]> {
  const apiKey = process.env.POKEWALLET_API_KEY;
  if (!apiKey) {
    throw new MissingPokewalletApiKeyError();
  }

  const queries = buildLookupQueries(args);
  if (queries.length === 0) {
    return [];
  }

  const baseUrl = process.env.POKEWALLET_BASE_URL ?? "https://api.pokewallet.io";
  const limit = String(Math.min(Math.max(Math.round(args.maxResults), 1), 100));

  for (const query of queries) {
    const endpoint = new URL("/search", baseUrl);
    endpoint.searchParams.set("q", query);
    endpoint.searchParams.set("limit", limit);

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

    const candidates = normalizePokewalletLookupResponse(body);
    if (candidates.length > 0) {
      return candidates;
    }
  }

  return [];
}

export const fetchCards = actionGeneric({
  args: fetchCardsArgsValidator,
  handler: async (_ctx, args) => {
    return fetchPokewalletCandidates(args);
  },
});
