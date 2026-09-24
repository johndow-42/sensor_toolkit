package com.geldmaschine.sensor_toolkit

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Eigene, kleine Lichtsensor-Bruecke statt eines Drittanbieter-Pakets.
 *
 * Grund: das Paket "light_sensor" (Stand 2026-09-24) hat ein veraltetes
 * Android-Gradle-Skript (benutzt die laengst entfernte jcenter()-Methode) und
 * baut mit aktuellem Gradle nicht mehr. Direkter SensorManager-Zugriff ist
 * fuer genau einen Wert (Lux) so einfach, dass eine eigene, wartungsfreie
 * Loesung sinnvoller ist als eine fragile Abhaengigkeit. Siehe concept.md.
 */
class MainActivity : FlutterActivity() {
    private val methodChannelName = "sensor_toolkit/light_sensor"
    private val eventChannelName = "sensor_toolkit/light_sensor/stream"

    private lateinit var sensorManager: SensorManager
    private var lightSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null

    private val listener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            eventSink?.success(event.values.getOrNull(0)?.toDouble())
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSensor" -> result.success(lightSensor != null)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    lightSensor?.let {
                        sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_UI)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    sensorManager.unregisterListener(listener)
                    eventSink = null
                }
            })
    }

    override fun onPause() {
        super.onPause()
        // Sensor nicht im Hintergrund weiterlaufen lassen (Akku, Trust-Punkt
        // aus concept.md: nichts laeuft, das der Nutzer nicht sieht).
        sensorManager.unregisterListener(listener)
    }

    override fun onResume() {
        super.onResume()
        if (eventSink != null) {
            lightSensor?.let {
                sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_UI)
            }
        }
    }
}
