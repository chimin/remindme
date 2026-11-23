package chimin.remindme.steps.home_screen_widget

import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import chimin.remindme.R
import chimin.remindme.TaskWidgetProvider
import io.cucumber.java.After
import io.cucumber.java.Before
import io.cucumber.java.Scenario
import io.cucumber.java.en.Given
import io.cucumber.java.en.When
import io.cucumber.java.en.Then
import org.junit.Assert.assertTrue

class ScenarioSteps {
    private val state = ScenarioContext()

    @Before("@home_screen_widget")
    fun rememberPreferences(scenario: Scenario) {
        state.screenshotName = when {
            scenario.name.contains("empty state") -> "home_screen_widget_when_empty"
            scenario.name.contains("appearance settings") -> "home_screen_widget_when_appearance_is_updated"
            scenario.name.contains("categories") -> "home_screen_widget_when_categories_are_shown"
            else -> "home_screen_widget_when_four_dated_tasks_exist"
        }
        state.rememberPreferences()
    }

    @After(value = "@home_screen_widget", order = 1)
    fun captureFailure(scenario: Scenario) {
        if (scenario.isFailed) state.captureWidget(failed = true)
    }

    @After(value = "@home_screen_widget", order = 0)
    fun restorePreferences() {
        state.restorePreferences()
    }

    @Given("four dated fixture tasks are available for the launcher")
    fun prepareDatedTasks() {
        state.launchFixture()
    }

    @When("widget pinning is confirmed and the widget is resized and refreshed")
    fun pinWidget() {
        state.pinWidget(requestNew = true)
        state.refreshWidget()
    }

    @Then("the pinned widget shows all four dated tasks and is captured")
    fun captureDatedTasks() {
        state.verifyWidget()
        state.captureWidget()
    }

    @Given("a pinned widget contains four dated tasks")
    fun preparePinnedWidget() {
        state.launchFixture()
        state.pinWidget()
        state.finishFixtureActivities()
    }

    @When("all tasks are removed from the pinned widget")
    fun removeTasks(): Unit = with(state) {
        prefs.edit().putString(TaskWidgetProvider.DATA_KEY, """[{"type":"tasklist","title":"My Tasks"}]""").commit()
        refreshWidget()
    }

    @Then("the launcher widget shows its empty state and is captured")
    fun captureEmptyWidget(): Unit = with(state) {
        assertTrue(device.wait(Until.hasObject(By.text(context.getString(R.string.task_widget_empty))), timeout))
        captureWidget()
    }

    @When("the pinned widget colors and transparency are changed")
    fun updateAppearance() {
        state.saveAppearance()
        state.refreshWidget()
    }

    @Then("the updated launcher widget keeps its tasks and is captured")
    fun captureAppearance() {
        state.verifyWidget()
        state.captureWidget()
    }

    @When("the pinned widget is refreshed with tasks spanning date categories")
    fun updateCategories() {
        state.saveCategories()
        state.refreshWidget()
    }

    @Then("the launcher widget shows all five date categories and is captured")
    fun captureCategories(): Unit = with(state) {
        for (text in listOf("Overdue", "No due date", "Today", "Tomorrow", "Sat, Jan 2, 2027",
                "Pay invoice", "Organize notes", "Send report", "Collect parcel", "Call the dentist")) {
            assertTrue("Widget must show $text", device.wait(Until.hasObject(By.text(text)), timeout))
        }
        captureWidget()
    }
}
