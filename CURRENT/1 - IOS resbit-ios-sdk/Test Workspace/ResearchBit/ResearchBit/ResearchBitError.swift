//
//  ResearchBitErrors.swift
//  ResearchBit
//
//  Created by Grant Courts on 2/5/20.
//  Copyright © 2020 Stan Rosenbaum. All rights reserved.
//

import UIKit

enum ResearchBitError: Error {
    case BLEPoweredOff
    case BLEConnectionTimeout
    case BLEIdentifierNotFound
    case BLEServiceFetchTimeout
    case BLECharacteristicFetchTimeout
}

extension ResearchBitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .BLEPoweredOff:
            return NSLocalizedString("Bluetooth is not powered on or it is in unknown state.", comment: "Please turn on Bluetooth before attempting to scan.")
        case .BLEConnectionTimeout:
            return NSLocalizedString("Timed out while attempting connection to device.", comment: "It took longer than 10 seconds to connect to the BLE device.")
        case .BLEIdentifierNotFound:
            return NSLocalizedString("Could not find a peripheral to restore with that identifier.", comment: "A peripheral with the given UUID could not be found on this device.")
        case .BLEServiceFetchTimeout:
            return NSLocalizedString("Timed out while attempting to fetch services for this peripheral.", comment: "It took longer than 10 seconds to fetch services from this peripheral.")
        case .BLECharacteristicFetchTimeout:
            return NSLocalizedString("Timed out while attempting to fetch characteristics for this peripheral.", comment: "It took longer than 10 seconds to fetch characteristics from this peripheral.")
        }
    }
}
