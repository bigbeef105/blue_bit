# P&G ResearchBIT SDK Documentation
Stan Rosenbaum - Nov 2019

This project is P&G's ResearchBIT SDK Framework.


# Goal

Provide a collection point for ResearchBIT BlueTooth sensors.


# Important: Apple Privacy Permissions

Make sure the BlueTooth permissions are set or else the App will crash.

Add the following keys to the info.Plist of the App:

    Privacy - Bluetooth Peripheral Usage Description
    Required background modes:
        App communicates using CoreBluetooth

# Architecture

This is P&G's SDK for P&G ResearchBIT.  The purpose is to gather data from the ResearchBIT sensors and deliver the formatted data to a client app.

This project is an iOS Framework, with a Debug app.

Note: The framework will appear as a folder on Windows computers. In order to use this SDK you need a Mac with Xcode installed.

# Using the Framework 

1) Drag 'ResearchBit.framework' into your project, ensuring that your project is set as a target on the import settings. 
2) Insert the text 'import ResearchBit' at the top of the file in which you want to use the ResearchBit framework.
3) Define a local instance of ResearchBit, i.e. 'var researchBit: ResearchBit = ResearchBit()'.
4) That's it! Now just use the function calls defined in ResearchBit.swift :
```
    1. scanForBLEDevices(completionHandler:@escaping (_ result: [BLEDevice], _ error: NSError?) -> Void
    2. getBLEDeviceSummaryData(device: BLEDevice, completionHandler:@escaping (_ result: [SummaryData], _ error: NSError?) -> Void
    3. getBLEDeviceSummaryData(peripheralUUID: UUID, completionHandler:@escaping (_ result: [SummaryData]?, _ error: NSError?) -> Void
```

Code snippets for given functions:

```
1. researchBit.scanForBLEDevices() { (deviceList, error) in
            if let theError = error {
                print(theError.localizedFailureReason!)
            } else {
                self.BLEDevices = deviceList
            }
   }
```
```
2. researchBit.getBLEDeviceSummaryData(device: device) { (result, error) in
            if let theError = error {
                print(theError.localizedFailureReason!)
            }
            let summaryData = result
            for data in summaryData {
                // do something with the data
            }
     }
```
```
3. if let peripheralIdStr = UserDefaults.standard.object(forKey: "peripheralIDKey") as? String, let peripheralId = UUID(uuidString: peripheralIdStr) {
            researchBit.getBLEDeviceSummaryData(peripheralUUID: peripheralId) { (result, error) in
                let summaryData = result
                for data in summaryData {
                    // do something with the data
                }
            }
    }
```
Note: Within the source files for this framework is a project called, "ResearchBitDebugApp". This is an example project showing how the framework can be used. Examine the 'ViewController.swift' file for an example of how the listed function calls can be used (this is where the above code snippets come from).

# Function Definitions

1. scanForBLEDevices(completionHandler:@escaping (_ result: [BLEDevice], _ error: NSError?) -> Void)

    Scan for available Resbit or Nordic Chip devices.
         
    - **Parameter scanTime:** The length of time in seconds to wait before stopping the scan and returning results.
    - **Parameter result:** An array of BLEDevices found during the scan. Each device will be populated with a name, battery life, and a bool representing whether or not there is data available to pull from that device. Note that a device is only added to this array if it is a Resbit or Nordic Chip device.
    - **Parameter error:** An NSError containing a description as to why the scan may have failed, or nil if the scan did not fail.
    - **Returns:** An array containing all of the BLEDevices that were found during the scan.

