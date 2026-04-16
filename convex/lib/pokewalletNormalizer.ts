import {
  SUPPORTED_CONDITION_KEYS,
  type CardCandidate,
  type CardConditionKey,
  type PriceValue,
} from "./cardsLookupContract";
import type { PokewalletCardLike, PokewalletLookupResponse, PokewalletProviderPrice } from "./pokewalletTypes";

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
  if (Array.isArray(response)) {
    return response as PokewalletCardLike[];
  }

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

function extractProviderPrices(value: unknown): PokewalletProviderPrice[] {
  const record = toRecord(value);
  if (!record || !Array.isArray(record.prices)) {
    return [];
  }

  return record.prices.filter((entry) => toRecord(entry) !== null) as PokewalletProviderPrice[];
}

function pickMarketFromProviderPrices(cardRecord: Record<string, unknown>): PriceValue | null {
  const providerPrices = [...extractProviderPrices(cardRecord.tcgplayer), ...extractProviderPrices(cardRecord.cardmarket)];

  for (const price of providerPrices) {
    const providerPriceRecord = toRecord(price) ?? {};
    const candidate = toPriceValue(
      price.market_price ??
        price.mid_price ??
        providerPriceRecord.low ??
        price.low_price ??
        price.avg ??
        price.avg30 ??
        price.trend,
    );

    if (candidate !== null) {
      return candidate;
    }
  }

  return null;
}

function normalizeCard(card: PokewalletCardLike): CardCandidate | null {
  const cardRecord = toRecord(card) ?? {};
  const cardInfo = toRecord(cardRecord.card_info) ?? toRecord(cardRecord.cardInfo) ?? {};
  const setRecord = toRecord(cardRecord.set) ?? {};
  const imageRecord = toRecord(cardRecord.image) ?? toRecord(cardInfo.image) ?? {};

  const id = pickFirstStringField(card.id, cardRecord.cardId, cardRecord.card_id, cardInfo.id, cardInfo.card_id);
  const name = pickFirstStringField(
    card.name,
    cardRecord.cardName,
    cardRecord.card_name,
    cardRecord.title,
    cardInfo.name,
    cardInfo.clean_name,
  );
  const number = pickFirstStringField(
    card.number,
    cardRecord.no,
    cardRecord.cardNumber,
    cardRecord.card_number,
    cardInfo.card_number,
    cardInfo.number,
  );
  const imageUrl = pickFirstStringField(
    card.imageUrl,
    card.image_url,
    card.image,
    imageRecord.url,
    imageRecord.small,
    imageRecord.large,
    cardInfo.image_url,
  );
  const rarity = pickFirstStringField(card.rarity, cardRecord.rarityLabel, cardRecord.rarity_label, cardInfo.rarity);
  const setCode = pickFirstStringField(
    card.setCode,
    card.set_code,
    setRecord.code,
    setRecord.id,
    setRecord.setCode,
    cardInfo.set_code,
    cardInfo.set_id,
  );

  if (!id || !name) {
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

  const market = toPriceValue(prices?.market ?? card.market) ?? pickMarketFromProviderPrices(cardRecord) ?? 0;

  const candidate: CardCandidate = {
    id,
    name,
    prices: {
      market,
      conditions,
    },
  };

  if (number) {
    candidate.number = number;
  }
  if (imageUrl) {
    candidate.imageUrl = imageUrl;
  }
  if (rarity) {
    candidate.rarity = rarity;
  }
  if (setCode) {
    candidate.setCode = setCode;
  }

  return candidate;
}

export function normalizePokewalletLookupResponse(response: unknown): CardCandidate[] {
  return extractCards(response)
    .map((card) => normalizeCard(card))
    .filter((card): card is CardCandidate => card !== null);
}
