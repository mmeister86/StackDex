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
  };
};

export async function lookupHandler(
  deps: {
    fetchCards: (args: PokewalletLookupArgs) => Promise<CardCandidate[]>;
  },
  args: LookupArgs,
) {
  assertCardsLookupSchemaVersion(args.responseSchemaVersion);

  const candidates = await deps.fetchCards({
    recognizedTexts: args.recognizedTexts,
    query: args.query,
    maxResults: args.maxResults,
    hints: args.hints,
  });

  return buildCardsLookupEnvelope(candidates);
}

export const lookup = actionGeneric({
  args: lookupArgsValidator,
  handler: async (ctx, args) => {
    return lookupHandler(
      {
        fetchCards: async (lookupArgs) => {
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
