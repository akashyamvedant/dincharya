package com.akashyam.dincharya

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/**
 * Native Ad Factory for Dincharya app
 * 
 * Reads isDarkMode from customOptions (passed by Flutter's ThemeProvider)
 * and applies theme-appropriate colors to the native ad layout.
 */
class DincharyaNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_layout, null) as NativeAdView

        // Read dark mode from Flutter's ThemeProvider via customOptions
        val isDarkMode = customOptions?.get("isDarkMode") as? Boolean ?: false

        // Apply theme-aware colors programmatically
        val headlineColor = if (isDarkMode) Color.parseColor("#E0E0E0") else Color.parseColor("#2C1810")
        val bodyColor = if (isDarkMode) Color.parseColor("#B0B0B0") else Color.parseColor("#444444")
        val subtextColor = if (isDarkMode) Color.parseColor("#909090") else Color.parseColor("#666666")
        val badgeTextColor = if (isDarkMode) Color.parseColor("#D4A574") else Color.parseColor("#8B4513")

        // Apply card background
        val cardContainer = nativeAdView.findViewById<View>(R.id.ad_card_container)
        if (cardContainer != null) {
            val bg = GradientDrawable()
            bg.cornerRadius = 48f // ~16dp
            if (isDarkMode) {
                bg.setColor(Color.parseColor("#1E1E1E"))
                bg.setStroke(3, Color.parseColor("#333333"))
            } else {
                bg.setColor(Color.parseColor("#FDF8F3"))
                bg.setStroke(3, Color.parseColor("#D4A574"))
            }
            cardContainer.background = bg
        }

        // Set the media view (required)
        val mediaView = nativeAdView.findViewById<MediaView>(R.id.ad_media)
        nativeAdView.mediaView = mediaView
        mediaView.mediaContent = nativeAd.mediaContent

        // Set other ad assets
        nativeAdView.headlineView = nativeAdView.findViewById(R.id.ad_headline)
        nativeAdView.bodyView = nativeAdView.findViewById(R.id.ad_body)
        nativeAdView.callToActionView = nativeAdView.findViewById(R.id.ad_call_to_action)
        nativeAdView.iconView = nativeAdView.findViewById(R.id.ad_app_icon)
        nativeAdView.priceView = nativeAdView.findViewById(R.id.ad_price)
        nativeAdView.starRatingView = nativeAdView.findViewById(R.id.ad_stars)
        nativeAdView.storeView = nativeAdView.findViewById(R.id.ad_store)
        nativeAdView.advertiserView = nativeAdView.findViewById(R.id.ad_advertiser)

        // Headline
        (nativeAdView.headlineView as TextView).apply {
            text = nativeAd.headline
            setTextColor(headlineColor)
        }

        // Body text
        if (nativeAd.body == null) {
            nativeAdView.bodyView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.bodyView?.visibility = View.VISIBLE
            (nativeAdView.bodyView as TextView).apply {
                text = nativeAd.body
                setTextColor(bodyColor)
            }
        }

        // Call to Action
        if (nativeAd.callToAction == null) {
            nativeAdView.callToActionView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.callToActionView?.visibility = View.VISIBLE
            (nativeAdView.callToActionView as TextView).text = nativeAd.callToAction
        }

        // Icon
        if (nativeAd.icon == null) {
            nativeAdView.iconView?.visibility = View.GONE
        } else {
            (nativeAdView.iconView as ImageView).setImageDrawable(nativeAd.icon?.drawable)
            nativeAdView.iconView?.visibility = View.VISIBLE
        }

        // Price
        if (nativeAd.price == null) {
            nativeAdView.priceView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.priceView?.visibility = View.VISIBLE
            (nativeAdView.priceView as TextView).apply {
                text = nativeAd.price
                setTextColor(subtextColor)
            }
        }

        // Store
        if (nativeAd.store == null) {
            nativeAdView.storeView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.storeView?.visibility = View.VISIBLE
            (nativeAdView.storeView as TextView).apply {
                text = nativeAd.store
                setTextColor(subtextColor)
            }
        }

        // Star Rating
        if (nativeAd.starRating == null) {
            nativeAdView.starRatingView?.visibility = View.INVISIBLE
        } else {
            (nativeAdView.starRatingView as RatingBar).rating = nativeAd.starRating!!.toFloat()
            nativeAdView.starRatingView?.visibility = View.VISIBLE
        }

        // Advertiser
        if (nativeAd.advertiser == null) {
            nativeAdView.advertiserView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.advertiserView?.visibility = View.VISIBLE
            (nativeAdView.advertiserView as TextView).apply {
                text = nativeAd.advertiser
                setTextColor(subtextColor)
            }
        }

        // Ad badge
        val adBadge = nativeAdView.findViewById<TextView>(R.id.ad_badge)
        adBadge?.setTextColor(badgeTextColor)

        // IMPORTANT: This must be called AFTER setting all asset views
        nativeAdView.setNativeAd(nativeAd)

        return nativeAdView
    }
}
