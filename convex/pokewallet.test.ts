import { describe, expect, it, vi } from "vitest";

import { MissingPokewalletApiKeyError, PokewalletUpstreamError } from "./lib/pokewalletErrors";
import { fetchPokewalletCandidates } from "./pokewallet";

describe("pokewallet upstream integration", () => {
  it("throws a dedicated error when no API key is configured", async () => {
    delete process.env.POKEWALLET_API_KEY;

    await expect(
      fetchPokewalletCandidates({
        query: "pikachu",
        recognizedTexts: ["pikachu"],
        maxResults: 3,
      }),
    ).rejects.toBeInstanceOf(MissingPokewalletApiKeyError);
  });

  it("calls GET /search with X-API-Key header", async () => {
    process.env.POKEWALLET_API_KEY = "pk_live_test";
    process.env.POKEWALLET_BASE_URL = "https://api.pokewallet.io";

    const fetchSpy = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          results: [
            {
              id: "pk_123",
              card_info: {
                name: "Pikachu",
                card_number: "25",
                set_code: "base1",
              },
            },
          ],
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        },
      ),
    );
    vi.stubGlobal("fetch", fetchSpy as unknown as typeof fetch);

    const result = await fetchPokewalletCandidates({
      query: "pikachu",
      recognizedTexts: ["pikachu"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(1);

    const [requestUrl, requestInit] = fetchSpy.mock.calls[0] as [RequestInfo | URL, RequestInit];
    const parsedUrl = new URL(
      typeof requestUrl === "string"
        ? requestUrl
        : requestUrl instanceof URL
          ? requestUrl.toString()
          : requestUrl.url,
    );

    expect(parsedUrl.origin).toBe("https://api.pokewallet.io");
    expect(parsedUrl.pathname).toBe("/search");
    expect(parsedUrl.searchParams.get("q")).toBe("pikachu");
    expect(parsedUrl.searchParams.get("limit")).toBe("3");
    expect(requestInit.method).toBe("GET");
    expect(requestInit.headers).toMatchObject({
      Accept: "application/json",
      "X-API-Key": "pk_live_test",
    });
    expect(result).toEqual([
      {
        id: "pk_123",
        name: "Pikachu",
        number: "25",
        setCode: "base1",
        prices: {
          market: 0,
          conditions: {},
        },
      },
    ]);
  });

  it("surfaces upstream HTTP status errors", async () => {
    process.env.POKEWALLET_API_KEY = "pk_live_test";
    process.env.POKEWALLET_BASE_URL = "https://api.pokewallet.io";

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: {
            "Content-Type": "application/json",
          },
        }),
      ) as unknown as typeof fetch,
    );

    await expect(
      fetchPokewalletCandidates({
        query: "charizard",
        recognizedTexts: ["charizard"],
        maxResults: 3,
      }),
    ).rejects.toBeInstanceOf(PokewalletUpstreamError);
  });
});
