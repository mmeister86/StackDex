export class MissingPokewalletApiKeyError extends Error {
  constructor() {
    super("Missing required POKEWALLET_API_KEY environment variable for Pokewallet lookup.");
    this.name = "MissingPokewalletApiKeyError";
  }
}

export class PokewalletUpstreamError extends Error {
  readonly status?: number;

  constructor(message: string, options?: { status?: number; cause?: unknown }) {
    super(message, { cause: options?.cause });
    this.name = "PokewalletUpstreamError";
    this.status = options?.status;
  }
}
