#!/usr/bin/env node
// The fork's documentation site has a deliberately small, explicit input set.
// Never replace this with a recursive copy of the repository or a local Library.
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import MarkdownIt from "markdown-it";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const repository = "https://github.com/luvega/ScientificFigureLibrary";
const branch = "luvega";
const outputDirectory = path.join(repoRoot, "dist", "luvega-pages");

// Only these Markdown files are rendered. Linked files are never copied.
const pages = [
  { source: "README.luvega.zh-CN.md", output: "index.html", title: "项目说明", description: "luvega 版 Scientific Figure Library：本机图片与代码知识库、安装、模板复用及来源边界。" },
  { source: "website/install.zh-CN.md", output: "install.html", title: "安装与接入", description: "从 luvega 分支安装 SFL，启动本地图库界面并接入 Codex 等 stdio MCP 宿主。" },
  { source: "docs/REAL_DATA_CASES.zh-CN.md", output: "real-data.html", title: "检索与重新绘图", description: "按数据类型与作图目的检索，确认精确版本，材料化后由宿主独立重画。" },
  { source: "docs/PRIVATE_TEMPLATE_MIGRATION.zh-CN.md", output: "migration.html", title: "整理与迁移模板", description: "把自己的图与代码整理为本机模板，保留来源、运行证据和不可变发布版本。" },
  { source: "docs/FORK_MAINTENANCE.zh-CN.md", output: "maintenance.html", title: "同步维护", description: "维护 luvega fork、读取上游更新并保留定制功能，只向自己的 fork 推送。" },
];
// Explicit single-file copies only; no glob, directory copy or user asset input.
const assets = [
  { source: "website/site.css", output: "assets/site.css" },
  { source: "website/site.js", output: "assets/site.js" },
  { source: "docs/assets/logo.svg", output: "assets/logo.svg" },
];

function fail(message) { throw new Error(message); }
function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]);
}
function digest(value) { return createHash("sha256").update(value).digest("hex"); }
function insideRoot(absolute) {
  const relative = path.relative(repoRoot, absolute);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}
