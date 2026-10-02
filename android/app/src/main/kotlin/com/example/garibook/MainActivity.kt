package com.example.garibook

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the LocationPlugin using the modern FlutterPlugin + ActivityAware API
        flutterEngine.plugins.add(LocationPlugin())
    }
}
