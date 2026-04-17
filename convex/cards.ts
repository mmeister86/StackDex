import { actionGeneric } from "convex/server";
import { v } from "convex/values";

import {
  assertCardsLookupSchemaVersion,
  buildCardsLookupEnvelope,
  type CardCandidate,
} from "./lib/cardsLookupContract";
import type { PokewalletLookupArgs } from "./lib/pokewalletTypes";

const signalQualityValidator = v.optional(
  v.object({
    isWeakNameSignal: v.optional(v.boolean()),
    hasCollectorNumberSignal: v.optional(v.boolean()),
    hasSuspiciousSetCodes: v.optional(v.boolean()),
  }),
);

const hintsValidator = v.optional(
  v.object({
    normalizedQuery: v.optional(v.string()),
    nameTokens: v.optional(v.array(v.string())),
    possibleNumbers: v.optional(v.array(v.string())),
    possibleSetCodes: v.optional(v.array(v.string())),
    possibleRarities: v.optional(v.array(v.string())),
    possibleLanguages: v.optional(v.array(v.string())),
    signalQuality: signalQualityValidator,
  }),
);

export const lookupArgsValidator = {
  recognizedTexts: v.array(v.string()),
  query: v.string(),
  maxResults: v.number(),
  responseSchemaVersion: v.string(),
  hints: hintsValidator,
};

export type LookupArgs = {
  recognizedTexts: string[];
  query: string;
  maxResults: number;
  responseSchemaVersion: string;
  hints?: {
    normalizedQuery?: string;
    nameTokens?: string[];
    possibleNumbers?: string[];
    possibleSetCodes?: string[];
    possibleRarities?: string[];
    possibleLanguages?: string[];
    signalQuality?: {
      isWeakNameSignal?: boolean;
      hasCollectorNumberSignal?: boolean;
      hasSuspiciousSetCodes?: boolean;
    };
  };
};

function shouldApplyNumberGuard(args: LookupArgs): boolean {
  return !!(
    args.hints?.signalQuality?.isWeakNameSignal &&
    args.hints?.signalQuality?.hasCollectorNumberSignal
  );
}

function normalizeCollectorNumber(raw: string): string {
  const split = raw
    .trim()
    .toUpperCase()
    .split("/")
    .at(0);

  if (!split) {
    return "";
  }

  return split.replace(/^0+(?=\d)/g, "");
}

function extractTargetCollectorNumber(args: LookupArgs): string | null {
  const numberHint = args.hints?.possibleNumbers?.find((entry) => entry.includes("/"));
  if (!numberHint) {
    return null;
  }
  return normalizeCollectorNumber(numberHint);
}

function normalizeCandidateNumber(raw: string | undefined | null): string | null {
  if (!raw) {
    return null;
  }
  return normalizeCollectorNumber(raw);
}

function applyNumberGuard(candidates: CardCandidate[], args: LookupArgs): CardCandidate[] {
  if (!shouldApplyNumberGuard(args)) {
    return candidates;
  }

  const targetNumber = extractTargetCollectorNumber(args);
  if (!targetNumber) {
    return candidates;
  }

  return candidates.filter((candidate) => normalizeCandidateNumber(candidate.number) === targetNumber);
}

export async function lookupHandler(
  deps: {
    fetchPrimaryCards: (args: PokewalletLookupArgs) => Promise<CardCandidate[]>;
    fetchFallbackCards: (args: PokewalletLookupArgs) => Promise<CardCandidate[]>;
  },
  args: LookupArgs,
) {
  assertCardsLookupSchemaVersion(args.responseSchemaVersion);

  const lookupArgs = {
    recognizedTexts: args.recognizedTexts,
    query: args.query,
    maxResults: args.maxResults,
    hints: args.hints,
  };

  try {
    const primaryCandidates = applyNumberGuard(await deps.fetchPrimaryCards(lookupArgs), args);
    if (primaryCandidates.length > 0) {
      return buildCardsLookupEnvelope(primaryCandidates);
    }
  } catch {
    // Intentionally ignored so we can fall back to the secondary provider.
  }

  const fallbackCandidates = applyNumberGuard(await deps.fetchFallbackCards(lookupArgs), args);

  return buildCardsLookupEnvelope(fallbackCandidates);
}

export const lookup = actionGeneric({
  args: lookupArgsValidator,
  handler: async (ctx, args) => {
    return lookupHandler(
      {
        fetchPrimaryCards: async (lookupArgs) => {
          return (ctx.runAction as unknown as (path: string, actionArgs: PokewalletLookupArgs) => Promise<CardCandidate[]>)(
            "tcgdex:fetchCards",
            lookupArgs,
          );
        },
        fetchFallbackCards: async (lookupArgs) => {
          return (ctx.runAction as unknown as (path: string, actionArgs: PokewalletLookupArgs) => Promise<CardCandidate[]>)(
            "pokewallet:fetchCards",
            lookupArgs,
          );
        },
      },
      args,
    );
  },
});
