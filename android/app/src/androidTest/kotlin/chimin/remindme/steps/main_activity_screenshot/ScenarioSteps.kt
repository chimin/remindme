package chimin.remindme.steps.main_activity_screenshot

import chimin.remindme.*
import io.cucumber.java.en.Given
import io.cucumber.java.en.When
import io.cucumber.java.en.Then
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue

class ScenarioSteps {
    private val state = ScenarioContext()

    @io.cucumber.java.Before("@main_activity_screenshot")
    fun closePreviousFixture() {
        state.finishFixtureActivities()
    }

    @io.cucumber.java.After(value = "@main_activity_screenshot", order = 0)
    fun closeFixture() {
        state.finishFixtureActivities()
    }

    @io.cucumber.java.After(value = "@main_activity_screenshot", order = 1)
    fun captureFailure(scenario: io.cucumber.java.Scenario) {
        if (!scenario.isFailed) return
        val name = when {
            scenario.name.contains("legacy service") -> "widget_task_editor/widget_task_editor_when_opened_from_legacy_widget"
            scenario.name.startsWith("widgetTap") -> "widget_task_editor/widget_task_editor_when_opened_from_widget"
            scenario.name.contains("add task") -> "task_edit_screen/task_edit_screen_when_adding_task"
            else -> "task_home_screen/task_home_screen_when_four_dated_tasks_exist"
        }
        state.capture("${name}_FAILED.png")
    }

    @Given("the screenshot fixture is installed")
    fun theScreenshotFixtureIsInstalled(): Unit = with(state) {
        // This feature runs only against lib/main_screenshot.dart.
    }

    @When("the four dated task fixture is launched")
    fun theFourDatedTaskFixtureIsLaunched(): Unit = with(state) {
        launchFixture()
    }

    @Then("the task listing screenshot is saved")
    fun theTaskListingScreenshotIsSaved(): Unit = with(state) {
        capture("task_home_screen/task_home_screen_when_four_dated_tasks_exist.png")
    }

    @Given("the dated task listing is open")
    fun theDatedTaskListingIsOpen(): Unit = with(state) {
        launchFixture()
    }

    @When("the add task button is tapped and the keyboard is dismissed")
    fun theAddTaskButtonIsTappedAndTheKeyboardIsDismissed(): Unit = with(state) {
        // Use the extended FAB's accessible action label.
        val add = device.wait(Until.findObject(By.desc("Add task")), timeout)
        checkNotNull(add) { "Add task button was not accessible" }
        add.click()
        assertTrue("Add task screen did not open",
            device.wait(Until.hasObject(By.descContains("New task")), timeout))
        device.pressBack() // Dismiss the autofocus keyboard for the store screenshot.
        assertTrue(device.wait(Until.hasObject(By.descContains("New task")), timeout))
    }

    @Then("the add task screenshot is saved")
    fun theAddTaskScreenshotIsSaved(): Unit = with(state) {
        capture("task_edit_screen/task_edit_screen_when_adding_task.png")
    }

    @Given("the {word} widget navigation fixture is selected")
    fun selectWidgetFixture(kind: String): Unit = with(state) {
        legacyService = kind == "legacy"
        launchFixture()
        pinWidget()
        verifyWidget()
        publishLegacyViews()
    }

    @When("the first widget task is tapped after closing the activity")
    fun tapColdTask(): Unit = with(state) {
        finishFixtureActivities()
        device.pressHome()
        device.waitForIdle()
        findWidgetTask("Renew library books").click()
    }

    @Then("the first task editor opens with a save action and is captured")
    fun checkColdTask(): Unit = with(state) {
        assertTrue("Cold widget tap did not open the task editor",
            device.wait(Until.hasObject(By.descContains("Edit task")), timeout))
        assertTrue("Wrong task opened", device.wait(Until.hasObject(By.text("Renew library books")), timeout))
        assertTrue("Save action missing", device.wait(Until.hasObject(By.desc("Save task")), timeout))
        capture(if (legacyService) "widget_task_editor/widget_task_editor_when_opened_from_legacy_widget.png" else "widget_task_editor/widget_task_editor_when_opened_from_widget.png")
    }

    @When("the second widget task is tapped with the app running")
    fun tapWarmTask(): Unit = with(state) {
        publishLegacyViews()
        device.pressHome()
        device.waitForIdle()
        findWidgetTask("Pick up groceries").click()
    }

    @Then("the second task opens in the task editor")
    fun checkWarmTask(): Unit = with(state) {
        assertTrue(device.wait(Until.hasObject(By.descContains("Edit task")), timeout))
        assertTrue("Warm widget tap did not open the requested task",
            device.wait(Until.hasObject(By.text("Pick up groceries")), timeout))
    }

    @When("back is pressed from the widget task editor")
    fun pressBack(): Unit = with(state) {
        device.pressBack()
    }

    @Then("the task home opens without an older editor")
    fun checkHome(): Unit = with(state) {
        assertTrue("Back should return home rather than an older editor",
            device.wait(Until.hasObject(By.desc("Add task")), timeout))
    }
}
