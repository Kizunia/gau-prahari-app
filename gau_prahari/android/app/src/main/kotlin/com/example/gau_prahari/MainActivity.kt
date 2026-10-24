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

/**
 * Multi-device Bluetooth RFCOMM Manager supporting independent connections:
 * - "milk_tester" channel: dedicated to Handheld Milk Tester HC-05 (pH, SCC, Temp, Cond)
 * - "collar" channel: dedicated to Smart Collar HC-05 (DHT22 Temp/Hum, MPU9250 Acc, MAX30105 IR)
 */
class BluetoothDeviceSession(private val channelName: String, private val expectedPrefixes: List<String>) {
    private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    var bluetoothSocket: BluetoothSocket? = null
    var reader: BufferedReader? = null

    fun connect(adapter: BluetoothAdapter?, address: String, onComplete: (Boolean, String?) -> Unit) {
        thread {
            try {
                adapter?.cancelDiscovery()
                val device: BluetoothDevice? = adapter?.getRemoteDevice(address)

                var socket: BluetoothSocket? = null
                try {
                    socket = device?.createRfcommSocketToServiceRecord(SPP_UUID)
                    socket?.connect()
                } catch (e1: Exception) {
                    try {
                        val m = device?.javaClass?.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        socket = m?.invoke(device, 1) as? BluetoothSocket
                        socket?.connect()
                    } catch (e2: Exception) {
                        onComplete(false, "Could not connect to $channelName HC-05 ($address). Check power and pairing: ${e1.message}")
                        return@thread
                    }
                }

                bluetoothSocket = socket
                reader = BufferedReader(InputStreamReader(bluetoothSocket?.inputStream))
                onComplete(true, null)
            } catch (e: Exception) {
                onComplete(false, e.message ?: "Failed to connect to $channelName")
            }
        }
    }

    fun isConnected(): Boolean {
        return bluetoothSocket?.isConnected == true
    }

    fun readPacket(timeoutMs: Long = 6000, onResult: (String?, String?) -> Unit) {
        thread {
            try {
                val socket = bluetoothSocket
                if (socket == null || !socket.isConnected) {
                    onResult(null, "Bluetooth socket for $channelName is not connected")
                    return@thread
                }

                val currentReader = reader ?: BufferedReader(InputStreamReader(socket.inputStream)).also { reader = it }
                var latestMatchingLine: String? = null
                val startTime = System.currentTimeMillis()

                while (System.currentTimeMillis() - startTime < timeoutMs) {
                    if (currentReader.ready()) {
                        val l = currentReader.readLine() ?: break
                        val clean = l.trim()
                        if (clean.isNotEmpty()) {
                            val matched = expectedPrefixes.isEmpty() || expectedPrefixes.any { clean.contains(it, ignoreCase = true) }
                            if (matched) {
                                latestMatchingLine = clean
                                // Drain any remaining backlog to obtain the freshest live telemetry
                                if (!currentReader.ready()) {
                                    break
                                }
                            }
                        }
                    } else {
                        Thread.sleep(50)
                    }
                }

                if (latestMatchingLine != null) {
                    onResult(latestMatchingLine, null)
                } else {
                    onResult(null, "No valid telemetry received from $channelName HC-05 within timeout")
                }
            } catch (e: Exception) {
                onResult(null, e.message ?: "Error reading from $channelName")
            }
        }
    }

    fun disconnect() {
        try {
            reader?.close()
            bluetoothSocket?.close()
            reader = null
            bluetoothSocket = null
        } catch (_: Exception) {}
    }
}

class MainActivity : FlutterActivity() {
    private val MILK_CHANNEL = "gau_prahari/bluetooth"
    private val COLLAR_CHANNEL = "gau_prahari/bluetooth_collar"
    private val PERMISSION_REQUEST_CODE = 2026

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    // Two independent sessions for milk tester and collar hardware!
    private val milkTesterSession = BluetoothDeviceSession(
        "Milk Tester",
        listOf("{", "ph", "gas", "scc", "conductivity", "g:", "d:")
    )
    private val collarSession = BluetoothDeviceSession(
        "Collar",
        listOf("T:", "H:", "Acc", "IR:", "ID:")
    )

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
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
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

        // 1. Setup Milk Tester Channel (Leaves existing Milk Tester logic 100% untouched)
        setupChannel(flutterEngine, MILK_CHANNEL, milkTesterSession)

        // 2. Setup Dedicated Collar Channel (Completely isolated socket & stream)
        setupChannel(flutterEngine, COLLAR_CHANNEL, collarSession)
    }

    private fun setupChannel(flutterEngine: FlutterEngine, channelName: String, session: BluetoothDeviceSession) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
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
                    session.connect(bluetoothAdapter, address) { success, errMsg ->
                        runOnUiThread {
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("CONNECT_FAILED", errMsg ?: "Failed to connect", null)
                            }
                        }
                    }
                }

                "isConnected" -> {
                    result.success(session.isConnected())
                }

                "readPacket" -> {
                    session.readPacket { line, error ->
                        runOnUiThread {
                            if (line != null) {
                                result.success(line)
                            } else {
                                result.error("READ_FAILED", error ?: "Failed to read packet", null)
                            }
                        }
                    }
                }

                "disconnect" -> {
                    session.disconnect()
                    result.success(true)
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
