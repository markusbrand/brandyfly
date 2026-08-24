import os
from playwright.sync_api import sync_playwright

def run_cuj(page):
    page.goto("http://localhost:8080")
    # Wait for flutter to load
    page.wait_for_timeout(10000)

    # Take screenshot at the key moment
    page.screenshot(path="test-results/screenshots/verification.png")
    page.wait_for_timeout(1000)

if __name__ == "__main__":
    os.makedirs("test-results/videos", exist_ok=True)
    os.makedirs("test-results/screenshots", exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="test-results/videos"
        )
        page = context.new_page()
        try:
            run_cuj(page)
        finally:
            context.close()
            browser.close()
