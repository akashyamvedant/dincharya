package com.akashyam.dincharya

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register native ad factory for Dincharya native ads
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "dincharyaNativeAd",
            DincharyaNativeAdFactory(context)
        )
    }
    
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        
        // Unregister when done
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "dincharyaNativeAd")
    }
}
