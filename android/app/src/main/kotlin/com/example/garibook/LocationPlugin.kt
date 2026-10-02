package com.example.garibook

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class LocationPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val METHOD_CHANNEL = "com.example.garibook/location_methods"
        const val EVENT_CHANNEL = "com.example.garibook/location_stream"

        private const val PERMISSION_REQUEST_CODE = 1001

        // Error codes sent back to Dart
        private const val ERR_PERMISSION_DENIED = "PERMISSION_DENIED"
        private const val ERR_SERVICES_DISABLED = "SERVICES_DISABLED"
        private const val ERR_PLAY_SERVICES = "PLAY_SERVICES_UNAVAILABLE"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Fields
    // ─────────────────────────────────────────────────────────────────────────

    private lateinit var context: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private lateinit var fusedClient: FusedLocationProviderClient

    /** Held so we can cancel the stream when Dart unsubscribes */
    private var locationCallback: LocationCallback? = null

    /** Held so we can reply to the runtime permission dialog result */
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Sink for pushing live locations down the EventChannel */
    private var eventSink: EventChannel.EventSink? = null

    // ─────────────────────────────────────────────────────────────────────────
    // FlutterPlugin — engine attach / detach
    // ─────────────────────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        fusedClient = LocationServices.getFusedLocationProviderClient(context)

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ActivityAware — activity lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MethodChannel — called from Dart
    // ─────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> result.success(checkPermission())
            "requestPermission" -> requestPermission(result)
            "getCurrentLocation" -> getCurrentLocation(result)
            "openSettings" -> openSettings(result)
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EventChannel — Dart stream subscribe / cancel
    // ─────────────────────────────────────────────────────────────────────────

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink

        if (!hasLocationPermission()) {
            sink?.error(ERR_PERMISSION_DENIED, "Location permission not granted", null)
            return
        }

        if (!isLocationEnabled()) {
            sink?.error(ERR_SERVICES_DISABLED, "Location services are disabled", null)
            return
        }

        startLocationUpdates(sink)
    }

    override fun onCancel(arguments: Any?) {
        stopLocationUpdates()
        eventSink = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Permission dialog result callback
    // ─────────────────────────────────────────────────────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED

        if (granted) {
            pendingPermissionResult?.success("GRANTED")
        } else {
            val act = activity
            val permanentlyDenied = act != null && !ActivityCompat.shouldShowRequestPermissionRationale(
                act,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
            if (permanentlyDenied) {
                pendingPermissionResult?.success("PERMANENTLY_DENIED")
            } else {
                pendingPermissionResult?.success("DENIED")
            }
        }

        pendingPermissionResult = null
        return true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun checkPermission(): String {
        val act = activity ?: return "DENIED"
        return when {
            hasLocationPermission() -> "GRANTED"
            ActivityCompat.shouldShowRequestPermissionRationale(
                act,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) -> "DENIED"
            else -> "PERMANENTLY_DENIED"
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val act = activity ?: run {
            result.error(ERR_PERMISSION_DENIED, "Activity not attached", null)
            return
        }
        if (hasLocationPermission()) {
            result.success("GRANTED")
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            act,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            PERMISSION_REQUEST_CODE,
        )
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error(ERR_PERMISSION_DENIED, "Location permission not granted", null)
            return
        }
        if (!isLocationEnabled()) {
            result.error(ERR_SERVICES_DISABLED, "Location services are disabled", null)
            return
        }

        try {
            fusedClient.lastLocation.addOnSuccessListener { location ->
                if (location != null) {
                    result.success(location.toMap())
                } else {
                    // lastLocation can be null on fresh boot — request a one-shot update
                    requestOneShot(result)
                }
            }.addOnFailureListener { e ->
                result.error(ERR_PLAY_SERVICES, e.message, null)
            }
        } catch (e: SecurityException) {
            result.error(ERR_PERMISSION_DENIED, e.message, null)
        }
    }

    private fun requestOneShot(result: MethodChannel.Result) {
        val request = buildLocationRequest()
        val callback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                fusedClient.removeLocationUpdates(this)
                val location = locationResult.lastLocation
                if (location != null) {
                    result.success(location.toMap())
                } else {
                    result.error(ERR_PLAY_SERVICES, "Could not get location", null)
                }
            }
        }
        try {
            fusedClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            result.error(ERR_PERMISSION_DENIED, e.message, null)
        }
    }

    private fun startLocationUpdates(sink: EventChannel.EventSink?) {
        val request = buildLocationRequest()
        val callback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                val location = locationResult.lastLocation ?: return
                sink?.success(location.toMap())
            }
        }

        locationCallback = callback

        try {
            fusedClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            sink?.error(ERR_PERMISSION_DENIED, e.message, null)
        }
    }

    private fun stopLocationUpdates() {
        locationCallback?.let { fusedClient.removeLocationUpdates(it) }
        locationCallback = null
    }

    private fun openSettings(result: MethodChannel.Result) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        result.success(null)
    }

    private fun buildLocationRequest(): LocationRequest {
        return LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2000L)
            .setMinUpdateIntervalMillis(1000L)
            .setWaitForAccurateLocation(false)
            .build()
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isLocationEnabled(): Boolean {
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    // Extension function to convert a Location into a Map for the Dart side
    private fun android.location.Location.toMap(): Map<String, Double> = mapOf(
        "latitude" to latitude,
        "longitude" to longitude,
        "accuracy" to accuracy.toDouble(),
        "bearing" to bearing.toDouble(),
        "speed" to speed.toDouble(),
        "altitude" to altitude,
    )
}
