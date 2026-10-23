package chimin.remindme

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import java.io.File
import java.io.FileOutputStream

object ScreenshotComparator {
    private const val TOLERANCE = 0.005

    fun renderToBitmap(view: android.view.View): Bitmap {
        val bitmap = Bitmap.createBitmap(
            view.width.coerceAtLeast(1), view.height.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        view.draw(canvas)
        return bitmap
    }

    fun assertMatchesGolden(name: String, actual: Bitmap) {
        val update = System.getProperty("updateGoldens") == "true"
        val goldenStream = javaClass.classLoader?.getResourceAsStream("golden/$name")
        val goldenFile = File("/sdcard/test_output/$name") // placeholder not used for read

        if (update || goldenStream == null) {
            // write to test output dir via instrumentation
            val outDir = File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), "test_output")
            outDir.mkdirs()
            outDir.mkdirs()
            val outFile = File(outDir, name)
            FileOutputStream(outFile).use { actual.compress(Bitmap.CompressFormat.PNG, 100, it) }
            if (!update && goldenStream == null) {
                // first run: accept
                return
            }
            if (update) return
        }

        goldenStream?.close()
        // Load golden from classpath to temp file then decode
        val goldenBitmap = loadGolden(name) ?: return
        val mismatch = countMismatch(actual, goldenBitmap)
        val total = actual.width * actual.height
        if (mismatch.toDouble() / total > TOLERANCE) {
            writeDiff(actual, goldenBitmap, name)
            throw AssertionError("Golden mismatch for $name: $mismatch/$total pixels differ")
        }
    }

    private fun loadGolden(name: String): Bitmap? {
        val stream = javaClass.classLoader?.getResourceAsStream("golden/$name") ?: return null
        return android.graphics.BitmapFactory.decodeStream(stream)
    }

    private fun countMismatch(a: Bitmap, b: Bitmap): Int {
        if (a.width != b.width || a.height != b.height) return a.width * a.height
        var count = 0
        for (y in 0 until a.height) for (x in 0 until a.width) {
            if (a.getPixel(x, y) != b.getPixel(x, y)) count++
        }
        return count
    }

    private fun writeDiff(actual: Bitmap, golden: Bitmap, name: String) {
        val w = actual.width; val h = actual.height
        val diff = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        for (y in 0 until h) for (x in 0 until w) {
            val pa = if (x < actual.width && y < actual.height) actual.getPixel(x, y) else Color.BLACK
            val pg = if (x < golden.width && y < golden.height) golden.getPixel(x, y) else Color.BLACK
            diff.setPixel(x, y, if (pa == pg) Color.BLACK else Color.RED)
        }
        val outDir = File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), "test_output")
        outDir.mkdirs()
        FileOutputStream(File(outDir, "diff_$name")).use { diff.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
