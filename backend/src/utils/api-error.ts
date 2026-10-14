export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}

export function assertAllowed(condition: boolean, code: string, message: string): asserts condition {
  if (!condition) {
    throw new ApiError(403, code, message);
  }
}
