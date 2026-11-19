#!/usr/bin/env node
"use strict";

const { execFileSync, spawnSync } = require("node:child_process");
const fs = require("node:fs");
const https = require("node:https");
const os = require("node:os");
const path = require("node:path");
const { pipeline } = require("node:stream/promises");
const { createWriteStream } = require("node:fs");

const pkg = require("../package.json");
const VERSION = pkg.version;
const APP_NAME = "Omnissa Beta Token Utility.app";
const ZIP_NAME = `Omnissa-Beta-Token-Utility-${VERSION}-macos.zip`;
const DOWNLOAD_URL =
  `https://github.com/judahtait/omnissa-beta-tokens/releases/download/v${VERSION}/${ZIP_NAME}`;

function destApp() {
  const homeApps = path.join(os.homedir(), "Applications", APP_NAME);
  const systemApps = path.join("/Applications", APP_NAME);
  if (fs.existsSync(systemApps)) return systemApps;
  return homeApps;
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const follow = (u, redirects = 0) => {
      if (redirects > 8) return reject(new Error("too many redirects"));
      https
        .get(u, { headers: { "User-Agent": "omnissa-beta-token-utility-npm" } }, (res) => {
          if (
            res.statusCode >= 300 &&
            res.statusCode < 400 &&
            res.headers.location
          ) {
            res.resume();
            return follow(res.headers.location, redirects + 1);
          }
          if (res.statusCode !== 200) {
            res.resume();
            return reject(
              new Error(`download failed: HTTP ${res.statusCode} for ${u}`)
            );
          }
          pipeline(res, createWriteStream(dest)).then(resolve).catch(reject);
        })
        .on("error", reject);
    };
    follow(url);
  });
}

async function main() {
  if (process.platform !== "darwin") {
    console.error("omnissa-beta-token-utility is macOS-only.");
    process.exit(1);
  }

  const target = destApp();
  const targetDir = path.dirname(target);
  fs.mkdirSync(targetDir, { recursive: true });

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "obt-npm-"));
  const zipPath = path.join(tmp, ZIP_NAME);
  const extractDir = path.join(tmp, "extract");
  fs.mkdirSync(extractDir);

  console.log(`Downloading ${ZIP_NAME}…`);
  await download(DOWNLOAD_URL, zipPath);

  console.log(`Installing to ${target}…`);
  execFileSync("ditto", ["-x", "-k", zipPath, extractDir], { stdio: "inherit" });
  const extracted = path.join(extractDir, APP_NAME);
  if (!fs.existsSync(extracted)) {
    throw new Error(`zip did not contain ${APP_NAME}`);
  }
  if (fs.existsSync(target)) {
    fs.rmSync(target, { recursive: true, force: true });
  }
  execFileSync("ditto", [extracted, target], { stdio: "inherit" });
  spawnSync("xattr", ["-dr", "com.apple.quarantine", target], { stdio: "ignore" });

  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(`Installed ${APP_NAME}`);
  console.log(`Open with: open "${target}"`);
  console.log(`Or run: omnissa-beta-token-utility`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
