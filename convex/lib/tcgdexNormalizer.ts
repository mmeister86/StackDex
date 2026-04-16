import type { CardCandidate, PriceValue } from "./cardsLookupContract";
import type {
  TcgdexCardLike,
  TcgdexCardmarketPricing,
  TcgdexPricing,
  TcgdexTcgplayerPricing,
  TcgdexTcgplayerVariantPricing,
} from "./tcgdexTypes";

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

function pickTcgplayerMarket(pricing: TcgdexTcgplayerPricing | null): PriceValue | null {
  if (!pricing) {
    return null;
  }

  const priceVariants: Array<TcgdexTcgplayerVariantPricing | undefined> = [
    pricing.normal,
    pricing.holo,
    pricing.reverse,
    pricing["1stEditionHolofoil"],
  ];

  for (const variant of priceVariants) {
    if (!variant) {
      continue;
    }

    const market = toPriceValue(variant.marketPrice ?? variant.midPrice ?? variant.lowPrice ?? variant.directLowPrice);
    if (market !== null) {
      return market;
    }
  }

  return null;
}

function pickCardmarketMarket(pricing: TcgdexCardmarketPricing | null): PriceValue | null {
  if (!pricing) {
    return null;
  }

  return toPriceValue(pricing.trend ?? pricing.avg ?? pricing.low ?? pricing.avg7 ?? pricing.avg30 ?? pricing.avg1);
}

function pickMarketValue(cardRecord: Record<string, unknown>): PriceValue {
  const prices = toRecord(cardRecord.prices);
  const pricing = toRecord(cardRecord.pricing) as TcgdexPricing | null;
  const tcgplayer = toRecord(pricing?.tcgplayer) as TcgdexTcgplayerPricing | null;
  const cardmarket = toRecord(pricing?.cardmarket) as TcgdexCardmarketPricing | null;

  return (
    toPriceValue(prices?.market) ??
    pickTcgplayerMarket(tcgplayer) ??
    pickCardmarketMarket(cardmarket) ??
    0
  );
}

function normalizeCard(card: TcgdexCardLike): CardCandidate | null {
  const cardRecord = toRecord(card) ?? {};
  const setRecord = toRecord(cardRecord.set) ?? {};

  const id = pickFirstStringField(card.id, cardRecord.cardId, cardRecord.card_id);
  const name = pickFirstStringField(card.name, cardRecord.cardName, cardRecord.card_name, cardRecord.title);
  const number = pickFirstStringField(card.localId, card.number, cardRecord.local_id, cardRecord.cardNumber, cardRecord.no);
  const imageUrl = pickFirstStringField(card.image, card.imageUrl, card.image_url);
  const rarity = pickFirstStringField(card.rarity, cardRecord.rarityLabel, cardRecord.rarity_label);
  const setCode = pickFirstStringField(card.setCode, card.set_code, setRecord.id, setRecord.code);

  if (!id || !name) {
    return null;
  }

  const candidate: CardCandidate = {
    id,
    name,
    prices: {
      market: pickMarketValue(cardRecord),
      conditions: {},
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

function extractCards(response: unknown): TcgdexCardLike[] {
  if (Array.isArray(response)) {
    return response as TcgdexCardLike[];
  }

  return [];
}

export function normalizeTcgdexCardsResponse(response: unknown): CardCandidate[] {
  return extractCards(response)
    .map((card) => normalizeCard(card))
    .filter((card): card is CardCandidate => card !== null);
}

export function normalizeTcgdexCardResponse(response: unknown): CardCandidate | null {
  const record = toRecord(response);
  if (!record) {
    return null;
  }

  return normalizeCard(record as TcgdexCardLike);
}