2. getBLEDeviceSummaryData(device: BLEDevice, completionHandler:@escaping (_ result: [SummaryData], _ error: NSError?) -> Void

    Fetch the summary data from a given BLEDevice.
         
    - **Parameter device:** The device that you want to pull data from.
    - **Parameter result:** An array containing SummaryData objects. Each object in this array represents one piece of summary data pulled from the device. The summary data is NOT automatically added to the passed-in device so it only exists in the returned array.
    - **Parameter error:** An NSError containing a description as to why the data fetch may have failed, or nil if it did not fail.
    - **Returns:** An array containing all of the available summary data for a given device.

3. getBLEDeviceSummaryData(peripheralUUID: UUID, completionHandler:@escaping (_ result: [SummaryData]?, _ error: NSError?) -> Void

    Fetch the summary data from a given BLEDevice with a specific UUID. This function can only be used if you've previously scanned and retrieved a nearby BLEDevice(s), and have already stored the UUID assigned to that BLEDevice(s) peripheral object locally on the device. If you've done so, you can use this function to connect and retrieve data directly from a peripheral(s) without having to re-scan.
         
    - **Parameter peripheralUUID:** The UUID of the device you want to restore connection to and retrieve data from. If you want to use this function, then store the peripheral UUID in something like UserDefaults during the initial scan.
    - **Parameter result:** An array containing SummaryData objects. Each object in this array represents one piece of summary data pulled from the device. The summary data is NOT automatically added to the passed-in device so it only exists in the returned array.
    - **Parameter error:** An NSError containing a description as to why the data fetch may have failed, or nil if it did not fail.
    - **Returns:** An array containing all of the available summary data for a given device.

# Data Objects

The framework also defines several custom data types in order to efficiently pass data around:

1. BLEDevice.swift

    BLE Devices returned from a scan will take the form of this object. 

    - **Property deviceName:** A String containing the human-readable name of the BLE Device that was found.
    - **Property dataIsAvailable:** A bool defining whether or not there is SummaryData available to pull from the BLE Device. True if data is available, False if the data is already synced.
    - **Property lastSyncTime:** The Date of the last time in which the device's data was synced to the app/server (we might change where this property is stored/comes from, so this one is possibly only temporary).
    - **Property batteryLifePercentage:** An Int containing the devices battery life percentage (0-100). This is also only temporary, as I believe that we don't have a good way of getting this information during a scan.
    - **Property summaryData:** An Array of SummaryData pulled from the device. This is never populated by the framework, and only exists in case the main app wants to link pulled SummaryData to the BLEDevice object for easy access.
    - **Property peripheral:** A CBPeripheral object which is what the CoreBluetooth framework uses to reference connectable BLE Devices. The idea was to abstract all useful information from this object into the BLEDevice object, but in case there's any useful data/properties that were not abstracted out, the entire peripheral object is available for use.

    Note: Eventually we will have subclasses of the BLEDevice object: ResbitDevice and NordicDongle. As of now it is unclear how much these two BLE Devices will actually differ so there is currently no use for them.

2. SummaryData.swift

    The data pulled from a BLE Device will take the form of this object. Each SummaryData object consists of a single event held on the BLE Device, remember that when pulling data you'll typically receive an array of a large number of these objects/events.

    - **Property eventType:** There are currently only 2 events types, one represents number of trigger pulls on a researchbit device for a given session, the other being a representation of how long that device was awake for that same session.
    - **Property eventUUID:** A unique identifier associated with this event.
    - **Property eventDataSize:** The total size of this event object and the data inside it.
    - **Property eventWakeupTime:** The time at which this event was recorded. A 'trigger pulls' event and a 'time awake' event will both share the same value for this property. If these two events share the same value for this property, then we know they were both referencing the same device usage session.
    - **Property eventFields:** The actual values of the trigger pulls or wakeup time. As of now its just one value for either event type, but its setup as an array in case events have additional fields/values in the future.

3. BLEDeviceConnectionUUIDs.swift

    This file/script stores all the unique identifiers for the services and characteristics that we are looking for. BLE Devices will advertise packets containing these UUIDs, so these determine what devices we can scan for and connect to. Users of this framework should really have no need to even look at this file, but for those that are curious to the ways of BLE there's a bit more information below.

    - **serviceID:** Services are the data form used to advertisement and transmit data from the BLE Device. BLE Devices typically only have a single service, but can have multiple. Service IDs are unique, so if we search for a specific service UUID, we will only receive notifications in our framework when we find devices that are advertising a matching service UUID. Once we find a device with this service UUID, we know we've found one of our ResearchBit or Nordic Chip devices.

    - **characteristicID:** Once we've identified our BLE Device as the correct type of device using the service ID, we can then try to fetch our desired data from that device. There's a handful of data on the BLE device that we can pull, but we only want some of it. Characteristics are what define and hold the data for transfer on the BLE Device, and each defined characteristic on that device represents a specific piece of data that we might want to pull. For example, our Nordic Chips have characteristics representing battery life, LED status, device name, or state of the button(pressed up or down). We might only care about one or two of those. So, instead of pulling all four characteristics, we define the UUIDs for just a couple of them like the LED status or button state. Then, when we go to fetch data from the Nordic Chip, we'll only receive notifications/data for those two characteristics. This saves us some energy by not having to pull things like the battery life and device name when we don't want them.

# References

## BlueTooth on iOS

[Working with Core Bluetooth](https://www.appcoda.com/core-bluetooth/)

[Bluetooth Sample Code](http://www.splinter.com.au/2019/06/06/bluetooth-sample-code/)

[Bluetooth Primer, really good](http://www.splinter.com.au/2019/05/18/ios-swift-bluetooth-le/index.html)

[iOS Bluetooth in 20 minutes](https://www.freecodecamp.org/news/ultimate-how-to-bluetooth-swift-with-hardware-in-20-minutes/)

[12 Steps of Bluetooth](https://www.kevinhoyt.com/2016/05/20/the-12-steps-of-bluetooth-swift/)


## Swift Bluetooth Playground

[Swift Bluetooth Playgound](https://blog.untitledkingdom.com/swift-playground-bluetooth-low-energy-8fe15eb2e6df)

## Building Swift Frameworks

[Creating Swift Framework](https://www.raywenderlich.com/5109-creating-a-framework-for-ios)


