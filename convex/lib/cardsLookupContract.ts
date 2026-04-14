export const CARDS_LOOKUP_SCHEMA_VERSION = "cards.lookup.v1" as const;

export const SUPPORTED_CONDITION_KEYS = [
  "mint",
  "near_mint",
  "lightly_played",
  "moderately_played",
  "heavily_played",
  "damaged",
] as const;

export type CardConditionKey = (typeof SUPPORTED_CONDITION_KEYS)[number];
export type PriceValue = number | string;

export type CardCandidate = {
  id: string;
  name: string;
  number: string;
  imageUrl: string;
  rarity: string;
  setCode: string;
  prices: {
    market: PriceValue;
    conditions: Partial<Record<CardConditionKey, PriceValue>>;
  };
};

export type CardsLookupEnvelope = {
  schemaVersion: typeof CARDS_LOOKUP_SCHEMA_VERSION;
  payload: {
    candidates: CardCandidate[];
  };
};

export function assertCardsLookupSchemaVersion(version: string): asserts version is typeof CARDS_LOOKUP_SCHEMA_VERSION {
  if (version !== CARDS_LOOKUP_SCHEMA_VERSION) {
    throw new Error(
      `Unsupported responseSchemaVersion "${version}". Supported version: ${CARDS_LOOKUP_SCHEMA_VERSION}`,
    );
  }
}

export function buildCardsLookupEnvelope(candidates: CardCandidate[]): CardsLookupEnvelope {
  return {
    schemaVersion: CARDS_LOOKUP_SCHEMA_VERSION,
    payload: {
      candidates,
    },
  };
}

export const makeCardsLookupV1Response = buildCardsLookupEnvelope;