function assertNoSymlinks(absolute) {
  if (!insideRoot(absolute)) fail("Path escapes the repository boundary.");
  // Check the root and every existing component: junctions must not redirect reads
  // or the fixed output directory to private or external filesystem locations.
  let current = repoRoot;
  if (fs.lstatSync(current).isSymbolicLink()) fail("Repository root must not be a symlink.");
  for (const component of path.relative(repoRoot, absolute).split(path.sep).filter(Boolean)) {
    current = path.join(current, component);
    if (!fs.existsSync(current)) continue;
    if (fs.lstatSync(current).isSymbolicLink()) fail(`Symlink input or output is forbidden: ${path.relative(repoRoot, current)}`);
  }
}
function publicFile(relative) {
  const absolute = path.resolve(repoRoot, relative);
  assertNoSymlinks(absolute);
  if (!fs.statSync(absolute).isFile()) fail(`Expected a regular public source file: ${relative}`);
  return fs.readFileSync(absolute);
}
function githubUrl(relative, directory = false, suffix = "") {
  const encoded = relative.split("/").map(encodeURIComponent).join("/");
  return `${repository}/${directory ? "tree" : "blob"}/${branch}/${encoded}${suffix}`;
}
function linkTarget(raw, source) {
  if (/^(https?:|mailto:)/i.test(raw) || raw.startsWith("#")) return raw;
  if (/^[a-z][a-z0-9+.-]*:/i.test(raw) || raw.startsWith("//") || raw.startsWith("/")) {
    fail(`Unsupported absolute link in ${source}: ${raw}`);
  }
  const suffixAt = raw.search(/[?#]/);
  const pathname = suffixAt < 0 ? raw : raw.slice(0, suffixAt);
  const suffix = suffixAt < 0 ? "" : raw.slice(suffixAt);
  const absolute = path.resolve(repoRoot, path.dirname(source), decodeURIComponent(pathname));
  assertNoSymlinks(absolute);
  if (!fs.existsSync(absolute)) fail(`Missing link target in ${source}: ${raw}`);
  const relative = path.relative(repoRoot, absolute).split(path.sep).join("/");
  const page = pages.find((entry) => entry.source === relative);
  if (page) return page.output + suffix;
  // GitHub renders non-site Markdown, scripts and examples. It does not cause a
  // browser to download a naked local .md file or silently add it to Pages.
  return githubUrl(relative, fs.statSync(absolute).isDirectory(), suffix);
}
function inlineText(token) {
  return (token.children ?? []).map((child) => ["text", "code_inline", "image"].includes(child.type) ? child.content : ["softbreak", "hardbreak"].includes(child.type) ? " " : "").join("");
}
function slug(value) {
  return value.trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, "").replace(/\s/g, "-");
}

const packageJson = JSON.parse(publicFile("package.json").toString("utf8"));
const version = packageJson.version;
const sourceToHtml = new Map();
for (const page of pages) {
  const markdown = publicFile(page.source).toString("utf8");
  const md = new MarkdownIt({ html: false, linkify: false, typographer: false });
  const tokens = md.parse(markdown, {});
  const usedIds = new Set();
  const headings = [];
  for (let index = 0; index < tokens.length; index++) {
    const token = tokens[index];
    if (token.type === "heading_open") {
      const text = inlineText(tokens[index + 1]);
      const base = slug(text) || "section";
      let id = base;
      let suffix = 0;
      while (usedIds.has(id)) id = `${base}-${++suffix}`;
      usedIds.add(id);
      token.attrSet("id", id);
      tokens[index + 2].meta = { id };
      headings.push({ level: Number(token.tag.slice(1)), text, id });
    }
    for (const child of token.children ?? []) {
      if (child.type === "image") fail(`Documentation images require a reviewed explicit allowlist: ${page.source}`);
      if (child.type === "link_open") child.attrSet("href", linkTarget(child.attrGet("href") ?? "", page.source));
    }
  }
  if (headings.filter((heading) => heading.level === 1).length !== 1) fail(`Expected one document title: ${page.source}`);
  md.renderer.rules.heading_close = (renderTokens, index) => {
    const token = renderTokens[index];
    return (token.tag !== "h1" ? `<a class="heading-anchor" href="#${escapeHtml(token.meta.id)}" aria-label="此节链接">#</a>` : "") + `</${token.tag}>\n`;
  };
  md.renderer.rules.fence = (renderTokens, index) => {
    const token = renderTokens[index];
    const language = token.info.trim().split(/\s+/)[0] || "text";
    return `<div class="code-block"><div class="code-toolbar"><span>${escapeHtml(language)}</span><button class="copy-code" type="button" aria-label="复制代码">复制代码</button></div><pre><code>${escapeHtml(token.content)}</code></pre></div>\n`;
  };
  md.renderer.rules.table_open = () => '<div class="table-scroll"><table>\n';
  md.renderer.rules.table_close = () => "</table></div>\n";
  sourceToHtml.set(page.source, { content: md.renderer.render(tokens, md.options, {}), headings, sha256: digest(Buffer.from(markdown)) });
}

const rendered = new Map();
for (let index = 0; index < pages.length; index++) {
  const page = pages[index];
  const { content, headings } = sourceToHtml.get(page.source);
  const nav = pages.map((entry) => `<a href="${entry.output}"${entry.output === page.output ? ' aria-current="page"' : ""}>${escapeHtml(entry.title)}</a>`).join("\n");
  const toc = headings.filter((heading) => heading.level === 2 || heading.level === 3).map((heading) => `<li class="toc-level-${heading.level}"><a href="#${escapeHtml(heading.id)}">${escapeHtml(heading.text)}</a></li>`).join("\n");
  const previous = pages[index - 1];
  const next = pages[index + 1];
  const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHtml(page.description)}">
  <meta name="color-scheme" content="light">
  <title>${escapeHtml(page.title)} · SFL luvega</title>
  <link rel="icon" href="assets/logo.svg" type="image/svg+xml">
  <link rel="stylesheet" href="assets/site.css">
  <script src="assets/site.js" defer></script>
</head>
<body>
  <a class="skip-link" href="#main-content">跳至正文</a>
  <header class="site-header"><div class="header-inner">
    <a class="brand" href="index.html"><img src="assets/logo.svg" alt="" width="32" height="32"><span><strong>Scientific Figure Library</strong><small>luvega fork · 中文使用文档</small></span></a>
    <div class="header-links"><span class="version-badge">基线 ${escapeHtml(version)}</span><a href="${repository}/tree/${branch}">GitHub ↗</a><a class="upstream-link" href="https://github.com/xuzhougeng/ScientificFigureLibrary">上游项目 ↗</a></div>
  </div></header>
  <div class="page-grid">
    <aside class="sidebar" aria-label="文档导航"><p class="sidebar-label">luvega documentation</p><nav>${nav}</nav>
      <div class="sidebar-extra"><p class="sidebar-label">公开资料</p><a href="${githubUrl("examples/single-cell/README.md")}">38 个历史公开模板 ↗</a><a href="${githubUrl("examples/single-cell/LICENSE_NOTICE.md")}">模板许可与来源 ↗</a><a href="${githubUrl("docs/USER_GUIDE.zh-CN.md")}">完整用户手册 ↗</a></div>
      <p class="sidebar-note">公开站点只提供说明。<br>私有案例、研究数据和本机图库保留在使用者电脑上。</p>
    </aside>
    <main class="document" id="main-content">
      <div class="doc-meta"><span>luvega / ${escapeHtml(page.title)}</span><a href="${githubUrl(page.source)}">查看本文源文件 ↗</a></div>
      <div class="fork-intro"><p><strong>luvega 定制版</strong> · 使用 <code>luvega</code> 分支。SFL 保存和检索图与代码，实际 R/Python 绘图由外部宿主在本机执行。</p></div>
      <article class="markdown">${content}</article>
      <nav class="page-pagination" aria-label="相邻文档">${previous ? `<a href="${previous.output}">← ${escapeHtml(previous.title)}</a>` : "<span></span>"}${next ? `<a href="${next.output}">${escapeHtml(next.title)} →</a>` : "<span></span>"}</nav>
    </main>
    <aside class="page-toc" aria-label="本文目录"><details open><summary>本文目录</summary><ol>${toc}</ol></details></aside>
  </div>
  <footer class="site-footer"><p>Scientific Figure Library · <a href="${repository}">luvega fork</a> · <a href="${githubUrl("LICENSE")}">原项目许可证</a> · <a href="${githubUrl("THIRD_PARTY_NOTICES.md")}">第三方说明</a></p><p>文档随 luvega 分支更新；研究数据、私有运行包与审批回执不在网站中分发。</p></footer>
</body>
</html>
`;
  rendered.set(page.output, Buffer.from(html));
}
for (const asset of assets) rendered.set(asset.output, publicFile(asset.source));
rendered.set(".nojekyll", Buffer.from(""));

// Reject accidental local-machine disclosure before writing any public output.
const privatePatterns = [
  /\b[A-Z]:[\\/](?:Codex_Projects|ScientificFigureData|Users)[\\/]/i,
  /(?:["'\/]|^)private-templates[\\/]/i,
  /(?:["'\/]|^)KS-codes[\\/]/i,
  /file:\/\//i,
];
for (const [filename, bytes] of rendered) {
  if (privatePatterns.some((pattern) => pattern.test(bytes.toString("utf8")))) fail(`Private filesystem reference in site output: ${filename}`);
}

// Verify all generated local navigation and anchors, independently of the source
// Markdown checker. External GitHub links stay links and are not fetched here.
const documentIds = new Map();
for (const page of pages) {
  const html = rendered.get(page.output).toString("utf8");
  const ids = Array.from(html.matchAll(/\bid="([^"]+)"/g), (match) => match[1]);
  if (new Set(ids).size !== ids.length) fail(`Duplicate HTML id in ${page.output}`);
  documentIds.set(page.output, new Set(ids));
}
let localLinks = 0;
for (const page of pages) {
  const html = rendered.get(page.output).toString("utf8");
  for (const match of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    const href = match[1];
    if (/^(https?:|mailto:)/i.test(href)) continue;
    const url = new URL(href, `https://documentation.invalid/${page.output}`);
    const target = decodeURIComponent(url.pathname.slice(1));
    if (!rendered.has(target)) fail(`Broken generated local target: ${page.output} -> ${href}`);
    if (url.hash && !documentIds.get(target)?.has(decodeURIComponent(url.hash.slice(1)))) fail(`Broken generated anchor: ${page.output} -> ${href}`);
    localLinks++;
  }
}

