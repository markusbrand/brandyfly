import http from 'http';
import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright';

const PORT = 8088;
const WEB_DIR = path.resolve('/home/markus/Projects/brandyfly/apps/mobile/build/web');
const SCREENSHOT_DIR = process.env.SCREENSHOT_DIR
  ? path.resolve(process.env.SCREENSHOT_DIR)
  : path.resolve('/home/markus/.gemini/antigravity/brain/6a3f3994-108c-494e-9ee9-958b3d01597b');

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
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

  // 1. Initial State Screenshot (Live Dashboard)
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '01_dashboard_normal.png') });
  console.log('Step 1: Saved 01_dashboard_normal.png');

  // 2. Enter Edit Mode (Click Edit Note Icon at top right)
  console.log('Step 2: Entering Screen Configuration (Edit Mode)...');
  await page.mouse.click(1135, 30);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '02_screen_configuration_mode.png') });
  console.log('Step 2: Saved 02_screen_configuration_mode.png');

  // 3. Exit Edit Mode (Click Done Editing at bottom right)
  console.log('Step 3: Exiting Edit Mode...');
  await page.mouse.click(1200, 770);
  await page.waitForTimeout(1500);

  // 4. Open Top Navigation Menu (Click Hamburger Menu at top left: x: 25, y: 30)
  console.log('Step 4: Opening Top Navigation Drawer...');
  await page.mouse.click(25, 30);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '03_top_nav_menu.png') });
  console.log('Step 4: Saved 03_top_nav_menu.png');

  // 5. Open Flights Screen (Click Flights Button in Drawer: x: 395, y: 165)
  console.log('Step 5: Navigating to Flights & Logbook...');
  await page.mouse.move(395, 165);
  await page.mouse.down();
  await page.waitForTimeout(100);
  await page.mouse.up();
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '04_flights_logbook.png') });
  console.log('Step 5: Saved 04_flights_logbook.png');

  // 6. Start Flight Replay from Card (Click Replay Flight icon button in card: x: 1220, y: 280)
  console.log('Step 6: Starting Flight Replay...');
  await page.mouse.move(1220, 280);
  await page.mouse.down();
  await page.waitForTimeout(100);
  await page.mouse.up();
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '05_flight_replay_hud.png') });
  console.log('Step 6: Saved 05_flight_replay_hud.png');

  // 7. Open Menu and Navigate to UI Settings Panel
  console.log('Step 7: Opening Settings Panel...');
  await page.mouse.move(25, 30);
  await page.mouse.down();
  await page.waitForTimeout(100);
  await page.mouse.up();
  await page.waitForTimeout(1000);
  // Click Settings button in drawer: x: 600, y: 165
  await page.mouse.move(600, 165);
  await page.mouse.down();
  await page.waitForTimeout(100);
  await page.mouse.up();
  await page.waitForTimeout(2000);
  await page.screenshot({ path: path.join(SCREENSHOT_DIR, '06_ui_settings_panel.png') });
  console.log('Step 7: Saved 06_ui_settings_panel.png');

  await browser.close();
  server.close();
  console.log('All Playwright E2E verification steps completed successfully!');
}

runTest().catch((err) => {
  console.error('Playwright verification failed:', err);
  process.exit(1);
});
