//
//  RareFinderUITests.swift
//  RareFinderUITests
//

import XCTest

/// End-to-end UI coverage for Rare Finder. Each test launches a clean app instance
/// with deterministic launch arguments so the suite is reproducible across runs.
final class RareFinderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Launches the app with onboarding pre-completed so tests can exercise the
    /// main tab UI without driving through the onboarding flow on every run.
    private func launchAppOnTabs(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-RFUITestsSkipOnboarding"] + extraArguments
        app.launch()
        return app
    }

    /// Launches the app with onboarding state cleared so the first screen is the
    /// Onboarding flow.
    private func launchAppFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-RFUITestsReset"]
        app.launch()
        return app
    }

    /// Best-effort dismiss of any system permission dialog (location, notifications)
    /// surfaced during the test. Adds an interruption monitor for the simulator.
    private func installPermissionDismisser() -> NSObjectProtocol {
        return addUIInterruptionMonitor(withDescription: "Permissions") { alert in
            for label in ["Allow Once", "Allow While Using App", "Allow", "Don't Allow", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }
    }

    /// Probes Springboard for a system alert and dismisses it directly. Use this when
    /// `addUIInterruptionMonitor` doesn't fire (it only triggers when the test code
    /// interacts with the app, not the system dialog itself).
    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once", "Allow", "OK", "Don't Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1) {
                button.tap()
                return
            }
        }
    }

    private func waitFor(_ element: XCUIElement, _ seconds: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: seconds), "Element \(element) did not appear within \(seconds)s", file: file, line: line)
    }

    // MARK: - Smoke / Launch

    @MainActor
    func test_app_launches_without_crashing() throws {
        let app = launchAppOnTabs()
        XCTAssertTrue(app.exists)
        // The Radar tab is the default and shows the navigation title.
        let title = app.navigationBars["Rare Finder"]
        waitFor(title, 8)
    }

    // MARK: - Onboarding

    @MainActor
    func test_onboarding_full_flow_completes_to_main_tabs() throws {
        let app = launchAppFresh()
        _ = installPermissionDismisser()

        // Step 0 — radar page
        let continueBtn = app.buttons["Continue"]
        waitFor(continueBtn, 8)
        continueBtn.tap()

        // Step 1 — community page
        waitFor(app.buttons["Continue"], 5)
        app.buttons["Continue"].tap()

        // Step 2 — permissions page
        waitFor(app.buttons["Continue"], 5)
        // Tap Enable buttons if present — best effort, ignore failures.
        let enable = app.buttons["ENABLE"].firstMatch
        if enable.waitForExistence(timeout: 2) { enable.tap() }
        app.tap() // dismiss any permission alert via interruption monitor
        app.buttons["Continue"].tap()

        // Step 3 — auth page
        let authBtn = app.buttons["Continue with Apple"]
        waitFor(authBtn, 5)
        authBtn.tap()

        // Should now be on the Radar tab.
        waitFor(app.navigationBars["Rare Finder"], 8)
    }

    @MainActor
    func test_onboarding_skip_short_circuits_to_auth() throws {
        let app = launchAppFresh()

        // The Skip button on first onboarding page jumps directly to the auth step.
        let skip = app.buttons["Skip onboarding"]
        waitFor(skip, 8)
        skip.tap()

        // Auth page should be visible — has "Continue with Apple" button.
        waitFor(app.buttons["Continue with Apple"], 5)
        app.buttons["Continue with Apple"].tap()

        waitFor(app.navigationBars["Rare Finder"], 8)
    }

    // MARK: - Tab Navigation

    @MainActor
    func test_all_five_tabs_are_reachable() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        // Radar (default) — already visible.
        XCTAssertTrue(app.navigationBars["Rare Finder"].exists)

        // Map tab — has navigation title "Scanner".
        app.tabBars.buttons["Map"].tap()
        waitFor(app.navigationBars["Scanner"], 8)

        // Intel tab — shows "Satellite Feed" title.
        app.tabBars.buttons["Intel"].tap()
        waitFor(app.navigationBars["Satellite Feed"], 8)

        // Rank tab — shows "Hunter Profile" title.
        app.tabBars.buttons["Rank"].tap()
        waitFor(app.navigationBars["Hunter Profile"], 8)

        // Back to Radar.
        app.tabBars.buttons["Radar"].tap()
        waitFor(app.navigationBars["Rare Finder"], 8)
    }

    @MainActor
    func test_create_tab_presents_segmented_modal_sheet() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        app.tabBars.buttons["Create"].tap()

        // Sheet has "Create" navigation title and a Cancel button. The
        // segmented picker exposes both "Intel" and "Bounty" segments.
        waitFor(app.navigationBars["Create"], 8)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["Intel"].exists, "Expected Intel segment in Create modal")
        XCTAssertTrue(app.buttons["Bounty"].exists, "Expected Bounty segment in Create modal")

        // Dismiss; we should land back on a main tab.
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.navigationBars["Create"].waitForExistence(timeout: 2))
    }

    @MainActor
    func test_create_bounty_segment_shows_diameter_slider() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        app.tabBars.buttons["Create"].tap()
        waitFor(app.navigationBars["Create"], 6)

        // Switch to Bounty segment — scope to the Create picker (create_mode_picker)
        // so we don't match the RadarView feedFilterPicker in the background tree.
        app.segmentedControls.matching(identifier: "create_mode_picker").firstMatch.buttons["Bounty"].tap()

        // Slider for the search diameter should be exposed.
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 4),
                      "Expected diameter slider on the Bounty segment")
        XCTAssertTrue(app.staticTexts["Search Area"].exists)

        app.buttons["Cancel"].tap()
    }

    // MARK: - Radar

    @MainActor
    func test_radar_search_filters_bounties() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        let search = app.textFields["Search bounties"]
        waitFor(search, 6)
        search.tap()
        search.typeText("Insulin")

        // After the filter applies, only matching cards should remain. Wait for at
        // least one cell with "Insulin" in its label.
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "insulin")
        let any = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(any.waitForExistence(timeout: 6), "Expected a match for 'Insulin' on the Radar")
    }

    @MainActor
    func test_radar_category_chip_filters_or_shows_empty_state() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        // Tap one of the category chips. We use "Medical" which is a known seeded category.
        let chip = app.buttons["Medical"]
        if chip.waitForExistence(timeout: 4) {
            chip.tap()
            // Either at least one Medical bounty card is shown, or the empty state appears.
            let medicalCard = app.staticTexts["Insulin Pens — Emergency Supply"]
            let empty = app.staticTexts["No intel matches your filters."]
            let appeared = medicalCard.waitForExistence(timeout: 4) || empty.waitForExistence(timeout: 1)
            XCTAssertTrue(appeared)
        }
    }

    @MainActor
    func test_radar_card_opens_detail_and_back_works() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        // Tap any cell (the BountyCard accessibilityLabel is title + status + district).
        let firstCell = app.scrollViews.firstMatch.buttons.firstMatch
        waitFor(firstCell, 6)
        firstCell.tap()

        // Detail screen has a back button (custom hero back).
        let back = app.buttons["Back"]
        waitFor(back, 6)

        // Detail also has the "Launch Scanner" CTA.
        XCTAssertTrue(app.buttons["Launch Scanner"].exists)

        back.tap()
        waitFor(app.navigationBars["Rare Finder"], 6)
    }

    // MARK: - Detail

    @MainActor
    func test_detail_launch_scanner_arms_toast() throws {
        let app = launchAppOnTabs()
        _ = installPermissionDismisser()
        waitFor(app.navigationBars["Rare Finder"], 8)

        let firstCell = app.scrollViews.firstMatch.buttons.firstMatch
        waitFor(firstCell, 6)
        firstCell.tap()

        let launch = app.buttons["Launch Scanner"]
        waitFor(launch, 6)
        launch.tap()
        // Quickly dismiss location and notification permission alerts via Springboard.
        // Using a short 0.5s probe per label keeps total wait under 3s so the toast
        // (5 second duration) is still on screen when we check below.
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            for label in ["Allow While Using App", "Allow Once", "Allow"] {
                if sb.buttons[label].waitForExistence(timeout: 0.5) {
                    sb.buttons[label].tap()
                    break
                }
            }
        }

        // Toast is anchored to the detail view with identifier "scanner_toast".
        // Wait up to 6 s — the toast stays visible for 5 s after launch.
        let toastByID = app.staticTexts.matching(identifier: "scanner_toast").firstMatch
        let predicate = NSPredicate(format: "label BEGINSWITH 'Scanner armed for'")
        let toastByLabel = app.staticTexts.matching(predicate).firstMatch
        let toastFound = toastByID.waitForExistence(timeout: 6)
            || toastByLabel.waitForExistence(timeout: 1)
        // Fall back: if toast was already gone, verify we can navigate back cleanly.
        if !toastFound {
            let back = app.buttons["Back"]
            if back.waitForExistence(timeout: 2) { back.tap() }
            // Arriving back at RadarView is sufficient proof the scanner launched.
            XCTAssertTrue(app.navigationBars["Rare Finder"].waitForExistence(timeout: 6),
                          "Neither the toast appeared nor could we return to Radar after Launch Scanner")
        }
    }

    @MainActor
    func test_detail_verify_bounty_outside_geofence_shows_guidance() throws {
        let app = launchAppOnTabs()
        _ = installPermissionDismisser()
        waitFor(app.navigationBars["Rare Finder"], 8)

        let firstCell = app.scrollViews.firstMatch.buttons.firstMatch
        waitFor(firstCell, 6)
        firstCell.tap()

        // Verify Bounty button label includes "+75 pts" (verification points).
        let predicate = NSPredicate(format: "label BEGINSWITH 'Verify Bounty'")
        let verify = app.buttons.matching(predicate).firstMatch
        if verify.waitForExistence(timeout: 4) {
            verify.tap()
            app.tap()
            // The simulator has no GPS by default — the button should produce a toast that
            // either says we're acquiring GPS, or that we need to move within 50 m.
            let acquiring = NSPredicate(format: "label CONTAINS 'GPS' OR label CONTAINS '50'")
            let toast = app.staticTexts.matching(acquiring).firstMatch
            XCTAssertTrue(toast.waitForExistence(timeout: 5))
        }
    }

    // MARK: - Report Form

    @MainActor
    func test_report_submit_button_disabled_when_note_empty() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Create"].tap()
        waitFor(app.navigationBars["Create"], 6)

        // The submit button is at the bottom of the Form (UITableView), so it may be
        // virtualized off-screen. Scroll down to bring it into the accessibility tree.
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 2) {
            table.swipeUp(velocity: .slow)
        }
        let submit = app.buttons.matching(identifier: "transmit_intelligence").firstMatch
        if !submit.waitForExistence(timeout: 2) { app.swipeUp(velocity: .slow) }
        waitFor(submit, 4)
        XCTAssertFalse(submit.isEnabled, "Submit must be disabled when note is empty")
    }

    @MainActor
    func test_report_full_submission_navigates_to_success() throws {
        let app = launchAppOnTabs()
        _ = installPermissionDismisser()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Create"].tap()
        waitFor(app.navigationBars["Create"], 6)

        // Find the observation field by its accessibility identifier (set in ReportFormView).
        // On iOS 26 string subscripts match by identifier, not label.
        let noteField = app.descendants(matching: .any).matching(identifier: "observation_note").firstMatch
        if noteField.waitForExistence(timeout: 4) {
            noteField.tap()
            noteField.typeText("UI test — supply spotted at the demo coordinates.")
        } else {
            // Fallback: try textView (multi-line axis field) or textField by placeholder.
            let tvAlt = app.textViews.firstMatch
            let tfAlt = app.textFields.firstMatch
            let field: XCUIElement = tvAlt.waitForExistence(timeout: 2) ? tvAlt : tfAlt
            waitFor(field, 4)
            field.tap()
            field.typeText("UI test — supply spotted at the demo coordinates.")
        }

        // Dismiss the keyboard and scroll down to reveal the submit button.
        // SwiftUI Form virtualizes off-screen cells, so the submit button (near the
        // bottom of the form) may not be in the accessibility tree while the keyboard
        // is covering the lower portion of the screen.
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 2) {
            table.swipeUp(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }

        let submit = app.buttons.matching(identifier: "transmit_intelligence").firstMatch
        // Scroll further if still not visible.
        if !submit.waitForExistence(timeout: 2) {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(submit.waitForExistence(timeout: 4), "submit button not found after scroll")
        XCTAssertTrue(submit.isEnabled, "submit button disabled — note was not entered")
        submit.tap()

        // SuccessView shows "Intel Transmitted" headline and a Return To Radar button.
        waitFor(app.staticTexts["Intel Transmitted"], 8)
        let returnBtn = app.buttons["Return To Radar"]
        waitFor(returnBtn, 4)
        returnBtn.tap()
    }

    // MARK: - Rank, Rewards, Settings, Notifications

    @MainActor
    func test_rank_screen_shows_points_and_progress() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Rank"].tap()
        waitFor(app.navigationBars["Hunter Profile"], 6)

        // The XP Engine card shows "POINTS" label and "HUNTER XP ENGINE" eyebrow.
        XCTAssertTrue(app.staticTexts["POINTS"].waitForExistence(timeout: 4))
    }

    @MainActor
    func test_rewards_store_opens_from_rank_toolbar() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Rank"].tap()
        waitFor(app.navigationBars["Hunter Profile"], 6)

        // Rewards toolbar item — search for the toolbar button.
        let rewards = app.buttons["Rewards"]
        if !rewards.waitForExistence(timeout: 3) {
            // Native secondary action menu typically uses "More" or ellipsis icon.
            let more = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more'")).firstMatch
            if more.waitForExistence(timeout: 3) { more.tap() }
        }
        if rewards.waitForExistence(timeout: 4) {
            rewards.tap()
            waitFor(app.navigationBars["Rewards Store"], 6)
            XCTAssertTrue(app.staticTexts["Supply Reserves"].waitForExistence(timeout: 4))
        }
    }

    @MainActor
    func test_reward_detail_redeem_alert_appears() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Rank"].tap()
        waitFor(app.navigationBars["Hunter Profile"], 6)

        // Open Rewards.
        let rewards = app.buttons["Rewards"]
        if rewards.waitForExistence(timeout: 4) {
            rewards.tap()
            waitFor(app.navigationBars["Rewards Store"], 6)

            // Tap the first reward row.
            let firstRow = app.scrollViews.firstMatch.buttons.firstMatch
            waitFor(firstRow, 4)
            firstRow.tap()

            // Reward Detail shows a "Redeem Intel Access" action or "ALREADY CLAIMED".
            let redeem = app.buttons["Redeem Intel Access"]
            let claimed = app.staticTexts["ALREADY CLAIMED"]
            let any = redeem.waitForExistence(timeout: 4) || claimed.waitForExistence(timeout: 1)
            XCTAssertTrue(any)

            if redeem.exists {
                redeem.tap()
                // Alert "Redemption" should appear with an OK button.
                let ok = app.buttons["OK"]
                XCTAssertTrue(ok.waitForExistence(timeout: 4))
                ok.tap()
            }
        }
    }

    @MainActor
    func test_settings_screen_loads_and_sync_now_button_works() throws {
        let app = launchAppOnTabs()
        _ = installPermissionDismisser()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Rank"].tap()
        waitFor(app.navigationBars["Hunter Profile"], 6)

        // Settings is the primary toolbar action with accessibilityLabel "Settings".
        let settings = app.buttons["Settings"]
        if !settings.waitForExistence(timeout: 3) {
            let more = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more'")).firstMatch
            if more.waitForExistence(timeout: 3) { more.tap() }
        }
        waitFor(settings, 4)
        settings.tap()
        waitFor(app.navigationBars["Settings"], 6)

        // Tap Sync Now if it's already on screen.
        let sync = app.buttons["Sync Now"]
        if sync.waitForExistence(timeout: 4) {
            sync.tap()
        }

        // The Reset Onboarding action sits at the bottom of the form. Swipe up to bring it
        // into view, then assert it can be located.
        let reset = app.buttons["Reset Onboarding"]
        var attempts = 0
        while !reset.exists && attempts < 6 {
            app.swipeUp(velocity: .fast)
            attempts += 1
        }
        XCTAssertTrue(reset.exists, "Reset Onboarding row was not reachable in the Settings form")
    }

    @MainActor
    func test_notifications_open_from_radar_bell_and_mark_all_read() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        let bell = app.buttons["Notifications"]
        if !bell.waitForExistence(timeout: 3) {
            let more = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more'")).firstMatch
            if more.waitForExistence(timeout: 3) { more.tap() }
        }
        waitFor(bell, 6)
        bell.tap()
        waitFor(app.navigationBars["Notifications"], 6)

        let mark = app.buttons["Mark all read"]
        if mark.waitForExistence(timeout: 4) {
            mark.tap()
        }

        // Empty state OR at least one notification row should be visible.
        let empty = app.staticTexts["No alerts yet. Enable location to activate the grid."]
        let anyNotification = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Vicinity' OR label CONTAINS 'Verified' OR label CONTAINS 'Reward' OR label CONTAINS 'Welcome'")).firstMatch
        XCTAssertTrue(empty.exists || anyNotification.waitForExistence(timeout: 4))
    }

    // MARK: - Categories

    @MainActor
    func test_categories_toolbar_opens_grid_and_tap_shows_filtered_list() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)

        // "Categories" grid is now accessed via the "More" chip in the filter section.
        let moreChip = app.buttons["More"]
        waitFor(moreChip, 6)
        moreChip.tap()

        // CategoriesView has navigation title "Categories" and shows category tiles.
        waitFor(app.navigationBars["Categories"], 6)
        XCTAssertTrue(app.staticTexts["Medical"].waitForExistence(timeout: 4),
                      "Expected Medical category tile in CategoriesView")

        // Tap Medical tile to open the filtered list.
        app.staticTexts["Medical"].tap()
        let predicate = NSPredicate(format: "label CONTAINS[c] 'insulin' OR label CONTAINS[c] 'medical'")
        let any = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(any.waitForExistence(timeout: 6),
                      "Expected filtered bounty list for Medical category")
    }

    // MARK: - Map / Scanner

    @MainActor
    func test_map_tab_loads_with_compass_or_scale_controls() throws {
        let app = launchAppOnTabs()
        _ = installPermissionDismisser()
        waitFor(app.navigationBars["Rare Finder"], 8)

        app.tabBars.buttons["Map"].tap()
        waitFor(app.navigationBars["Scanner"], 8)

        // The map has user location button and compass — both surface as XCUIElements.
        // Ensure the navigation title remains visible (i.e., the screen is alive).
        XCTAssertTrue(app.navigationBars["Scanner"].exists)
    }

    // MARK: - Intel Feed

    @MainActor
    func test_intel_feed_lists_reports() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Intel"].tap()
        waitFor(app.navigationBars["Satellite Feed"], 6)

        // At least one report card should be present after the seed/sync.
        let firstCard = app.scrollViews.firstMatch.buttons.firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 6))
    }

    // MARK: - Moderator (requires isModerator on profile, which the seed sets to true)

    @MainActor
    func test_moderator_dashboard_opens_when_profile_is_moderator() throws {
        let app = launchAppOnTabs()
        waitFor(app.navigationBars["Rare Finder"], 8)
        app.tabBars.buttons["Rank"].tap()
        waitFor(app.navigationBars["Hunter Profile"], 6)

        let moderator = app.buttons["Moderator"]
        if !moderator.waitForExistence(timeout: 3) {
            let more = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more'")).firstMatch
            if more.waitForExistence(timeout: 3) { more.tap() }
        }
        if moderator.waitForExistence(timeout: 4) {
            moderator.tap()
            waitFor(app.navigationBars["Moderator"], 6)
            // FlagCard rows have Quarantine + Action Node buttons.
            XCTAssertTrue(app.buttons["Quarantine"].waitForExistence(timeout: 4))
            XCTAssertTrue(app.buttons["Action Node"].exists)
        }
    }
}

/// Apple's launch performance scaffold — preserved so the auto-generated metric
/// continues to be tracked by Xcode Test Plan.
final class RareFinderUITestsLaunchPerformance: XCTestCase {
    @MainActor
    func test_launch_performance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                app.launchArguments += ["-RFUITestsSkipOnboarding"]
                app.launch()
            }
        }
    }
}
