import { afterEach, beforeEach, vi } from "vitest";

const originalApiKey = process.env.POKEWALLET_API_KEY;
const originalBaseUrl = process.env.POKEWALLET_BASE_URL;
const originalTcgdexBaseUrl = process.env.TCGDEX_BASE_URL;
const originalTcgdexLanguage = process.env.TCGDEX_LANGUAGE;

beforeEach(() => {
  if (originalApiKey === undefined) {
    delete process.env.POKEWALLET_API_KEY;
  } else {
    process.env.POKEWALLET_API_KEY = originalApiKey;
  }

  if (originalBaseUrl === undefined) {
    delete process.env.POKEWALLET_BASE_URL;
  } else {
    process.env.POKEWALLET_BASE_URL = originalBaseUrl;
  }

  if (originalTcgdexBaseUrl === undefined) {
    delete process.env.TCGDEX_BASE_URL;
  } else {
    process.env.TCGDEX_BASE_URL = originalTcgdexBaseUrl;
  }

  if (originalTcgdexLanguage === undefined) {
    delete process.env.TCGDEX_LANGUAGE;
  } else {
    process.env.TCGDEX_LANGUAGE = originalTcgdexLanguage;
  }
});

afterEach(() => {
  vi.restoreAllMocks();
});
