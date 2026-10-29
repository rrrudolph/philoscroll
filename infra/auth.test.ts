import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Script } from "node:vm";
import { describe, expect, it } from "vitest";
import { themes } from "../src/tokens";

const here = dirname(fileURLToPath(import.meta.url));

type Header = { value: string };
type Cookie = { value: string; attributes: string };

type GateRequest = {
  uri: string;
  querystring: Record<string, { value: string }>;
  cookies: Record<string, { value: string }>;
  headers: Record<string, Header>;
};

type GateEvent = {
  context: { distributionDomainName: string };
  request: GateRequest;
};

type GateResponse = {
  statusCode: number;
  statusDescription: string;
  headers: Record<string, Header>;
  cookies?: Record<string, Cookie>;
  body?: string;
};

type Handler = (event: GateEvent) => GateRequest | GateResponse;

function loadHandler(password: string, queryName = "k", cookieName = "philo"): Handler {
  const source = readFileSync(join(here, "auth.js.tftpl"), "utf8")
    .replaceAll("${password_json}", JSON.stringify(password))
    .replaceAll("${query_name_json}", JSON.stringify(queryName))
    .replaceAll("${cookie_name_json}", JSON.stringify(cookieName));
  if (source.includes("${")) throw new Error("unresolved template placeholder");
  const context: { handler?: Handler } = {};
  new Script(`${source}\nglobalThis.handler = handler;`).runInNewContext(context);
  if (!context.handler) throw new Error("gate handler was not created");
  return context.handler;
}

function event(input: { uri?: string; host?: string; key?: string; cookie?: string }): GateEvent {
  return {
    context: { distributionDomainName: "d111.cloudfront.net" },
    request: {
      uri: input.uri ?? "/",
      querystring: input.key === undefined ? {} : { k: { value: input.key } },
      cookies: input.cookie === undefined ? {} : { philo: { value: input.cookie } },
      headers: { host: { value: input.host ?? "d111.cloudfront.net" } },
    },
  };
}

function response(result: GateRequest | GateResponse): GateResponse {
  if (!("statusCode" in result)) throw new Error("expected a gate response");
  return result;
}

function relativeLuminance(hex: string): number {
  const channels = [0, 2, 4].map((start) => {
    const value = parseInt(hex.slice(start + 1, start + 3), 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  const [red, green, blue] = channels;
  if (red === undefined || green === undefined || blue === undefined) throw new Error("bad color");
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

function contrastRatio(foreground: string, background: string): number {
  const first = relativeLuminance(foreground);
  const second = relativeLuminance(background);
  const lighter = Math.max(first, second);
  const darker = Math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

function painted(body: string): Array<{ background: string; color: string }> {
  return [...body.matchAll(/background:(#[0-9A-Fa-f]{6});color:(#[0-9A-Fa-f]{6})/g)].map((match) => {
    const background = match[1];
    const color = match[2];
    if (!background || !color) throw new Error("missing colors");
    return { background, color };
  });
}

describe("phone link gate", () => {
  const password = "quiet-scroll";
  const handler = loadHandler(password);

  it("refuses a visit that does not have the password", () => {
    const result = response(handler(event({})));
    expect(result.statusCode).toBe(401);
    expect(result.headers["cache-control"]?.value).toBe("no-store");
    expect(result.headers["content-type"]?.value).toContain("text/html");
    expect(result.body).toContain("This scroll is private.");
    expect(result.body).toContain('name="viewport"');
    expect(result.body).toContain("prefers-color-scheme: dark");
    expect(result.headers["set-cookie"]).toBeUndefined();

    const colors = painted(result.body ?? "");
    expect(colors).toEqual([
      { background: themes.light.surface, color: themes.light.text },
      { background: themes.dark.bg, color: themes.dark.text },
    ]);
    for (const pair of colors) {
      expect(contrastRatio(pair.color, pair.background)).toBeGreaterThanOrEqual(4.5);
    }
  });

  it("remembers the phone and drops the password from the address", () => {
    const result = response(handler(event({ key: password, uri: "/" })));
    expect(result.statusCode).toBe(302);
    expect(result.headers.location?.value).toBe("https://d111.cloudfront.net/");
    expect(result.headers.location?.value).not.toContain(password);
    expect(result.headers.location?.value).not.toContain("?");
    expect(result.headers["set-cookie"]).toBeUndefined();
    expect(result.cookies?.philo).toEqual({
      value: password,
      attributes: "Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=31536000",
    });
    expect(result.headers["cache-control"]?.value).toBe("no-store");
  });

  it("accepts a new link when the phone still remembers an old password", () => {
    const result = response(handler(event({ key: password, cookie: "old-password" })));
    expect(result.statusCode).toBe(302);
    expect(result.headers["set-cookie"]).toBeUndefined();
    expect(result.cookies?.philo?.value).toBe(password);
  });

  it("refuses a wrong link even when the phone was already remembered", () => {
    const result = response(handler(event({ key: "wrong-password", cookie: password })));
    expect(result.statusCode).toBe(401);
    expect(result.headers["set-cookie"]).toBeUndefined();
  });

  it("lets the script and fonts load once the phone is remembered", () => {
    const source = event({ uri: "/assets/index.js", cookie: password });
    expect(handler(source)).toBe(source.request);
    expect(source.request.uri).toBe("/assets/index.js");

    const font = event({ uri: "/assets/playfair.woff2", cookie: password });
    expect(handler(font)).toBe(font.request);
    expect(font.request.uri).toBe("/assets/playfair.woff2");
  });

  it("maps folder paths to index.html for S3 subfolders", () => {
    const folder = event({ uri: "/archive/", cookie: password });
    const result = handler(folder);
    expect(result).toBe(folder.request);
    expect(folder.request.uri).toBe("/archive/index.html");

    const bare = event({ uri: "/archive", cookie: password });
    const canonical = response(handler(bare));
    expect(canonical.statusCode).toBe(301);
    expect(canonical.headers.location?.value).toBe("https://d111.cloudfront.net/archive/");
  });

  it("uses trailing slashes in post-login redirects for folder paths", () => {
    const result = response(handler(event({ key: password, uri: "/archive" })));
    expect(result.statusCode).toBe(302);
    expect(result.headers.location?.value).toBe("https://d111.cloudfront.net/archive/");
  });

  it("does not send a remembered phone anywhere but this site", () => {
    const result = response(handler(event({ key: password, uri: "//evil.example/steal" })));
    expect(result.headers.location?.value).toBe("https://d111.cloudfront.net/");
  });

  it("builds the phone link from the same password the gate checks", () => {
    const variables = readFileSync(join(here, "variables.tf"), "utf8");
    const main = readFileSync(join(here, "main.tf"), "utf8");
    const outputs = readFileSync(join(here, "outputs.tf"), "utf8");
    const match = variables.match(/variable "access_password"[\s\S]*?default\s+=\s+"([^"]+)"/);
    const hardcoded = match?.[1];
    expect(hardcoded).toMatch(/^[A-Za-z0-9_-]{8,64}$/);
    expect(response(loadHandler(hardcoded ?? "")(event({ key: hardcoded }))).statusCode).toBe(302);
    expect(main).toContain('runtime = "cloudfront-js-2.0"');
    expect(main).toMatch(/access_param\s+=\s+"k"/);
    expect(main).toMatch(/access_cookie\s+=\s+"philo"/);
    expect(main).toContain("jsonencode(var.access_password)");
    expect(main).toContain("jsonencode(local.access_param)");
    expect(main).toContain("jsonencode(local.access_cookie)");
    expect(outputs).toContain("local.access_param");
    expect(outputs).toContain("var.access_password");
  });
});
