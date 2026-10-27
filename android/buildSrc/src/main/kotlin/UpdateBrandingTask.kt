import groovy.json.JsonSlurper
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.OutputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import org.gradle.work.DisableCachingByDefault
import java.awt.Color
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO

/** Exports opaque PNGs for Android, iOS, and Google Play using JVM image processing. */
@DisableCachingByDefault(because = "Regenerates checked-in artwork; sources may also be destinations.")
abstract class UpdateBrandingTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val iconSource: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val featureSource: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val iconCatalog: RegularFileProperty

    @get:Internal
    abstract val outputDirectory: DirectoryProperty

    private data class Export(val path: String, val width: Int, val height: Int)

    private fun iconExports(): List<Export> {
        val android = mapOf("mdpi" to 48, "hdpi" to 72, "xhdpi" to 96, "xxhdpi" to 144, "xxxhdpi" to 192)
            .map { (density, size) ->
                Export("android/app/src/main/res/mipmap-$density/ic_launcher.png", size, size)
            }
        val catalog = JsonSlurper().parse(iconCatalog.get().asFile) as Map<*, *>
        val images = catalog["images"] as? List<*>
            ?: throw GradleException("The iOS icon catalog must contain an images array.")
        val ios = images.map { entry ->
            val image = entry as? Map<*, *> ?: throw GradleException("Invalid iOS icon entry.")
            val filename = image["filename"] as? String ?: throw GradleException("Missing iOS icon filename.")
            if (File(filename).name != filename || filename.contains('\\') || !filename.endsWith(".png")) {
                throw GradleException("Invalid iOS icon filename: $filename")
            }
            val size = (image["size"] as? String)?.split('x')
                ?: throw GradleException("Missing size for $filename")
            val scale = (image["scale"] as? String)?.removeSuffix("x")?.toDoubleOrNull()
                ?: throw GradleException("Invalid scale for $filename")
            val width = size.getOrNull(0)?.toDoubleOrNull()?.times(scale)
            val height = size.getOrNull(1)?.toDoubleOrNull()?.times(scale)
            if (width == null || height == null || width <= 0 || height <= 0 ||
                width != width.toInt().toDouble() || height != height.toInt().toDouble()) {
                throw GradleException("Invalid pixel dimensions for $filename")
            }
            Export("ios/Runner/Assets.xcassets/AppIcon.appiconset/$filename", width.toInt(), height.toInt())
        }.distinctBy { it.path }
        return listOf(Export("assets/branding/play-store-icon.png", 512, 512)) + android + ios
    }

    @get:OutputFiles
    val generatedFiles: List<File>
        get() = (iconExports() + Export("assets/branding/play-store-feature-graphic.png", 1024, 500))
            .map { outputDirectory.file(it.path).get().asFile }

    init {
        // Inputs may also be outputs, so always run this explicit maintenance task.
        outputs.upToDateWhen { false }
    }

    private fun readImage(file: File): BufferedImage =
        ImageIO.read(file) ?: throw GradleException("Cannot decode image: $file")

    private fun exportImage(source: BufferedImage, sourceFile: File, export: Export) {
        val destination = outputDirectory.file(export.path).get().asFile
        if (destination.canonicalFile == sourceFile.canonicalFile &&
            source.width == export.width && source.height == export.height && !source.colorModel.hasAlpha()) {
            return // Keep full-resolution sources intact on repeated runs.
        }
        val bitmap = BufferedImage(export.width, export.height, BufferedImage.TYPE_INT_RGB)
        val graphics = bitmap.createGraphics()
        try {
            graphics.color = Color.WHITE
            graphics.fillRect(0, 0, export.width, export.height)
            graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC)
            graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY)
            graphics.drawImage(source, 0, 0, export.width, export.height, null)
        } finally {
            graphics.dispose()
        }
        destination.parentFile.mkdirs()
        if (!ImageIO.write(bitmap, "png", destination)) {
            throw GradleException("Cannot write PNG: $destination")
        }
    }

    @TaskAction
    fun generate() {
        // Read both sources and validate the catalog before writing any output.
        val iconFile = iconSource.get().asFile
        val featureFile = featureSource.get().asFile
        val icon = readImage(iconFile)
        val feature = readImage(featureFile)
        if (icon.width != icon.height) throw GradleException("The icon source must be square.")
        val exports = iconExports()
        exports.forEach { exportImage(icon, iconFile, it) }
        exportImage(feature, featureFile, Export("assets/branding/play-store-feature-graphic.png", 1024, 500))
        logger.lifecycle("Generated " + (exports.size + 1) + " branding assets in " + outputDirectory.get().asFile)
    }
}
