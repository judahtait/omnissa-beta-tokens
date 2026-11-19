#!/usr/bin/env node
"use strict";

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const APP_NAME = "Omnissa Beta Token Utility.app";

function findApp() {
  const candidates = [
    path.join("/Applications", APP_NAME),
    path.join(os.homedir(), "Applications", APP_NAME),
  ];
  return candidates.find((p) => fs.existsSync(p));
}

function main() {
  if (process.platform !== "darwin") {
    console.error("omnissa-beta-token-utility is macOS-only.");
    process.exit(1);
  }

  let app = findApp();
  if (!app) {
    console.log("App not found — installing from GitHub release…");
    const installer = path.join(__dirname, "..", "scripts", "install-app.js");
    const r = spawnSync(process.execPath, [installer], { stdio: "inherit" });
    if (r.status !== 0) process.exit(r.status || 1);
    app = findApp();
  }
  if (!app) {
    console.error("Install finished but the app was not found.");
    process.exit(1);
  }

  const open = spawnSync("open", [app], { stdio: "inherit" });
  process.exit(open.status || 0);
}

main();
