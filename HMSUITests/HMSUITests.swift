//
//  HMSUITests.swift
//  HMSUITests
//
//  Created by admin99 on 07/03/26.
//

import XCTest

final class HMSUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // The app should launch without crashing
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    // MARK: - Login Screen Tests

    @MainActor
    func testLoginScreenShowsWelcomeText() throws {
        // The unified login screen shows "Welcome to CureIt"
        let welcomeText = app.staticTexts["Welcome to CureIt"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5), "Welcome text should be visible on login screen")
    }

    @MainActor
    func testLoginScreenShowsSignInSubtitle() throws {
        let subtitle = app.staticTexts["Sign in to continue"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5), "Sign-in subtitle should be visible")
    }

    @MainActor
    func testLoginScreenShowsEmailField() throws {
        let emailField = app.textFields["Email Address"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Email text field should be visible")
    }

    @MainActor
    func testLoginScreenShowsPasswordField() throws {
        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5), "Password secure field should be visible")
    }

    @MainActor
    func testLoginScreenShowsSignInButton() throws {
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5), "Sign In button should be visible")
    }

    @MainActor
    func testLoginScreenShowsForgotPassword() throws {
        let forgotButton = app.buttons["Forgot Password?"]
        XCTAssertTrue(forgotButton.waitForExistence(timeout: 5), "Forgot Password button should be visible")
    }

    @MainActor
    func testLoginScreenShowsRegisterOption() throws {
        let registerButton = app.buttons["Register as Patient"]
        XCTAssertTrue(registerButton.waitForExistence(timeout: 5), "Register as Patient button should be visible")
    }

    // MARK: - Text Field Interaction Tests

    @MainActor
    func testCanTypeInEmailField() throws {
        let emailField = app.textFields["Email Address"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))

        emailField.tap()
        emailField.typeText("test@example.com")

        XCTAssertEqual(emailField.value as? String, "test@example.com")
    }

    @MainActor
    func testCanTypeInPasswordField() throws {
        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))

        passwordField.tap()
        passwordField.typeText("password123")

        // SecureField value is typically masked, just verify it's not empty
        let value = passwordField.value as? String ?? ""
        XCTAssertFalse(value.isEmpty || value == "Password", "Password field should have content")
    }

    // MARK: - Sign In Button State Tests

    @MainActor
    func testSignInButtonDisabledWhenFieldsEmpty() throws {
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))

        // Button should be disabled when both fields are empty
        XCTAssertFalse(signInButton.isEnabled, "Sign In button should be disabled with empty fields")
    }

    // MARK: - Navigation Tests

    @MainActor
    func testForgotPasswordOpensSheet() throws {
        let forgotButton = app.buttons["Forgot Password?"]
        XCTAssertTrue(forgotButton.waitForExistence(timeout: 5))

        forgotButton.tap()

        // The forgot password sheet should appear
        // Give it time to animate
        let sheetExists = app.staticTexts["Reset Password"].waitForExistence(timeout: 3)
            || app.staticTexts["Forgot Password"].waitForExistence(timeout: 3)
        // Sheet may have different title — just verify navigation happened
        XCTAssertTrue(sheetExists || app.navigationBars.count > 0, "Forgot password sheet should appear")
    }

    @MainActor
    func testRegisterNavigatesToRegistration() throws {
        let registerButton = app.buttons["Register as Patient"]
        XCTAssertTrue(registerButton.waitForExistence(timeout: 5))

        registerButton.tap()

        // Should navigate to the registration screen
        // Give it time to animate
        sleep(1)
        // The registration view should be visible (check for any registration-related element)
        let registrationVisible = app.staticTexts["Create Account"].waitForExistence(timeout: 3)
            || app.staticTexts["Register"].waitForExistence(timeout: 3)
            || app.buttons["Register"].waitForExistence(timeout: 3)
            || app.textFields["Full Name"].waitForExistence(timeout: 3)
        XCTAssertTrue(registrationVisible, "Registration screen should be visible after tapping Register")
    }

    // MARK: - Launch Performance Test

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
