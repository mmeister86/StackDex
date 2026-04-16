import { describe, expect, it, vi } from "vitest";

import { TcgdexUpstreamError } from "./lib/tcgdexErrors";
import { fetchTcgdexCandidates } from "./tcgdex";

describe("tcgdex upstream integration", () => {
  it("calls card list and card detail endpoints", async () => {
    process.env.TCGDEX_BASE_URL = "https://api.tcgdex.net";
    delete process.env.TCGDEX_LANGUAGE;

    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              id: "swsh3-136",
              localId: "136",
              name: "Furret",
              image: "https://assets.tcgdex.net/en/swsh/swsh3/136",
            },
          ]),
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
            id: "swsh3-136",
            localId: "136",
            name: "Furret",
            rarity: "Uncommon",
            set: {
              id: "swsh3",
            },
            pricing: {
              tcgplayer: {
                normal: {
                  marketPrice: 0.09,
                },
              },
            },
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

    const result = await fetchTcgdexCandidates({
      query: "furret",
      recognizedTexts: ["furret"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(2);

    const [listRequestUrl] = fetchSpy.mock.calls[0] as [RequestInfo | URL, RequestInit];
    const parsedListUrl = new URL(
      typeof listRequestUrl === "string"
        ? listRequestUrl
        : listRequestUrl instanceof URL
          ? listRequestUrl.toString()
          : listRequestUrl.url,
    );
    expect(parsedListUrl.origin).toBe("https://api.tcgdex.net");
    expect(parsedListUrl.pathname).toBe("/v2/en/cards");
    expect(parsedListUrl.searchParams.get("name")).toBe("furret");

    const [detailRequestUrl] = fetchSpy.mock.calls[1] as [RequestInfo | URL, RequestInit];
    const parsedDetailUrl = new URL(
      typeof detailRequestUrl === "string"
        ? detailRequestUrl
        : detailRequestUrl instanceof URL
          ? detailRequestUrl.toString()
          : detailRequestUrl.url,
    );
    expect(parsedDetailUrl.pathname).toBe("/v2/en/cards/swsh3-136");

    expect(result).toEqual([
      {
        id: "swsh3-136",
        number: "136",
        name: "Furret",
        rarity: "Uncommon",
        setCode: "swsh3",
        prices: {
          market: 0.09,
          conditions: {},
        },
      },
    ]);
  });

  it("retries with normalized query when first query returns empty", async () => {
    process.env.TCGDEX_BASE_URL = "https://api.tcgdex.net";
    delete process.env.TCGDEX_LANGUAGE;

    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        }),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              id: "swsh4-157",
              localId: "157",
              name: "Pikachu VMAX",
            },
          ]),
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
            id: "swsh4-157",
            localId: "157",
            name: "Pikachu VMAX",
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

    const result = await fetchTcgdexCandidates({
      query: "Pikachu-VMAX",
      recognizedTexts: ["Pikachu-VMAX"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(3);

    const [firstRequestUrl] = fetchSpy.mock.calls[0] as [RequestInfo | URL, RequestInit];
    const firstParsedUrl = new URL(
      typeof firstRequestUrl === "string"
        ? firstRequestUrl
        : firstRequestUrl instanceof URL
          ? firstRequestUrl.toString()
          : firstRequestUrl.url,
    );
    expect(firstParsedUrl.searchParams.get("name")).toBe("Pikachu-VMAX");

    const [secondRequestUrl] = fetchSpy.mock.calls[1] as [RequestInfo | URL, RequestInit];
    const secondParsedUrl = new URL(
      typeof secondRequestUrl === "string"
        ? secondRequestUrl
        : secondRequestUrl instanceof URL
          ? secondRequestUrl.toString()
          : secondRequestUrl.url,
    );
    expect(secondParsedUrl.searchParams.get("name")).toBe("pikachu vmax");
    expect(result[0]?.id).toBe("swsh4-157");
  });

  it("keeps list candidate when detail fetch fails", async () => {
    process.env.TCGDEX_BASE_URL = "https://api.tcgdex.net";
    process.env.TCGDEX_LANGUAGE = "de";

    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              id: "base1-25",
              localId: "25",
              name: "Pikachu",
              rarity: "Common",
              set: {
                id: "base1",
              },
            },
          ]),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
            },
          },
        ),
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ error: "not found" }), {
          status: 404,
          headers: {
            "Content-Type": "application/json",
          },
        }),
      );
    vi.stubGlobal("fetch", fetchSpy as unknown as typeof fetch);

    const result = await fetchTcgdexCandidates({
      query: "pikachu",
      recognizedTexts: ["pikachu"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(result).toEqual([
      {
        id: "base1-25",
        number: "25",
        name: "Pikachu",
        rarity: "Common",
        setCode: "base1",
        prices: {
          market: 0,
          conditions: {},
        },
      },
    ]);
  });

  it("falls back from configured language to english when configured language returns no hits", async () => {
    process.env.TCGDEX_BASE_URL = "https://api.tcgdex.net";
    process.env.TCGDEX_LANGUAGE = "de";

    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify([]), {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        }),
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify([
            {
              id: "base1-25",
              localId: "25",
              name: "Pikachu",
              set: {
                id: "base1",
              },
            },
          ]),
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
            id: "base1-25",
            localId: "25",
            name: "Pikachu",
            set: {
              id: "base1",
            },
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

    const result = await fetchTcgdexCandidates({
      query: "pikachu",
      recognizedTexts: ["pikachu"],
      maxResults: 3,
    });

    expect(fetchSpy).toHaveBeenCalledTimes(3);

    const [firstRequestUrl] = fetchSpy.mock.calls[0] as [RequestInfo | URL, RequestInit];
    const firstParsedUrl = new URL(
      typeof firstRequestUrl === "string"
        ? firstRequestUrl
        : firstRequestUrl instanceof URL
          ? firstRequestUrl.toString()
          : firstRequestUrl.url,
    );
    expect(firstParsedUrl.pathname).toBe("/v2/de/cards");

    const [secondRequestUrl] = fetchSpy.mock.calls[1] as [RequestInfo | URL, RequestInit];
    const secondParsedUrl = new URL(
      typeof secondRequestUrl === "string"
        ? secondRequestUrl
        : secondRequestUrl instanceof URL
          ? secondRequestUrl.toString()
          : secondRequestUrl.url,
    );
    expect(secondParsedUrl.pathname).toBe("/v2/en/cards");

    expect(result[0]?.id).toBe("base1-25");
  });

  it("surfaces upstream HTTP status errors on list fetch", async () => {
    process.env.TCGDEX_BASE_URL = "https://api.tcgdex.net";
    delete process.env.TCGDEX_LANGUAGE;

    const fetchSpy = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: "bad request" }), {
        status: 400,
        headers: {
          "Content-Type": "application/json",
        },
      }),
    );
    vi.stubGlobal("fetch", fetchSpy as unknown as typeof fetch);

    await expect(
      fetchTcgdexCandidates({
        query: "pikachu",
        recognizedTexts: ["pikachu"],
        maxResults: 3,
      }),
    ).rejects.toBeInstanceOf(TcgdexUpstreamError);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });
});
