// End-to-end smoke test of the Flutter web build.
//
//   cd apps/mobile && flutter build web --release
//   cd test_e2e && npm install && node playwright_verification.mjs
//
// Uses the Flutter semantics tree (enabled in main.dart) to locate controls
// by their accessible labels, fails on any page error or Flutter exception
// logged to the console, and writes screenshots for visual review.
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { chromium } from 'playwright';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 8088);
const WEB_DIR = path.resolve(process.env.WEB_DIR || path.join(HERE, '..', 'build', 'web'));
const SCREENSHOT_DIR = path.resolve(
  process.env.SCREENSHOT_DIR || path.join(HERE, '..', 'build', 'e2e_screenshots'),
);
// Use the system Chrome when Playwright's bundled browsers are not installed.
const CHANNEL = process.env.PW_CHANNEL ?? 'chrome';

fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

if (!fs.existsSync(path.join(WEB_DIR, 'index.html'))) {
  console.error(`No web build at ${WEB_DIR}. Run "flutter build web" first.`);
  process.exit(2);
}

function startServer() {
  const mimeTypes = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.mjs': 'text/javascript',
    '.wasm': 'application/wasm',
    '.json': 'application/json',
    '.css': 'text/css',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
  };

  const server = http.createServer((req, res) => {
    let reqPath = decodeURIComponent(req.url.split('?')[0]);
    if (reqPath === '/') reqPath = '/index.html';
    const filePath = path.join(WEB_DIR, reqPath);
    if (!filePath.startsWith(WEB_DIR)) {
      res.writeHead(403);
      res.end();
      return;
    }
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      res.writeHead(200, {
        'Content-Type': mimeTypes[path.extname(filePath)] || 'application/octet-stream',
      });
      fs.createReadStream(filePath).pipe(res);
    } else {
      res.writeHead(404);
      res.end('Not Found');
    }
  });
  return new Promise((resolve) => server.listen(PORT, () => resolve(server)));
}

const errors = [];

async function shot(page, name) {
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, `${name}.png`) });
  console.log(`  screenshot ${name}.png`);
}

/** Locates a control in the Flutter semantics tree by role and name. */
function control(page, name, { exact = false } = {}) {
  return page
    .getByRole('button', { name, exact })
    .or(page.getByRole('checkbox', { name, exact }))
    .first();
}

async function clickLabel(page, name, opts = {}) {
  const locator = control(page, name, opts);
  await locator.waitFor({ state: 'visible', timeout: 10000 });
  await locator.click();
  await page.waitForTimeout(700);
}

async function expectLabel(page, name, opts = {}) {
  await control(page, name, opts).waitFor({ state: 'attached', timeout: 10000 });
}

async function runViewport(browser, name, viewport) {
  console.log(`\n== ${name} (${viewport.width}x${viewport.height})`);
  const page = await browser.newPage({ viewport });
  page.on('pageerror', (err) => errors.push(`[${name}] pageerror: ${err.message}`));
  page.on('console', (msg) => {
    const text = msg.text();
    if (msg.type() === 'error' || /EXCEPTION CAUGHT|RenderFlex overflowed/.test(text)) {
      // Network fetches of online map tiles may fail offline; ignore those.
      if (/Failed to load resource|net::ERR_/.test(text)) return;
      errors.push(`[${name}] console: ${text}`);
    }
  });

  await page.goto(`http://localhost:${PORT}`, { waitUntil: 'load' });
  await page.locator('flt-semantics-host').first().waitFor({ state: 'attached', timeout: 30000 });
  await page.waitForTimeout(4000);
  await shot(page, `${name}_01_flight`);

  console.log('  step: switch to map screen via navigation overlay');
  await clickLabel(page, 'Open navigation bar');
  await shot(page, `${name}_02_nav`);
  await clickLabel(page, 'Alpine Map Screen');
  await expectLabel(page, /^Zoom in/);

  console.log('  step: placed map controls');
  await clickLabel(page, /^Zoom in/);
  await clickLabel(page, /^Zoom out/);
  await clickLabel(page, /Recenter/);
  await shot(page, `${name}_03_map_controls`);

  console.log('  step: edit mode');
  await clickLabel(page, 'Open navigation bar');
  await clickLabel(page, 'Edit Mode');
  await expectLabel(page, /Done Editing|Save layout/);
  await clickLabel(page, /Select Zoom rocker widget/);
  await expectLabel(page, 'Configure Widget');
  await shot(page, `${name}_04_edit_selected`);
  await clickLabel(page, /Done Editing|Save layout/);
  await expectLabel(page, 'Open navigation bar');
  await shot(page, `${name}_05_after_edit`);

  await page.close();
}

async function run() {
  const server = await startServer();
  const browser = await chromium.launch({ headless: true, channel: CHANNEL || undefined });
  try {
    await runViewport(browser, 'phone_portrait', { width: 390, height: 844 });
    await runViewport(browser, 'tablet_landscape', { width: 1280, height: 800 });
  } finally {
    await browser.close();
    server.close();
  }
  if (errors.length) {
    console.error(`\n${errors.length} error(s):\n${errors.join('\n')}`);
    process.exit(1);
  }
  console.log('\nAll Playwright E2E verification steps passed.');
}

run().catch((err) => {
  console.error('Playwright verification failed:', err);
  process.exit(1);
});
