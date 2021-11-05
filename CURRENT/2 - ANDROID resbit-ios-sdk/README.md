# ResearchBit Android SDK

This project is an Android/Kotlin implementation of the P&G ResearchBit SDK Framework.

## Goal
Communicate with and retrieve data from ResearchBit Bluetooth sensors

## Location Services
In order to allow the application to scan for beacons in the background, the user must select "Allow all the time". Selecting "Allow only while using the app" or "Ask every time" will prevent the background scan.

## Architecture
**Language:** Kotlin


This repository contains an Android Library which manages the bluetooth stack, as well as a demonstration/debug app.

## Using the Library
1. Include the `resbit_ble_sdk` Module in your project
1. Create an instance of `ResearchBitImpl` and pass it a `context`.
```
val researchBit : ResearchBit = ResearchBitImpl(context)
```
1. Utilize methods defined in the `ResearchBit` protocol to retrieve data from the devices.

## ResearchBit Protocol Method Definitions
### Properties
#### state
A class enum which contains information on the current state of the ResearchBitImpl object. Possible states are:

- PoweredOff
- Disconnected
- Scanning
- Connecting
- DiscoveringServices
- DiscoveringCharacteristics
- Connected
- OutOfRange

### Functions
#### isBluetoothEnabled(): Boolean
Manages the Android OS request to check if the bluetooth hardware on the device is enabled.
#### setMessageListener(listener: MessageListener)
Allows another object to receive human-readable messages as all of the ResearchBit steps are executed. This is used, for example, in the admin screen of the demonstration/debug app.
#### scanForBLEDevices(scanTime: Long, callback: ResBitScanCallback)
Scans locally for ResearchBit compliant devices.

Example:

```kotlin
scanForBLEDevices(5000, object : ResBitScanCallback() {

    override fun onPeripheralsFound(peripherals: List<BLEPeripheral>) {
    		// May be called multiple times in a scan.
    }

    override fun onScanFinished() {
        // Called when the scan is finished, whether any peripherals were found or not.
    }

    override fun onFailure(error: ResearchBitError) {
    	  // Called if there is an error during the scan.
         Log.d(TAG, "Scan Failure: $error")
    }
})
```

#### getBLEDevice(peripheral: BLEPeripheral, callback: ResBitDeviceCallback)
Calling this method with a `BLEPeripheral` will make a connection and callback to the `onConnectionEstablished()` method with the associated `BLEDevice`. The `BLEDevice` is needed to retrieve the SummaryData.

#### getBLEDeviceSummaryData(device: BLEDevice, callback: ResBitDeviceCallback)
Calling this method handles the communication with the device to retrieve all SummaryData. Once it is completed, `OnSummaryDataRetrieved()` is called with all of the SummaryData objects.

#### setBLEDeviceTime(peripheral: BLEPeripheral, callback: ResBitDeviceCallback)
Calling this method handles setting the `BLEPeripheral` with the Android device's time. Once completed, `OnTimeSet()` is called.

### ResBitDeviceCallback Example

```kotlin
override fun onConnectionEstablished(device: BLEDevice) {
    // Returns the BLEDevice for the requested peripheral once a connection is made.
}

override fun onConnectionClosed(device: BLEDevice) {
    // Called when the BLEDevice's connection is closed.
}

override fun onSummaryDataReceived(summaries: List<SummaryData>) {
	// Handle the SummaryData objects returned here.
}

override fun onTimeSet() {
	// Called after the time has been set on the device.
}

override fun onFailure(error: ResearchBitError) {
    // Called if there is an error during the requested action.
    Log.d(TAG, "Scan Failure: $error")
}
```

## References
* [Android Developer - Bluetooth Documentation](https://developer.android.com/reference/android/bluetooth/package-summary)
* [Android Developer - Bluetooth Low Energy Documentation](https://developer.android.com/guide/topics/connectivity/bluetooth/ble-overview)
* [Third Party Android BLE Guide](https://punchthrough.com/android-ble-guide/)