const manifest = {
  schemaVersion: 1,
  repository,
  branch,
  baselineVersion: version,
  scope: "Public documentation only; no figure data, private cases, Library contents or approval receipts.",
  sources: [...pages, ...assets].map((entry) => ({ path: entry.source, output: entry.output, sha256: digest(publicFile(entry.source)) })),
  files: Array.from(rendered, ([filename, bytes]) => ({ path: filename, bytes: bytes.length, sha256: digest(bytes) })).sort((a, b) => a.path.localeCompare(b.path)),
};
rendered.set("site-manifest.json", Buffer.from(JSON.stringify(manifest, null, 2) + "\n"));

// The recursive removal target is a fixed, checked directory beneath repo/dist;
// callers cannot override it, and neither dist nor its parents may be symlinks.
if (path.resolve(outputDirectory) !== path.resolve(repoRoot, "dist", "luvega-pages")) fail("Unexpected output directory.");
assertNoSymlinks(outputDirectory);
if (fs.existsSync(outputDirectory)) fs.rmSync(outputDirectory, { recursive: true });
fs.mkdirSync(outputDirectory, { recursive: true });
for (const [filename, bytes] of rendered) {
  const absolute = path.resolve(outputDirectory, filename);
  if (!absolute.startsWith(outputDirectory + path.sep)) fail("Invalid output filename.");
  fs.mkdirSync(path.dirname(absolute), { recursive: true });
  fs.writeFileSync(absolute, bytes);
}
console.log(`Built ${pages.length} public documentation pages into dist/luvega-pages/`);
console.log(`Verified ${localLinks} generated local links/anchors; ${rendered.size} allowlisted output files.`);
console.log("No recursive input copies, private assets, template datasets or plotting execution.");
