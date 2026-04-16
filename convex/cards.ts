import { actionGeneric } from "convex/server";
import { v } from "convex/values";

import {
  assertCardsLookupSchemaVersion,
  buildCardsLookupEnvelope,
  type CardCandidate,
} from "./lib/cardsLookupContract";
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
  };
};

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
    const primaryCandidates = await deps.fetchPrimaryCards(lookupArgs);
    if (primaryCandidates.length > 0) {
      return buildCardsLookupEnvelope(primaryCandidates);
    }
  } catch {
    // Intentionally ignored so we can fall back to the secondary provider.
  }

  const fallbackCandidates = await deps.fetchFallbackCards(lookupArgs);

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
