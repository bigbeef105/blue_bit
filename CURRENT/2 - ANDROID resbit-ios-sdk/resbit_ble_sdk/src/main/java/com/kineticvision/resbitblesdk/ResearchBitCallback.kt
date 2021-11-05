package com.kineticvision.resbitblesdk

import android.bluetooth.le.ScanResult

abstract class ResBitScanCallback {
    abstract fun onPeripheralsFound(peripherals: List<BLEPeripheral>)
    abstract fun onScanFinished()
    abstract fun onFailure(error: ResearchBitError)
}

abstract class ResBitDeviceCallback {
    abstract fun onConnectionEstablished(device:BLEDevice)
    abstract fun onConnectionClosed(device:BLEDevice)
    abstract fun onSummaryDataReceived(summaries:List<SummaryData>)
    abstract fun onTimeSet()
    abstract fun onFailure(error: ResearchBitError)
}
