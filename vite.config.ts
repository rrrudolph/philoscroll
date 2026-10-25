/// <reference types="vitest/config" />
import { defineConfig, loadEnv, type Connect, type Plugin } from "vite";
import { isAuthorized } from "./src/access.ts";

function accessSecret(secret: string | undefined): Plugin {
  const install = (middlewares: Connect.Server) => {
    if (!secret) return;
    middlewares.use((req, res, next) => {
      if (isAuthorized(req.headers["x-access-secret"], secret)) {
        next();
        return;
      }
      res.statusCode = 401;
      res.setHeader("content-type", "text/plain; charset=utf-8");
      res.end("Unauthorized");
    });
  };

  return {
    name: "access-secret",
    configureServer(server) {
      install(server.middlewares);
    },
    configurePreviewServer(server) {
      install(server.middlewares);
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const secret = process.env.ACCESS_SECRET || env.ACCESS_SECRET || undefined;
  return {
    plugins: [accessSecret(secret)],
    server: {
      port: 5173,
    },
    test: {
      environment: "happy-dom",
      include: ["src/**/*.test.ts", "infra/**/*.test.ts"],
    },
  };
});
