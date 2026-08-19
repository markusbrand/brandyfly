import http from 'http';
import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright';

const PORT = 8088;
const WEB_DIR = path.resolve('/home/markus/Projects/brandyfly/apps/mobile/build/web');
const SCREENSHOT_DIR = path.resolve('/home/markus/.gemini/antigravity-ide/brain/e12857ef-e90a-45e2-b854-723a8a2db1f4');

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
  };

  const server = http.createServer((req, res) => {
    let reqPath = req.url.split('?')[0];
    if (reqPath === '/') reqPath = '/index.html';
    const filePath = path.join(WEB_DIR, reqPath);

    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      const ext = path.extname(filePath);
      const contentType = mimeTypes[ext] || 'application/octet-stream';
      res.writeHead(200, {
        'Content-Type': contentType,
        'Cross-Origin-Embedder-Policy': 'require-corp',
        'Cross-Origin-Opener-Policy': 'same-origin',
      });
      fs.createReadStream(filePath).pipe(res);
    } else {
      res.writeHead(404);
      res.end('Not Found');
    }
  });

  return new Promise((resolve) => {
    server.listen(PORT, () => {
      console.log(`Server listening at http://localhost:${PORT}`);
      resolve(server);
    });
  });
}

async function runTest() {
  const server = await startServer();

  console.log('Launching Playwright browser...');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });

  console.log('Navigating to BrandyFly app...');
  await page.goto(`http://localhost:${PORT}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(4000);

  // 1. Initial State Screenshot
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '01_dashboard_normal.png') });
  console.log('Step 1: Saved 01_dashboard_normal.png');

  // 2. Click Edit Mode Icon in AppBar (x: 1180, y: 30)
  console.log('Step 2: Entering Screen Configuration (Edit Mode)...');
  await page.mouse.click(1180, 30);
  await page.waitForTimeout(1500);

  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '02_screen_configuration_mode.png') });
  console.log('Step 2: Saved 02_screen_configuration_mode.png');

  // 3. Resize Altitude Widget (W-): click W- at x: 556, y: 274
  console.log('Step 3: Resizing Altitude widget (W-)...');
  await page.mouse.click(556, 274);
  await page.waitForTimeout(1000);

  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '03_altitude_resized_w_minus.png') });
  console.log('Step 3: Saved 03_altitude_resized_w_minus.png');

  // 4. Reposition Altitude widget (Move Right >): click Move Right at x: 38, y: 274
  console.log('Step 4: Repositioning Altitude widget (Move Right >)...');
  await page.mouse.click(38, 274);
  await page.waitForTimeout(1000);

  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '04_altitude_moved_right.png') });
  console.log('Step 4: Saved 04_altitude_moved_right.png');

  // 5. Reposition Altitude widget (Move Down v): click Move Down at x: 380, y: 274 (now that it moved right to col 1)
  console.log('Step 5: Repositioning Altitude widget (Move Down v)...');
  await page.mouse.click(380, 274);
  await page.waitForTimeout(1000);

  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '05_altitude_moved_down.png') });
  console.log('Step 5: Saved 05_altitude_moved_down.png');

  // 6. Test Drag repositioning of Speed widget:
  // Drag Speed widget header from x: 700, y: 188 to x: 1050, y: 188
  console.log('Step 6: Drag-to-move Speed widget...');
  await page.mouse.move(700, 188);
  await page.mouse.down();
  await page.mouse.move(1050, 188, { steps: 15 });
  await page.mouse.up();
  await page.waitForTimeout(1000);

  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '06_speed_drag_moved.png') });
  console.log('Step 6: Saved 06_speed_drag_moved.png');

  // 7. Click Done Editing FAB at bottom right (x: 915, y: 775)
  console.log('Step 7: Finalizing Screen Configuration (Done Editing)...');
  await page.mouse.click(915, 775);
  await page.waitForTimeout(1500);

  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '07_final_persisted_dashboard.png') });
  console.log('Step 7: Saved 07_final_persisted_dashboard.png');

  await browser.close();
  server.close();
  console.log('All Playwright E2E verification steps completed successfully!');
}

runTest().catch((err) => {
  console.error('Playwright verification failed:', err);
  process.exit(1);
});
