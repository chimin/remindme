package chimin.remindme.support

import android.os.Build
import io.cucumber.java.Before
import org.junit.Assume.assumeTrue

class NativeHooks {
    @Before(value = "@api31", order = 0)
    fun requireWidgetCollections() {
        assumeTrue("Widget collection scenarios require API 31+", Build.VERSION.SDK_INT >= 31)
    }

    @Before(value = "@api33", order = 0)
    fun requireNotificationPermission() {
        assumeTrue("Notification runtime permissions require API 33+", Build.VERSION.SDK_INT >= 33)
    }
}
