/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as cards from "../cards.js";
import type * as lib_cardsLookupContract from "../lib/cardsLookupContract.js";
import type * as lib_pokewalletErrors from "../lib/pokewalletErrors.js";
import type * as lib_pokewalletNormalizer from "../lib/pokewalletNormalizer.js";
import type * as lib_pokewalletQueryNormalizer from "../lib/pokewalletQueryNormalizer.js";
import type * as lib_pokewalletTypes from "../lib/pokewalletTypes.js";
import type * as lib_tcgdexErrors from "../lib/tcgdexErrors.js";
import type * as lib_tcgdexNormalizer from "../lib/tcgdexNormalizer.js";
import type * as lib_tcgdexTypes from "../lib/tcgdexTypes.js";
import type * as pokewallet from "../pokewallet.js";
import type * as tcgdex from "../tcgdex.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  cards: typeof cards;
  "lib/cardsLookupContract": typeof lib_cardsLookupContract;
  "lib/pokewalletErrors": typeof lib_pokewalletErrors;
  "lib/pokewalletNormalizer": typeof lib_pokewalletNormalizer;
  "lib/pokewalletQueryNormalizer": typeof lib_pokewalletQueryNormalizer;
  "lib/pokewalletTypes": typeof lib_pokewalletTypes;
  "lib/tcgdexErrors": typeof lib_tcgdexErrors;
  "lib/tcgdexNormalizer": typeof lib_tcgdexNormalizer;
  "lib/tcgdexTypes": typeof lib_tcgdexTypes;
  pokewallet: typeof pokewallet;
  tcgdex: typeof tcgdex;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
