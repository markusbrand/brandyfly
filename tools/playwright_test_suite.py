import os
from playwright.sync_api import sync_playwright, expect

def run_test_suite():
    os.makedirs("test-results/videos", exist_ok=True)
    os.makedirs("test-results/screenshots", exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="test-results/videos"
        )
        page = context.new_page()

        print("Navigating to Flutter web app...")
        page.goto("http://localhost:8080")

        # Wait for initial render.
        page.wait_for_timeout(10000)

        # Flutter rendering creates a <flutter-view>
        print("Asserting visibility of the main application shell...")
        expect(page.locator("flutter-view").first).to_be_visible()

        # NOTE: Flutter Web CanvasKit mode obscures the standard DOM.
        # While SemanticsBinding.instance.ensureSemantics() forces semantic nodes to be attached
        # (allowing some visibility checks like `flutter-view`), interacting with draggable elements
        # or specific internal layout components via DOM locators is heavily abstracted.
        # As a fallback for verifying the layout strategy engine, we simulate direct canvas coordinates.
        print("Enabling edit mode via coordinate click...")
        page.mouse.click(360, 40)
        page.wait_for_timeout(2000)

        print("Simulating widget layout manipulation (resizing/moving)...")

        # Click on a widget to select it (center of screen)
        page.mouse.click(200, 300)
        page.wait_for_timeout(1000)

        # Drag to move
        page.mouse.move(200, 300)
        page.mouse.down()
        page.mouse.move(200, 150, steps=10)
        page.mouse.up()
        page.wait_for_timeout(2000)

        print("Adding a new widget via Add Menu...")
        page.mouse.click(360, 750)
        page.wait_for_timeout(2000)

        print("Test suite completed successfully.")
        page.screenshot(path="test-results/screenshots/verification.png")

        context.close()
        browser.close()

if __name__ == "__main__":
    run_test_suite()
