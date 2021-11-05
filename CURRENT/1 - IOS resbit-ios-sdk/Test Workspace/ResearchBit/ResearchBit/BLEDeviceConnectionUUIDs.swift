//
//  BLEDeviceConnectionUUIDs.swift
//  ResearchBit
//
//  Created by Grant Courts on 12/17/19.
//  Copyright © 2019 Stan Rosenbaum. All rights reserved.
//

import UIKit
import CoreBluetooth

open class ResBitVendorSpecificUUID {
    public static func getFullUUIDForID(ID: String) -> CBUUID {
        return CBUUID(string: "240F" + ID + "-2498-4B36-BC0C-EDCCC32D0635")
    }
}

open class ResBitSummaryService {
    static let uuid = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA00") // TBD
    
    static let charUUIDData = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA01")
    static let charUUIDTransferSummaryData = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA02")
    static let charUUIDTransferring = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA03")
    static let charUUIDAckNack = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA04")
    static let charUUIDResponse = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA05")
    static let charUUIDRegistered = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA06")
    static let charUUIDEnableDebug = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA07")
    static let charUUIDResbitSerialNumber = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA08")
    static let charUUIDResbitTransferError = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "AA09")
}

open class ResBitDeviceInfoService {
    static let uuid = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "180A") // TBD
    
    static let charUUIDManufacturerName = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A29")
    static let charUUIDModuleNumber = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A24")
    static let charUUIDSerialNumber = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A25")
    static let charUUIDHardwareRevision = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A27")
    static let charUUIDFirmwareRevision = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A26")
    static let charUUIDSoftwareRevision = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A28")
    static let charUUIDSystemID = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "2A23")
}

open class BLEDeviceServiceUUIDS {
    static let deviceInfoService = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "180A")
    static let summaryService = ResBitVendorSpecificUUID.getFullUUIDForID(ID: "180A") // TBD
    
    public static func serviceIDNordicChip() -> CBUUID {
        return CBUUID(string: "00001523-1212-EFDE-1523-785FEABCD123")
    }
    
    public static func serviceIDResBit() -> CBUUID {
        // placeholder
        return CBUUID(string: "00000000-1212-EFDE-1523-785FEABCD123")
    }
    
    public static func servicesAll() -> [CBUUID] {
        return [serviceIDNordicChip(), serviceIDResBit()]
    }
}

open class BLEDeviceCharacteristicUUIDS {
    static let DataUUID = CBUUID(string: "00001524-1212-EFDE-1523-785FEABCD123")
    
    public static func characteristicIDsNordicChip() -> [CBUUID] {
        let buttonStateUUID = CBUUID(string: "00001524-1212-EFDE-1523-785FEABCD123")
        let LEDStateUUID = CBUUID(string: "00001525-1212-EFDE-1523-785FEABCD123")
        return [buttonStateUUID, LEDStateUUID]
    }
    
    public static func characteristicIDsResBit() -> [CBUUID] {
        
        let ShouldTransferSummaryDataUUID = CBUUID(string: "00001525-1212-EFDE-1523-785FEABCD123")
        return [ShouldTransferSummaryDataUUID]
    }
}
