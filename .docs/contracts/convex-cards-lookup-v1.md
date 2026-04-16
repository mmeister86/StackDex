# Contract Spec: Convex Cards Lookup v1

## 1. Identity, Version, Ownership

- **Contract ID / schema literal:** `cards.lookup.v1`
- **Boundary owner:** Convex BFF (public app-facing contract)
- **Upstream data owner:** Pokewallet (hidden behind Convex; never called directly by iOS)
- **Audience:** iOS client + Convex backend maintainers

This document defines the wire contract currently expected by the implemented iOS client.

## 2. Request Shape (iOS -> Convex `/api/query`)

- **HTTP endpoint:** `POST /api/query`
- **Transport wrapper (Convex HTTP API):**
  - `path` (string): must be `cards:lookup`
  - `args` (object): function arguments (defined below)
  - `format` (string): must be `json`

### `args` contract

- **Required:**
  - `recognizedTexts` (array of string)
  - `query` (string)
  - `maxResults` (number)
  - `responseSchemaVersion` (string): must be `cards.lookup.v1`
- **Optional:**
  - `hints` (object)
    - `normalizedQuery` (string)
    - `nameTokens` (array of string)
    - `possibleNumbers` (array of string)
    - `possibleSetCodes` (array of string)
    - `possibleRarities` (array of string)
    - `possibleLanguages` (array of string)

### Full request example

```json
{
  "path": "cards:lookup",
  "args": {
    "recognizedTexts": ["charizard", "4/102"],
    "query": "charizard 4/102",
    "maxResults": 5,
    "responseSchemaVersion": "cards.lookup.v1",
    "hints": {
      "normalizedQuery": "charizard 4/102",
      "nameTokens": ["charizard"],
      "possibleNumbers": ["4/102"],
      "possibleSetCodes": ["SVI"],
      "possibleRarities": ["Rare"],
      "possibleLanguages": ["DE"]
    }
  },
  "format": "json"
}
```

## 3. Response Envelope and Convex Transport

Convex `/api/query` wraps function output in a transport object. For this contract, iOS expects the schema envelope under `value`.

- Convex transport success shape (relevant part):
  - `status`: `"success"`
  - `value`: function return payload
- Inside `value`, the function must return:
  - `schemaVersion` (string): for v1, `cards.lookup.v1`
  - `payload` (object)
    - `candidates` (array of `Candidate`)

### Temporary legacy compatibility rule (migration)

- The canonical v1 contract is the envelope form (`value.schemaVersion` + `value.payload`).
- While migration is in progress, iOS still accepts legacy non-envelope, unversioned payloads (for example a direct array or object under `value`/`result`/`data`).
- If a response uses an envelope container (`payload` key present), `schemaVersion` is required and must match the requested version.
- Legacy acceptance is compatibility-only and will be removed after backend migration is complete.

### Full response example

```json
{
  "status": "success",
  "value": {
    "schemaVersion": "cards.lookup.v1",
    "payload": {
      "candidates": [
        {
          "id": "base1-4",
          "name": "Charizard",
          "number": "4/102",
          "imageUrl": "https://img.pokewallet.example/cards/base1-4.png",
          "rarity": "Holo Rare",
          "setCode": "base1",
          "prices": {
            "market": 349.99,
            "conditions": {
              "near_mint": "349.99",
              "lightly_played": 279.5
            }
          }
        }
      ]
    }
  }
}
```

## 4. Candidate Schema (`value.payload.candidates[]`)

- **Core identity**
  - `id` (string)
  - `name` (string)
  - `number` (string)
  - `imageUrl` (string URL)
- **Details**
  - `rarity` (string)
  - `setCode` (string)
- **Prices**
  - `prices.market` (number or decimal string)
  - `prices.conditions` (object/map)
    - keys should be canonical `CardCondition` raw values:
      - `mint`
      - `near_mint`
      - `lightly_played`
      - `moderately_played`
      - `heavily_played`
      - `damaged`
    - value per key: number or decimal string

## 5. Versioning and Rollout

- Client sends `args.responseSchemaVersion` to request an exact schema.
- iOS validates `value.schemaVersion` strictly against the requested `args.responseSchemaVersion` (no implicit fallback acceptance).
- Server returns `schemaVersion` in the function envelope for runtime validation.
- Additive, backward-compatible changes stay within `cards.lookup.v1` (new optional fields only).
- Request-side hint extensions (`possibleSetCodes`, `possibleRarities`, `possibleLanguages`) are additive and remain `cards.lookup.v1` compatible.
- Breaking changes require a new literal (for example `cards.lookup.v2`) with parallel server support.
- Rollout pattern: dual-serve versions, gate iOS opt-in by config/flag, remove old version only after supported clients migrate.

## 6. Error and Empty Handling Expectations

- **No matches:** return success transport + envelope with `payload.candidates: []`.
- **Upstream/recoverable failure:** return Convex error response; iOS falls back to safe scan UX.
- **Schema mismatch:** iOS treats payload as incompatible and fails safely (no crash).
- **Malformed envelope:** if the response uses a `payload` envelope container but omits `schemaVersion`, iOS treats it as a schema mismatch.

This contract matches current `cards.lookup.v1` iOS request/response expectations.
