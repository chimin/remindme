package chimin.remindme.steps.task_widget_provider

import chimin.remindme.*
import io.cucumber.java.en.Given
import io.cucumber.java.en.When
import io.cucumber.java.en.Then
import android.appwidget.AppWidgetHostView
import android.graphics.Color
import android.view.View
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.junit.Assert.*

class ScenarioSteps {
    private val state = ScenarioContext()

    @io.cucumber.java.Before("@task_widget_provider")
    fun rememberPreferences(): Unit = with(state) {
        previousData = prefs.getString(TaskWidgetProvider.DATA_KEY, null)
        previousConfig = prefs.getString(TaskWidgetProvider.CONFIG_KEY, null)
        snapshotSaved = true
    }

    @io.cucumber.java.After("@task_widget_provider")
    fun restorePreferences(): Unit = with(state) {
        if (snapshotSaved) {
            prefs.edit().putString(TaskWidgetProvider.DATA_KEY, previousData)
                .putString(TaskWidgetProvider.CONFIG_KEY, previousConfig).commit()
        }
    }

    @Given("two widget views use the original appearance")
    fun prepareAppearanceViews(): Unit = with(state) {
        HomeWidgetPlugin.getData(context).edit().putString(TaskWidgetProvider.DATA_KEY, """
          [{"type":"tasklist","title":"Tasks"},
           {"type":"header","title":"Overdue","category":"overdue"},
           {"type":"task","title":"Open task","completed":false},
           {"type":"task","title":"Finished task","completed":true},
           {"type":"header","title":"Today","category":"today"}]
        """.trimIndent()).commit()
        instrumentation.runOnMainSync {
            val provider = TaskWidgetProvider()
            val parent = AppWidgetHostView(context)
            saveColors(Color.BLACK, Color.RED, Color.WHITE, 242)
            first = provider.buildViews(context, 101).apply(context, parent)
            second = provider.buildViews(context, 102).apply(context, parent)
            parent.addView(first)
            parent.addView(second)
            assertColors(first, Color.BLACK, Color.RED, Color.WHITE, 242)
        }
    }

    @When("the {word} updated appearance is reapplied to both widgets")
    fun reapplyAppearance(appearance: String): Unit = with(state) {
        expectedColors = if (appearance == "first") listOf(Color.WHITE, Color.YELLOW, Color.DKGRAY, 216)
            else listOf(Color.GREEN, Color.BLUE, Color.BLACK, 128)
        val (text, overdue, background, alpha) = expectedColors
        instrumentation.runOnMainSync {
            saveColors(text, overdue, background, alpha)
            val provider = TaskWidgetProvider()
            provider.buildViews(context, 101).reapply(context, first)
            provider.buildViews(context, 102).reapply(context, second)
        }
    }

    @Then("both widget views use all the updated colors")
    fun checkUpdatedColors(): Unit = with(state) {
        val (text, overdue, background, alpha) = expectedColors
        instrumentation.runOnMainSync {
            assertColors(first, text, overdue, background, alpha)
            assertColors(second, text, overdue, background, alpha)
        }
    }

    @Given("the widget has no tasks and a transparent background")
    fun theWidgetHasNoTasksAndATransparentBackground(): Unit = with(state) {
        prefs.edit().putString(TaskWidgetProvider.DATA_KEY, "[]").commit()
        saveColors(Color.WHITE, Color.RED, Color.BLACK, 0)
    }

    @When("the empty widget views are built")
    fun theEmptyWidgetViewsAreBuilt(): Unit = with(state) {
        instrumentation.runOnMainSync {
            view = TaskWidgetProvider().buildViews(context, 101).apply(context, AppWidgetHostView(context))
        }
    }

