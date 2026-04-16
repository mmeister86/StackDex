export class TcgdexUpstreamError extends Error {
  readonly status?: number;

  constructor(message: string, options?: { status?: number; cause?: unknown }) {
    super(message, { cause: options?.cause });
    this.name = "TcgdexUpstreamError";
    this.status = options?.status;
  }
}
