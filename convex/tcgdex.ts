import { actionGeneric } from "convex/server";
import { v } from "convex/values";

import type { CardCandidate } from "./lib/cardsLookupContract";
import { normalizePokewalletQuery } from "./lib/pokewalletQueryNormalizer";
import { TcgdexUpstreamError } from "./lib/tcgdexErrors";
import { normalizeTcgdexCardResponse, normalizeTcgdexCardsResponse } from "./lib/tcgdexNormalizer";
import type { TcgdexLookupArgs } from "./lib/tcgdexTypes";

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

function pickLookupQuery(args: TcgdexLookupArgs): string | null {
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

function buildLookupQueries(args: TcgdexLookupArgs): string[] {
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

function parseLanguageCode(input: string | undefined): string | null {
  const normalized = input?.trim().toLowerCase().replace(/_/g, "-");
  if (!normalized) {
    return null;
  }

  if (normalized === "jp") {
    return "ja";
  }

  if (/^[a-z]{2}(?:-[a-z]{2})?$/.test(normalized)) {
    return normalized;
  }

  return null;
}

function resolveLanguage(args: TcgdexLookupArgs): string {
  const hintedLanguage = args.hints?.possibleLanguages?.find((entry) => parseLanguageCode(entry) !== null);

  return (
    parseLanguageCode(process.env.TCGDEX_LANGUAGE) ??
    parseLanguageCode(hintedLanguage) ??
    "en"
  );
}

function buildLanguageFallbackChain(args: TcgdexLookupArgs): string[] {
  const chain: string[] = [];
  const seen = new Set<string>();

  const appendLanguage = (value: string | null) => {
    if (!value || seen.has(value)) {
      return;
    }
    seen.add(value);
    chain.push(value);
  };

  appendLanguage(resolveLanguage(args));
  appendLanguage("en");

  return chain;
}

async function requestJSON(endpoint: URL): Promise<unknown> {
  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
    });
  } catch (cause) {
    throw new TcgdexUpstreamError("TCGdex upstream request failed before receiving a response.", {
      cause,
    });
  }

  if (!response.ok) {
    const upstreamMessage = await response.text().catch(() => "");
    throw new TcgdexUpstreamError(`TCGdex upstream request failed with status ${response.status}.`, {
      status: response.status,
      cause: upstreamMessage ? new Error(upstreamMessage) : undefined,
    });
  }

  try {
    return await response.json();
  } catch (cause) {
    throw new TcgdexUpstreamError("TCGdex upstream returned non-JSON response.", {
      status: response.status,
      cause,
    });
  }
}

async function fetchCardDetail(
  cardId: string,
  language: string,
  baseUrl: string,
): Promise<CardCandidate | null> {
  const endpoint = new URL(`/v2/${language}/cards/${encodeURIComponent(cardId)}`, baseUrl);
  const body = await requestJSON(endpoint);
  return normalizeTcgdexCardResponse(body);
}

function deduplicateCandidates(candidates: CardCandidate[]): CardCandidate[] {
  const seen = new Set<string>();
  const deduplicated: CardCandidate[] = [];

  for (const candidate of candidates) {
    if (seen.has(candidate.id)) {
      continue;
    }
    seen.add(candidate.id);
    deduplicated.push(candidate);
  }

  return deduplicated;
}

async function enrichCandidatesWithDetails(
  candidates: CardCandidate[],
  language: string,
  baseUrl: string,
  maxResults: number,
): Promise<CardCandidate[]> {
  const base = candidates.slice(0, maxResults);
  const detailed = await Promise.all(
    base.map(async (candidate) => {
      try {
        return (await fetchCardDetail(candidate.id, language, baseUrl)) ?? candidate;
      } catch {
        return candidate;
      }
    }),
  );

  return deduplicateCandidates(detailed).slice(0, maxResults);
}

export async function fetchTcgdexCandidates(args: TcgdexLookupArgs): Promise<CardCandidate[]> {
  const queries = buildLookupQueries(args);
  if (queries.length === 0) {
    return [];
  }

  const baseUrl = process.env.TCGDEX_BASE_URL ?? "https://api.tcgdex.net";
  const languages = buildLanguageFallbackChain(args);
  const maxResults = Math.min(Math.max(Math.round(args.maxResults), 1), 20);
  let lastUpstreamError: TcgdexUpstreamError | null = null;

  for (const query of queries) {
    for (const language of languages) {
      const endpoint = new URL(`/v2/${language}/cards`, baseUrl);
      endpoint.searchParams.set("name", query);

      let listCandidates: CardCandidate[];
      try {
        const body = await requestJSON(endpoint);
        listCandidates = normalizeTcgdexCardsResponse(body);
      } catch (error) {
        if (error instanceof TcgdexUpstreamError) {
          lastUpstreamError = error;
          continue;
        }
        throw error;
      }

      if (listCandidates.length === 0) {
        continue;
      }

      const enrichedCandidates = await enrichCandidatesWithDetails(listCandidates, language, baseUrl, maxResults);
      if (enrichedCandidates.length > 0) {
        return enrichedCandidates;
      }
    }
  }

  if (lastUpstreamError) {
    throw lastUpstreamError;
  }

  return [];
}

export const fetchCards = actionGeneric({
  args: fetchCardsArgsValidator,
  handler: async (_ctx, args) => {
    return fetchTcgdexCandidates(args);
  },
});
