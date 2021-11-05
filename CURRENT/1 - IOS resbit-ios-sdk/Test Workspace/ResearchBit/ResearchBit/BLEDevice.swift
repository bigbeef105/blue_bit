//
//  BLEDevice.swift
//  ResearchBit
//
//  Created by Grant Courts on 11/26/19.
//  Copyright © 2019 Stan Rosenbaum. All rights reserved.
//

import UIKit
import CoreBluetooth

public struct BLEDevice {
    public var deviceName: String?
    public var lastSyncTime: Date
    public var dataIsAvailable: Bool
    public var batteryLifePercentage: Int
    public var summaryData: [SummaryData] = [SummaryData]()
    public var serialID: String
    public var peripheral: CBPeripheral
    public var iBeaconUUID: UUID
    public var iBeaconMajor: Int
    public var iBeaconMinor: Int
    
    public static func GetFormattedJSON() -> String {
        return "There's nothing here yet..."
    }
    
    init(peripheral: CBPeripheral, theSerialID: String, theiBeaconUUID: UUID, theiBeaconMajor: Int, theiBeaconMinor: Int) {
        self.peripheral = peripheral
        self.serialID = theSerialID
        self.deviceName = peripheral.name
        self.iBeaconUUID = theiBeaconUUID
        self.iBeaconMajor = theiBeaconMajor
        self.iBeaconMinor = theiBeaconMinor
        
        // Below is temporary since nordic dongles don't have a battery life or sync time or data(this is just for testing)
        self.lastSyncTime = Date()
        self.batteryLifePercentage = Int.random(in: 0...100)
        
        self.dataIsAvailable = true
        
        print("BLE Serial ID: \(serialID)")
        print(self.debugDescription)
    }
    
    public var debugDescription: String {
        return """
        BLE Device Info: {
            deviceName: "\(deviceName ?? "nil")"
            lastSyncTime: "\(lastSyncTime)"
            dataIsAvailable: "\(dataIsAvailable)"
            batteryLifePercentage: "\(batteryLifePercentage)"
            summaryData: "\(summaryData)"
            serialID: "\(serialID)"
            peripheral: "\(peripheral)"
            iBeaconUUID: "\(iBeaconUUID.uuidString)"
            iBeaconMajor: "\(iBeaconMajor)"
            iBeaconMinor: "\(iBeaconMinor)"
        }
        """
    }
}

//open class ResbitDevice: BLEDevice {
//
//}
//
//open class NordicDongle: BLEDevice {
//
//}
