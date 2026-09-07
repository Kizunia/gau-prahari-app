package com.example.gau_prahari

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "gau_prahari/bluetooth"
    private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val PERMISSION_REQUEST_CODE = 2026

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var reader: BufferedReader? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private fun checkPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val connectGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
            val scanGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
            connectGranted && scanGranted
        } else {
            val locGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            locGranted
        }
    }

    private fun requestAppPermissions(result: MethodChannel.Result) {
        if (checkPermissions()) {
            result.success(true)
            return
        }

        pendingPermissionResult = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ),
                PERMISSION_REQUEST_CODE
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }

    @SuppressLint("MissingPermission")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    requestAppPermissions(result)
                }

                "getPairedDevices" -> {
                    if (bluetoothAdapter == null) {
                        result.error("NO_BLUETOOTH", "Bluetooth is not supported on this device", null)
                        return@setMethodCallHandler
                    }
                    if (!bluetoothAdapter!!.isEnabled) {
                        result.error("BLUETOOTH_DISABLED", "Bluetooth is turned OFF. Please turn ON Bluetooth in Android Settings.", null)
                        return@setMethodCallHandler
                    }

                    if (!checkPermissions()) {
                        // Request permissions automatically
                        requestAppPermissions(object : MethodChannel.Result {
                            override fun success(res: Any?) {
                                if (res == true) {
                                    fetchPairedDevices(result)
                                } else {
                                    result.error("PERMISSION_DENIED", "Nearby devices / Bluetooth permission was denied by user", null)
                                }
                            }
                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                result.error(errorCode, errorMessage, errorDetails)
                            }
                            override fun notImplemented() {
                                result.notImplemented()
                            }
                        })
                        return@setMethodCallHandler
                    }

                    fetchPairedDevices(result)
                }

                "connect" -> {
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGS", "Device address is required", null)
                        return@setMethodCallHandler
                    }
                    thread {
                        try {
                            bluetoothAdapter?.cancelDiscovery()
                            val device: BluetoothDevice? = bluetoothAdapter?.getRemoteDevice(address)
                            
                            // Try standard SPP UUID first
                            var socket: BluetoothSocket? = null
                            try {
                                socket = device?.createRfcommSocketToServiceRecord(SPP_UUID)
                                socket?.connect()
                            } catch (e1: Exception) {
                                // Fallback to reflection socket on port 1 (common for HC-05 on Android)
                                try {
                                    val m = device?.javaClass?.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                                    socket = m?.invoke(device, 1) as? BluetoothSocket
                                    socket?.connect()
                                } catch (e2: Exception) {
                                    throw Exception("Could not connect to HC-05. Please ensure HC-05 is powered on and not connected to another app (e.g. Serial Terminal). Details: ${e1.message}")
                                }
                            }

                            bluetoothSocket = socket
                            reader = BufferedReader(InputStreamReader(bluetoothSocket?.inputStream))
                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("CONNECT_FAILED", e.message ?: "Failed to connect to HC-05", null)
                            }
                        }
                    }
                }

                "isConnected" -> {
                    val connected = bluetoothSocket?.isConnected == true
                    result.success(connected)
                }

                "readPacket" -> {
                    thread {
                        try {
                            val socket = bluetoothSocket
                            if (socket == null || !socket.isConnected) {
                                runOnUiThread {
                                    result.error("NOT_CONNECTED", "Bluetooth socket is not connected", null)
                                }
                                return@thread
                            }

                            val inStream = socket.inputStream
                            // 1. DRAIN / FLUSH all stale backlog bytes accumulated while the app was idle
                            try {
                                if (inStream != null && inStream.available() > 0) {
                                    inStream.skip(inStream.available().toLong())
                                }
                            } catch (_: Exception) {}

                            // Create fresh reader on the purged stream
                            val freshReader = BufferedReader(InputStreamReader(inStream))
                            reader = freshReader

                            var line: String? = null
                            val startTime = System.currentTimeMillis()
                            
                            // Poll up to 6 seconds for the next live freshly arriving packet
                            while (System.currentTimeMillis() - startTime < 6000) {
                                val l = freshReader.readLine()
                                if (!l.isNullOrBlank() && (l.contains("{") || l.contains("pH:") || l.contains("G:"))) {
                                    line = l
                                    break
                                }
                            }

                            val finalLine = line
                            runOnUiThread {
                                if (finalLine != null) {
                                    result.success(finalLine)
                                } else {
                                    result.error("READ_TIMEOUT", "No valid sensor telemetry received from HC-05. Make sure Arduino is transmitting data.", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("READ_FAILED", e.message ?: "Error reading Bluetooth stream", null)
                            }
                        }
                    }
                }

                "disconnect" -> {
                    try {
                        reader?.close()
                        bluetoothSocket?.close()
                        reader = null
                        bluetoothSocket = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DISCONNECT_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun fetchPairedDevices(result: MethodChannel.Result) {
        try {
            val paired = bluetoothAdapter?.bondedDevices
            val deviceList = ArrayList<Map<String, String>>()
            paired?.forEach { dev ->
                deviceList.add(mapOf("name" to (dev.name ?: "Unknown Device"), "address" to dev.address))
            }
            result.success(deviceList)
        } catch (e: Exception) {
            result.error("BLUETOOTH_ERROR", e.message, null)
        }
    }
}
