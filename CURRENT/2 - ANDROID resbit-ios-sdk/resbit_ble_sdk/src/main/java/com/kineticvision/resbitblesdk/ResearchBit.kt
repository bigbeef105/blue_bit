package com.kineticvision.resbitblesdk

import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context

typealias MessageListener = (String) -> Unit

interface ResearchBit {
    var state: ResearchBitImpl.State

    fun isBluetoothEnabled(): Boolean
    fun setMessageListener(listener:MessageListener)
    fun scanForBLEDevices(scanTime: Long, callback: ResBitScanCallback)
    fun getBLEDevice(peripheral: BLEPeripheral, callback: ResBitDeviceCallback)
    fun getBLEDeviceSummaryData(device: BLEDevice, callback: ResBitDeviceCallback)
    fun setBLEDeviceTime(peripheral: BLEPeripheral, callback: ResBitDeviceCallback)
}
