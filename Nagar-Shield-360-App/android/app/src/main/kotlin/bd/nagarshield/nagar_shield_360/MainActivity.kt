package bd.nagarshield.nagar_shield_360

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var photoPrivacy: PhotoPrivacy? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        photoPrivacy = PhotoPrivacy(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bd.nagarshield/photo_privacy")
            .setMethodCallHandler { call, result -> photoPrivacy!!.handle(call, result) }
    }

    override fun onDestroy() {
        photoPrivacy?.close()
        super.onDestroy()
    }
}
