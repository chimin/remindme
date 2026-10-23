package chimin.remindme

import android.graphics.Bitmap
import android.graphics.Canvas
import android.content.Context
import java.io.File
import java.io.FileOutputStream

object ScreenshotCapture {
    fun renderToBitmap(view: android.view.View): Bitmap {
        val bitmap = Bitmap.createBitmap(
            view.width.coerceAtLeast(1), view.height.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        view.draw(canvas)
        return bitmap
    }

    fun captureScreenshot(name: String, actual: Bitmap, context: Context) {
        val outDir = context.getExternalFilesDir("test_output") ?: context.filesDir
        outDir.mkdirs()
        val outFile = File(outDir, name)
        FileOutputStream(outFile).use { actual.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
