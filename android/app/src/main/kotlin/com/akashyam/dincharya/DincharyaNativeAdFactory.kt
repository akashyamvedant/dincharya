package com.akashyam.dincharya

import android.content.Context
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
 * Based on Google's official example:
 * https://developers.google.com/admob/flutter/native/platforms
 * 
 * IMPORTANT: Uses View.INVISIBLE (not GONE) for optional assets
 * to prevent "Advertiser assets outside native ad view" error
 */
class DincharyaNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_layout, null) as NativeAdView

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

        // Headline is guaranteed in every NativeAd
        (nativeAdView.headlineView as TextView).text = nativeAd.headline

        // Body text - use INVISIBLE if null (not GONE!)
        if (nativeAd.body == null) {
            nativeAdView.bodyView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.bodyView?.visibility = View.VISIBLE
            (nativeAdView.bodyView as TextView).text = nativeAd.body
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
            (nativeAdView.priceView as TextView).text = nativeAd.price
        }

        // Store
        if (nativeAd.store == null) {
            nativeAdView.storeView?.visibility = View.INVISIBLE
        } else {
            nativeAdView.storeView?.visibility = View.VISIBLE
            (nativeAdView.storeView as TextView).text = nativeAd.store
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
            (nativeAdView.advertiserView as TextView).text = nativeAd.advertiser
        }

        // IMPORTANT: This must be called AFTER setting all asset views
        nativeAdView.setNativeAd(nativeAd)

        return nativeAdView
    }
}
