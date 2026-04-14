import {
  SUPPORTED_CONDITION_KEYS,
  type CardCandidate,
  type CardConditionKey,
  type PriceValue,
} from "./cardsLookupContract";
import type { PokewalletCardLike, PokewalletLookupResponse } from "./pokewalletTypes";

const CONDITION_ALIASES: Record<string, CardConditionKey> = {
  mint: "mint",
  nearmint: "near_mint",
  near_mint: "near_mint",
  nm: "near_mint",
  lightlyplayed: "lightly_played",
  lightly_played: "lightly_played",
  lp: "lightly_played",
  moderatelyplayed: "moderately_played",
  moderately_played: "moderately_played",
  mp: "moderately_played",
  heavilyplayed: "heavily_played",
  heavily_played: "heavily_played",
  hp: "heavily_played",
  damaged: "damaged",
  dmg: "damaged",
};

function toRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

function toStringField(value: unknown): string | null {
  if (typeof value === "string" && value.trim().length > 0) {
    return value;
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }

  return null;
}

function pickFirstStringField(...values: unknown[]): string | null {
  for (const value of values) {
    const normalized = toStringField(value);
    if (normalized) {
      return normalized;
    }
  }

  return null;
}

function toPriceValue(value: unknown): PriceValue | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string" && value.trim().length > 0) {
    return value;
  }

  return null;
}

function normalizeConditionKey(input: string): CardConditionKey | null {
  const canonical = input.trim().toLowerCase().replace(/[\s-]+/g, "_").replace(/[^a-z_]/g, "");
  const mapped = CONDITION_ALIASES[canonical] ?? CONDITION_ALIASES[canonical.replace(/_/g, "")];

  if (mapped) {
    return mapped;
  }

  if ((SUPPORTED_CONDITION_KEYS as readonly string[]).includes(canonical)) {
    return canonical as CardConditionKey;
  }

  return null;
}

function extractCards(response: unknown): PokewalletCardLike[] {
  const record = toRecord(response) as PokewalletLookupResponse | null;
  if (!record) {
    return [];
  }

  if (Array.isArray(record.results)) {
    return record.results;
  }

  if (Array.isArray(record.cards)) {
    return record.cards;
  }

  if (Array.isArray(record.data)) {
    return record.data;
  }

  return [];
}

function normalizeCard(card: PokewalletCardLike): CardCandidate | null {
  const cardRecord = toRecord(card) ?? {};
  const setRecord = toRecord(cardRecord.set) ?? {};
  const imageRecord = toRecord(cardRecord.image) ?? {};

  const id = pickFirstStringField(card.id, cardRecord.cardId, cardRecord.card_id);
  const name = pickFirstStringField(card.name, cardRecord.cardName, cardRecord.card_name, cardRecord.title);
  const number = pickFirstStringField(card.number, cardRecord.no, cardRecord.cardNumber, cardRecord.card_number);
  const imageUrl = pickFirstStringField(
    card.imageUrl,
    card.image_url,
    card.image,
    imageRecord.url,
    imageRecord.small,
    imageRecord.large,
  );
  const rarity = pickFirstStringField(card.rarity, cardRecord.rarityLabel, cardRecord.rarity_label);
  const setCode = pickFirstStringField(card.setCode, card.set_code, setRecord.code, setRecord.id, setRecord.setCode);

  if (!id || !name || !number || !imageUrl || !rarity || !setCode) {
    return null;
  }

  const prices = toRecord(card.prices);
  const conditionSource =
    toRecord(prices?.conditions) ??
    toRecord(card.conditionPrices) ??
    toRecord(cardRecord.conditions) ??
    toRecord(cardRecord.condition_prices) ??
    {};
  const conditions: Partial<Record<CardConditionKey, PriceValue>> = {};

  for (const [key, raw] of Object.entries(conditionSource)) {
    const normalizedKey = normalizeConditionKey(key);
    const value = toPriceValue(raw);
    if (normalizedKey && value !== null) {
      conditions[normalizedKey] = value;
    }
  }

  const market = toPriceValue(prices?.market ?? card.market) ?? 0;

  return {
    id,
    name,
    number,
    imageUrl,
    rarity,
    setCode,
    prices: {
      market,
      conditions,
    },
  };
}

export function normalizePokewalletLookupResponse(response: unknown): CardCandidate[] {
  return extractCards(response)
    .map((card) => normalizeCard(card))
    .filter((card): card is CardCandidate => card !== null);
}
