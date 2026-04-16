const DASH_PATTERN = /[\p{Dash_Punctuation}\u2212]+/gu;
const NON_SEARCH_CHAR_PATTERN = /[^\p{L}\p{N}/\s]+/gu;
const MULTIPLE_WHITESPACE_PATTERN = /\s+/g;

export function normalizePokewalletQuery(input: string): string {
  return input
    .normalize("NFKC")
    .replace(DASH_PATTERN, " ")
    .replace(NON_SEARCH_CHAR_PATTERN, " ")
    .replace(MULTIPLE_WHITESPACE_PATTERN, " ")
    .trim()
    .toLowerCase();
}
