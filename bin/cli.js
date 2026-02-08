#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");

const PACKAGE_NAME = "bria-skills";
const SKILLS = ["bria-ai", "vgl", "image-utils"];

// Where the skill files live relative to this script
const packageRoot = path.resolve(__dirname, "..");
const skillsSource = path.join(packageRoot, "skills");
const pluginSource = path.join(packageRoot, ".claude-plugin");

// Target: ~/.claude/skills/bria-skills/
const claudeDir = path.join(os.homedir(), ".claude");
const targetDir = path.join(claudeDir, "skills", PACKAGE_NAME);

function copyDirSync(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function removeDirSync(dir) {
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function install() {
  console.log(`\nInstalling ${PACKAGE_NAME}...\n`);

  // Copy skills
  copyDirSync(skillsSource, path.join(targetDir, "skills"));

  // Copy .claude-plugin
  copyDirSync(pluginSource, path.join(targetDir, ".claude-plugin"));

  console.log(`Installed to: ${targetDir}\n`);
  console.log("Skills installed:");
  for (const skill of SKILLS) {
    console.log(`  - ${skill}`);
  }

  console.log(`\nTo use in Claude Code, add the skills to your project:\n`);
  console.log(`  claude /install ${targetDir}`);
  console.log(``);
  console.log(`Or add to your Claude Code settings (~/.claude/settings.json):\n`);
  console.log(`  {`);
  console.log(`    "skills": ["${targetDir}"]`);
  console.log(`  }`);
  console.log(``);
}

function uninstall() {
  console.log(`\nUninstalling ${PACKAGE_NAME}...\n`);
  removeDirSync(targetDir);
  console.log(`Removed: ${targetDir}`);
  console.log(`\nDon't forget to remove the skills reference from your Claude Code settings.\n`);
}

function printHelp() {
  console.log(`
${PACKAGE_NAME} - Bria AI skills for Claude Code

Usage:
  npx ${PACKAGE_NAME}              Install skills
  npx ${PACKAGE_NAME} install      Install skills
  npx ${PACKAGE_NAME} uninstall    Remove skills
  npx ${PACKAGE_NAME} --help       Show this help

Skills included:
  bria-ai       AI-powered image generation and editing (FIBO, RMBG-2.0)
  vgl           Visual Generation Language structured prompts
  image-utils   Classic image manipulation (resize, crop, composite)

More info: https://github.com/bria-ai/bria-skills
`);
}

// Parse command
const args = process.argv.slice(2);
const command = args[0] || "install";

switch (command) {
  case "install":
    install();
    break;
  case "uninstall":
  case "remove":
    uninstall();
    break;
  case "--help":
  case "-h":
  case "help":
    printHelp();
    break;
  default:
    console.error(`Unknown command: ${command}`);
    printHelp();
    process.exit(1);
}
