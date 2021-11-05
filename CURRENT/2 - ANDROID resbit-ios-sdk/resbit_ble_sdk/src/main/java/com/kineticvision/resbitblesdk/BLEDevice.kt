package com.kineticvision.resbitblesdk

import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import java.util.*

class BLEDevice(val peripheral:BLEPeripheral) {

    var serialID:String? = null
    var iBeaconUUID:UUID? = null
    var iBeaconMajor:Int? = null
    var iBeaconMinor:Int? = null

    var bondState:BondState = BondState.NONE
    var lastSyncTime:Long = System.currentTimeMillis()
    var dataIsAvailable:Boolean = true

    var summaryData: List<SummaryData> = emptyList<SummaryData>()
}

enum class BondState(val id:Int) {
    NONE(10),
    BONDING(11),
    BONDED(12);

    companion object {
        fun fromInt(value: Int) = BondState.values().first { it.id == value }
    }
}