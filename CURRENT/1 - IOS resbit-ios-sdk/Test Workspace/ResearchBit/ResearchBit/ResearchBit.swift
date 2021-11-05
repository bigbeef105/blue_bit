//
//  ResearchBit.swift
//  RESEARCH_BIT_FRAMEWORK
//
//  Created by Stan Rosenbaum on 11/18/19.
//  Copyright © 2019 Stan Rosenbaum. All rights reserved.
//

import Foundation
import CoreBluetooth

// MARK: - ResearchBit Class

/**
Main entry point for Framework
Bridges Framework to the Client App.
The client should only ever have to call functions from here.
Think of this as the interface to the Framework for the client
*/
open class ResearchBit {
	
	// MARK: - Properties
	var rbtbManager = RBBTManager.shared
	var researchBitDataFormatter = ResearchBitDataFormatter()
	
	// MARK: - Inits
	public init() {}
	
	// MARK: - Class Methods
    
    /**
     Scan for available Resbit or Nordic Chip devices.
     
     - Parameter scanTime: The length of time in seconds to wait before stopping the scan and returning results.
     - Parameter result: An array of Peripherals found during the scan on success, or a ResearchBitError on fail. Note that a peripheral is only added to this array if it is a Resbit or Nordic Chip device, and the peripheral object itself is not very useful until you use it to create a BLEDevice object via the 'getBLEDevice' function
     - Returns: An array containing all of the peripherals that were found during the scan on success, or a ResearchBitError on fail.
     */
    public func scanForBLEDevices(scanTime: Int, completionHandler:@escaping RBBTManager.ScanCompletionHandler) {
        rbtbManager.scanForBLEDevices(scanTime: scanTime) { (result) in
            completionHandler(result)
        }
    }
    
    /**
    Fetch/create a BLEDevice object from a given peripheral
     
     - Parameter peripheral: The peripheral that you want to pull data from.
     - Parameter result: A BLEDevice object containing device info on success, or a ResearchBitError on fail.
     - Returns: A BLEDevice object
    */
    public func getBLEDevice(peripheral: CBPeripheral, completionHandler:@escaping RBBTManager.BLEDeviceCompletionHandler) {
        rbtbManager.getBLEDeviceInfo(peripheral: peripheral) { (result) in
            completionHandler(result)
        }
    }
    
    /**
    Fetch the summary data from a given BLEDevice.
     
     - Parameter device: The device that you want to pull data from.
     - Parameter result: An array containing SummaryData objects on success, or a ResearchBitError on fail. Each object in this array represents one piece of summary data pulled from the device. The summary data is NOT automatically added to the passed-in device so it only exists in the returned array.
     - Returns: An array containing all of the available sumamry data for a given device on success, or a ResearchBitError on fail.
    */
    public func getBLEDeviceSummaryData(device: BLEDevice, completionHandler:@escaping RBBTManager.SummaryDataCompletionHandler) {
        rbtbManager.getBLEDeviceSummaryData(device: device, finishedRetrievingData: { (result) in
            completionHandler(result)
        })
    }
    
    /**
        Fetch summary data from a given BLEDevice with specific UUID.
     
        - Parameter peripheralUUID: The UUID of the device you want to restore connection to and retrieve data from. If you want to use this function, then store the peripheral UUID in something like UserDefaults during the initial scan.
        - Parameter result: An array containing SummaryData objects on success, or a ResearchBitError on fail. Each object in this array represents one piece of summary data pulled from the device. The summary data is NOT automatically added to the passed-in device so it only exists in the returned array.
     
        - Returns: An array containing all of the available sumamry data for a given device on success, or a ResearchBitError on fail.
     */
    public func getBLEDeviceSummaryData(peripheralUUID: UUID, completionHandler:@escaping RBBTManager.SummaryDataCompletionHandler) {
        rbtbManager.getBLEDeviceSummaryData(peripheralUUID: peripheralUUID, finishedRetrievingData: { (result) in
            completionHandler(result)
        })
    }
}

// MARK: - ResearchBitDataFormatter Class

/**
Formats the data from BlueTooth to whatever the Clients want.
*/
internal class ResearchBitDataFormatter {
	
	internal func formatData() -> [Int] {
		return[1,2,3,4,5]
	}
	
}
