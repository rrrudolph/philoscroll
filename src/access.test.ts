import { describe, expect, it } from "vitest";
import { isAuthorized } from "./access";

describe("access secret", () => {
  it("leaves the app open when no secret is configured", () => {
    expect(isAuthorized(undefined, undefined)).toBe(true);
    expect(isAuthorized(undefined, "")).toBe(true);
  });

  it("accepts only the matching header", () => {
    expect(isAuthorized("quiet", "quiet")).toBe(true);
    expect(isAuthorized("nope", "quiet")).toBe(false);
    expect(isAuthorized(undefined, "quiet")).toBe(false);
    expect(isAuthorized(["quiet", "other"], "quiet")).toBe(true);
    expect(isAuthorized(["other"], "quiet")).toBe(false);
  });
});
