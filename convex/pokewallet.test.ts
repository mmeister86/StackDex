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

  it("retries with normalized query when the first response is empty", async () => {
    process.env.POKEWALLET_API_KEY = "pk_live_test";
    process.env.POKEWALLET_BASE_URL = "https://api.pokewallet.io";

    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            results: [],
          }),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
            },
          },
        ),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            results: [
              {
                id: "pk_456",
                card_info: {
                  name: "Mega Gengar ex",
                  card_number: "56/094",
                  set_code: "PFL",
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
      query: "Mega-Gengar ex",
      recognizedTexts: ["Mega-Gengar ex"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(2);

    const [firstUrl] = fetchSpy.mock.calls[0] as [RequestInfo | URL, RequestInit];
    const firstParsedUrl = new URL(
      typeof firstUrl === "string" ? firstUrl : firstUrl instanceof URL ? firstUrl.toString() : firstUrl.url,
    );
    expect(firstParsedUrl.searchParams.get("q")).toBe("Mega-Gengar ex");

    const [secondUrl] = fetchSpy.mock.calls[1] as [RequestInfo | URL, RequestInit];
    const secondParsedUrl = new URL(
      typeof secondUrl === "string" ? secondUrl : secondUrl instanceof URL ? secondUrl.toString() : secondUrl.url,
    );
    expect(secondParsedUrl.searchParams.get("q")).toBe("mega gengar ex");

    expect(result).toEqual([
      {
        id: "pk_456",
        name: "Mega Gengar ex",
        number: "56/094",
        setCode: "PFL",
        prices: {
          market: 0,
          conditions: {},
        },
      },
    ]);
  });

  it("does not issue a fallback request when query is already normalized", async () => {
    process.env.POKEWALLET_API_KEY = "pk_live_test";
    process.env.POKEWALLET_BASE_URL = "https://api.pokewallet.io";

    const fetchSpy = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          results: [],
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
      query: "pikachu ex",
      recognizedTexts: ["pikachu ex"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(result).toEqual([]);
  });

  it("surfaces upstream HTTP status errors", async () => {
    process.env.POKEWALLET_API_KEY = "pk_live_test";
    process.env.POKEWALLET_BASE_URL = "https://api.pokewallet.io";

    const fetchSpy = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: {
          "Content-Type": "application/json",
        },
      }),
    );

    vi.stubGlobal(
      "fetch",
      fetchSpy as unknown as typeof fetch,
    );

    await expect(
      fetchPokewalletCandidates({
        query: "Mega-Gengar ex",
        recognizedTexts: ["Mega-Gengar ex"],
        maxResults: 3,
      }),
    ).rejects.toBeInstanceOf(PokewalletUpstreamError);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });
});
