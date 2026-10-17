package bd.nagarshield.nagar_shield_360

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

class PhotoPrivacy(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in listOf("protect", "mask")) {
            result.notImplemented()
            return
        }
        worker.execute {
            try {
                val path = requireNotNull(call.argument<String>("path"))
                val bitmap = loadUpright(path)
                try {
                    var faces = 0
                    var textRegions = 0
                    if (call.method == "protect") {
                        val detector = FaceDetection.getClient(FaceDetectorOptions.Builder()
                            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                            .setMinFaceSize(0.05f).build())
                        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        try {
                            val input = InputImage.fromBitmap(bitmap, 0)
                            val faceTask = detector.process(input)
                            val textTask = recognizer.process(input)
                            // Blocking awaits run on this worker, never on the UI thread.
                            val foundFaces = Tasks.await(faceTask, 30, TimeUnit.SECONDS)
                            val foundText = Tasks.await(textTask, 30, TimeUnit.SECONDS)
                            for (face in foundFaces) {
                                val rect = expanded(face.boundingBox, bitmap, 0.22f)
                                pixelate(bitmap, rect)
                            }
                            // Mask all recognized text rather than guessing which text is sensitive.
                            for (block in foundText.textBlocks) {
                                block.boundingBox?.let { box ->
                                    fill(bitmap, expanded(box, bitmap, 0.08f))
                                    textRegions++
                                }
                            }
                            faces = foundFaces.size
                        } finally {
                            detector.close()
                            recognizer.close()
                        }
                    } else {
                        val rects = call.argument<List<Map<String, Number>>>("rects") ?: emptyList()
                        require(rects.size <= 100)
                        for (r in rects) {
                            val l = requireNotNull(r["left"]).toDouble()
                            val t = requireNotNull(r["top"]).toDouble()
                            val right = requireNotNull(r["right"]).toDouble()
                            val bottom = requireNotNull(r["bottom"]).toDouble()
                            require(listOf(l, t, right, bottom).all { it.isFinite() && it in 0.0..1.0 })
                            require(right > l && bottom > t)
                            fill(bitmap, Rect((l*bitmap.width).toInt(), (t*bitmap.height).toInt(),
                                ceil(right*bitmap.width).toInt(), ceil(bottom*bitmap.height).toInt()))
                        }
                    }
                    val folder = File(context.cacheDir, "private_proof").apply { mkdirs() }
                    val output = File(folder, "proof-${UUID.randomUUID()}.jpg")
                    try {
                        output.outputStream().use { stream ->
                            check(bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream))
                        }
                    } catch (error: Exception) {
                        output.delete()
                        throw error
                    }
                    // Re-encoding copies no GPS/EXIF tags from the selected original.
                    val response = mapOf("path" to output.path, "width" to bitmap.width,
                        "height" to bitmap.height, "faces" to faces, "textRegions" to textRegions)
                    main.post { result.success(response) }
                } finally { bitmap.recycle() }
            } catch (_: Exception) {
                // No raw path or detected personal text is exposed in error logs or UI.
                main.post { result.error("PRIVACY_FAILED", "Photo privacy processing failed. Choose another image.", null) }
            }
        }
    }

    private fun loadUpright(path: String): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > 2000) sample *= 2
        val decoded = requireNotNull(BitmapFactory.decodeFile(path,
            BitmapFactory.Options().apply { inSampleSize = sample; inPreferredConfig = Bitmap.Config.ARGB_8888 }))
        val matrix = Matrix()
        when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(270f)
        }
        val upright = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        val mutable = upright.copy(Bitmap.Config.ARGB_8888, true)
        if (upright !== decoded) upright.recycle()
        decoded.recycle()
        return requireNotNull(mutable)
    }

    private fun expanded(box: Rect, image: Bitmap, padding: Float): Rect {
        val dx = max(4, (box.width() * padding).toInt())
        val dy = max(4, (box.height() * padding).toInt())
        return Rect(max(0, box.left-dx), max(0, box.top-dy),
            min(image.width, box.right+dx), min(image.height, box.bottom+dy))
    }

    private fun pixelate(image: Bitmap, box: Rect) {
        if (box.width() <= 0 || box.height() <= 0) return
        val crop = Bitmap.createBitmap(image, box.left, box.top, box.width(), box.height())
        val tiny = Bitmap.createScaledBitmap(crop, min(8, box.width()), min(8, box.height()), false)
        Canvas(image).drawBitmap(tiny, null, box, Paint().apply { isFilterBitmap = false })
        if (tiny !== crop) tiny.recycle()
        crop.recycle()
    }

    private fun fill(image: Bitmap, box: Rect) {
        Canvas(image).drawRect(box, Paint().apply { color = Color.rgb(23, 59, 54) })
    }

    fun close() { worker.shutdown() }
}
