package com.example.clean_apg_app

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "apg_background",
                "APG 백그라운드 서비스",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "약통 연결 상태를 유지합니다"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
