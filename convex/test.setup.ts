import { afterEach, beforeEach, vi } from "vitest";

const originalApiKey = process.env.POKEWALLET_API_KEY;
const originalBaseUrl = process.env.POKEWALLET_BASE_URL;

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
});

afterEach(() => {
  vi.restoreAllMocks();
});
