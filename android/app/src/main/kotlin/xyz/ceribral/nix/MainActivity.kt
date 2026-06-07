package xyz.ceribral.nix

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "nix/battery_optimization"
    private val NOTIFICATION_CHANNEL = "nix/notifications"
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    private var pendingPermissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createBackgroundServiceNotificationChannel()
        createUpdateNotificationChannel()
        clearStalePluginPrefs()

        // Battery optimization settings
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openBatteryOptimizationSettings") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }

        // Notifications channel: permission + update notifications + openUpdates
        val notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notificationMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "showUpdateNotification" -> {
                    val title = call.argument<String>("title") ?: "Update Available"
                    val body = call.argument<String>("body") ?: "A new version of N.I.X is available"
                    showUpdateNotification(title, body)
                    result.success(true)
                }
                "getLaunchIntent" -> {
                    val openUpdates = intent.getBooleanExtra("nix_open_updates", false)
                    result.success(openUpdates)
                }
                else -> result.notImplemented()
            }
        }
        // Check cold start from notification
        if (intent.getBooleanExtra("nix_open_updates", false)) {
            notificationMethodChannel.invokeMethod("openUpdates", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("nix_open_updates", false)) {
            val flutterEngine = flutterEngine
            if (flutterEngine != null) {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
                    .invokeMethod("openUpdates", null)
            }
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun createBackgroundServiceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "nix_background_channel",
                "N.I.X Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "N.I.X background service connection status"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createUpdateNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "nix_update_channel",
                "N.I.X Updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "N.I.X app update notifications"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun showUpdateNotification(title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("nix_open_updates", true)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, "nix_update_channel")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(1002, notification)
    }

    private fun clearStalePluginPrefs() {
        val prefs: SharedPreferences =
            applicationContext.getSharedPreferences("id.flutter.background_service", Context.MODE_PRIVATE)
        prefs.edit()
            .remove("notification_channel_id")
            .remove("foreground_service_types")
            .apply()
    }
}
