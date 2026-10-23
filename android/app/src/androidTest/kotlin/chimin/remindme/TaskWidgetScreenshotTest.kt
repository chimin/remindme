package chimin.remindme

import android.view.View
import android.widget.RemoteViews
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4

@RunWith(AndroidJUnit4::class)
class TaskWidgetScreenshotTest {

    private fun inflateAndRender(layout: Int, w: Int, h: Int): android.graphics.Bitmap {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val inflater = android.view.LayoutInflater.from(context)
        val view = inflater.inflate(layout, null, false)
        view.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY)
        )
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        return ScreenshotComparator.renderToBitmap(view)
    }

    @Test
    fun inflateTaskWidgetLayoutShouldNotThrow() {
        val bitmap = inflateAndRender(R.layout.task_widget, 400, 300)
        ScreenshotComparator.assertMatchesGolden("task_widget.png", bitmap)
    }

    @Test
    fun inflateTaskWidgetItemLayoutShouldNotThrow() {
        val bitmap = inflateAndRender(R.layout.task_widget_item, 400, 80)
        ScreenshotComparator.assertMatchesGolden("task_widget_item.png", bitmap)
    }

    @Test
    fun inflateTaskWidgetGroupLayoutShouldNotThrow() {
        val bitmap = inflateAndRender(R.layout.task_widget_group, 400, 60)
        ScreenshotComparator.assertMatchesGolden("task_widget_group.png", bitmap)
    }

    @Test
    fun inflateTaskWidgetEmptyLayoutShouldNotThrow() {
        val bitmap = inflateAndRender(R.layout.task_widget_empty, 400, 120)
        ScreenshotComparator.assertMatchesGolden("task_widget_empty.png", bitmap)
    }

}
