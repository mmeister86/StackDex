import type { PokewalletLookupArgs } from "./pokewalletTypes";

export type TcgdexLookupArgs = PokewalletLookupArgs;

export type TcgdexSetLike = {
  id?: string;
  name?: string;
};

export type TcgdexTcgplayerVariantPricing = {
  lowPrice?: unknown;
  midPrice?: unknown;
  highPrice?: unknown;
  marketPrice?: unknown;
  directLowPrice?: unknown;
};

export type TcgdexTcgplayerPricing = {
  normal?: TcgdexTcgplayerVariantPricing;
  reverse?: TcgdexTcgplayerVariantPricing;
  holo?: TcgdexTcgplayerVariantPricing;
  "1stEditionHolofoil"?: TcgdexTcgplayerVariantPricing;
};

export type TcgdexCardmarketPricing = {
  low?: unknown;
  avg?: unknown;
  trend?: unknown;
  avg1?: unknown;
  avg7?: unknown;
  avg30?: unknown;
};

export type TcgdexPricing = {
  tcgplayer?: TcgdexTcgplayerPricing;
  cardmarket?: TcgdexCardmarketPricing;
};

export type TcgdexCardLike = {
  id?: string;
  localId?: string | number;
  number?: string | number;
  name?: string;
  image?: string;
  imageUrl?: string;
  image_url?: string;
  rarity?: string;
  set?: TcgdexSetLike;
  setCode?: string;
  set_code?: string;
  prices?: {
    market?: unknown;
  };
  pricing?: TcgdexPricing;
};
