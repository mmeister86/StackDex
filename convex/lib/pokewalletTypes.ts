export type PokewalletLookupArgs = {
  recognizedTexts: string[];
  query: string;
  maxResults: number;
  hints?: {
    normalizedQuery?: string;
    nameTokens?: string[];
    possibleNumbers?: string[];
  };
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
};

export type PokewalletLookupResponse = {
  results?: PokewalletCardLike[];
  cards?: PokewalletCardLike[];
  data?: PokewalletCardLike[];
};
