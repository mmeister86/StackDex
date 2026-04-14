# Convex Wave 1a Backend Scaffold

This directory contains Wave 1a backend scaffolding for `cards.lookup.v1`.

## Implemented In Wave 1a

- Contract and response envelope helper in `convex/lib/cardsLookupContract.ts`
- Pokewallet normalization logic in `convex/lib/pokewalletNormalizer.ts`
- Pokewallet error taxonomy in `convex/lib/pokewalletErrors.ts`
- Test harness setup in `convex/test.setup.ts`

`convex/cards.ts` and `convex/pokewallet.ts` are intentionally out of scope for Wave 1a.

## Contract Notes

- Envelope schema version: `cards.lookup.v1`
- Envelope shape: `payload: { candidates: [...] }`
- Candidate prices keep parser-compatible values (`number | string`)
- Condition keys are normalized into canonical values:
  - `mint`
  - `near_mint`
  - `lightly_played`
  - `moderately_played`
  - `heavily_played`
  - `damaged`

## Tests

Run Wave 1a tests:

```bash
npm run convex:test -- convex/lib/cardsLookupContract.test.ts convex/lib/pokewalletNormalizer.test.ts
```