    @Then("the empty state uses the saved appearance")
    fun theEmptyStateUsesTheSavedAppearance(): Unit = with(state) {
        instrumentation.runOnMainSync {
            assertEquals(View.VISIBLE, view.findViewById<View>(R.id.empty_view).visibility)
            assertEquals(Color.WHITE, view.findViewById<TextView>(R.id.empty_view).currentTextColor)
            assertEquals(0, view.findViewById<ImageView>(R.id.widget_background).imageAlpha)
            assertEquals(0, view.findViewById<ListView>(R.id.task_list).adapter.count)
        }
    }

    @Given("widget tasks span all five date categories")
    fun widgetTasksSpanAllFiveDateCategories(): Unit = with(state) {
        HomeWidgetPlugin.getData(context).edit()
          .remove(TaskWidgetProvider.CONFIG_KEY)
          .putString(TaskWidgetProvider.DATA_KEY, """
            [{"type":"tasklist","title":"Tasks"},
             {"type":"header","title":"Overdue","category":"overdue"},
             {"type":"task","title":"Pay invoice","completed":false},
             {"type":"header","title":"No due date","category":"noDueDate"},
             {"type":"task","title":"Organize notes","completed":false},
             {"type":"header","title":"Today","category":"today"},
             {"type":"task","title":"Send report","completed":false},
             {"type":"header","title":"Tomorrow","category":"future"},
             {"type":"task","title":"Collect parcel","completed":false},
             {"type":"header","title":"Sat, Jan 2, 2027","category":"future"},
             {"type":"task","title":"Call the dentist","completed":false}]
          """.trimIndent()).commit()
    }

    @When("the categorized widget views are built")
    fun theCategorizedWidgetViewsAreBuilt(): Unit = with(state) {
        instrumentation.runOnMainSync {
            view = TaskWidgetProvider().buildViews(context, 101).apply(context, AppWidgetHostView(context))
        }
    }

    @Then("the widget shows all matching category labels")
    fun theWidgetShowsAllMatchingCategoryLabels(): Unit = with(state) {
        instrumentation.runOnMainSync {
            val list = view.findViewById<ListView>(R.id.task_list)
            val expected = listOf("Overdue", "No due date", "Today", "Tomorrow", "Sat, Jan 2, 2027")
            assertEquals(10, list.adapter.count)
            expected.forEachIndexed { index, title ->
              val header = list.adapter.getView(index * 2, null, list)
              assertEquals(title, header.findViewById<TextView>(R.id.group_title).text.toString())
            }
        }
    }

    @Given("task identities contain reserved characters")
    fun taskIdentitiesContainReservedCharacters(): Unit = with(state) {
        taskListId = "list /+?&"
        taskId = "task /+?&"
    }

    @When("a widget intent is built with reserved characters")
    fun aWidgetIntentIsBuiltWithReservedCharacters(): Unit = with(state) {
        uri = TaskWidgetProvider.taskFillInIntent(taskListId, taskId).data!!
    }

    @Then("the widget intent preserves both encoded identities")
    fun theWidgetIntentPreservesBothEncodedIdentities(): Unit = with(state) {
        assertEquals("remindme", uri.scheme)
        assertEquals("task", uri.host)
        assertEquals("/edit", uri.path)
        assertEquals("list /+?&", uri.getQueryParameter("taskListId"))
        assertEquals("task /+?&", uri.getQueryParameter("taskId"))
        assertNotEquals(uri, TaskWidgetProvider.taskFillInIntent("other", "task /+?&").data)
    }

    @Given("legacy task identities may be absent")
    fun legacyTaskIdentitiesMayBeAbsent(): Unit = with(state) {
        fallbackUris.clear()
    }

    @When("widget intents are built with incomplete identities")
    fun widgetIntentsAreBuiltWithIncompleteIdentities(): Unit = with(state) {
        for ((list, task) in listOf(null to null, "list" to null, null to "task", "" to "task")) {
            fallbackUris.add(TaskWidgetProvider.taskFillInIntent(list, task).data.toString())
        }
    }

    @Then("each incomplete identity opens home")
    fun eachIncompleteIdentityOpensHome(): Unit = with(state) {
        fallbackUris.forEach { assertEquals("remindme://home", it) }
    }
}
