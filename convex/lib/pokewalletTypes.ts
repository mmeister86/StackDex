export type PokewalletLookupArgs = {
  recognizedTexts: string[];
  query: string;
  maxResults: number;
  hints?: {
    normalizedQuery?: string;
    nameTokens?: string[];
    possibleNumbers?: string[];
    possibleSetCodes?: string[];
    possibleRarities?: string[];
    possibleLanguages?: string[];
  };
};

export type PokewalletCardInfo = {
  id?: string | number;
  card_id?: string | number;
  name?: string;
  clean_name?: string;
  card_number?: string | number;
  number?: string | number;
  set_code?: string;
  set_id?: string | number;
  rarity?: string;
  image_url?: string;
};

export type PokewalletProviderPrice = {
  sub_type_name?: string;
  variant_type?: string;
  market_price?: unknown;
  mid_price?: unknown;
  low?: unknown;
  low_price?: unknown;
  avg?: unknown;
  avg30?: unknown;
  trend?: unknown;
};

export type PokewalletCardLike = {
  id?: string | number;
  name?: string;
  number?: string | number;
  imageUrl?: string;
  image_url?: string;
  image?: string;
  rarity?: string;
  setCode?: string;
  set_code?: string;
  prices?: {
    market?: unknown;
    conditions?: Record<string, unknown>;
  };
  market?: unknown;
  conditionPrices?: Record<string, unknown>;
  card_info?: PokewalletCardInfo;
  cardInfo?: PokewalletCardInfo;
  tcgplayer?: {
    prices?: PokewalletProviderPrice[];
  };
  cardmarket?: {
    prices?: PokewalletProviderPrice[];
  };
};

export type PokewalletLookupResponse = {
  results?: PokewalletCardLike[];
  cards?: PokewalletCardLike[];
  data?: PokewalletCardLike[];
};
