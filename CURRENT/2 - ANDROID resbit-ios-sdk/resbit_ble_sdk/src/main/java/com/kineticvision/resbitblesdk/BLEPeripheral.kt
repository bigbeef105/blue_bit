package com.kineticvision.resbitblesdk

import android.bluetooth.le.ScanResult
import android.os.Build
import androidx.annotation.RequiresApi

class BLEPeripheral(val address:String, val name: String?, var rssi: Int, var isConnectable: Boolean) {

    constructor(scanResult: ScanResult) : this(scanResult.device.address, scanResult.device.name, scanResult.rssi, scanResult.isConnectable) { }
}