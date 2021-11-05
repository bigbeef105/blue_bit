//
//  RBBTManager.swift
//  RESEARCH_BIT_FRAMEWORK
//
//  Created by Stan Rosenbaum on 11/18/19.
//  Copyright © 2019 Stan Rosenbaum. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
The helper for dealing with Bluetooth and talking to sensor.
Also the Adaptee in the Adapter Pattern

- SeeAlso - [This class is based on the example code found here.](http://www.splinter.com.au/2019/06/06/bluetooth-sample-code/)

*/

public class RBBTManager {
	
	public static let shared = RBBTManager()
	
	fileprivate static let restoreIdKey = "RBBTManager"
	fileprivate static let peripheralIdDefaultsKey = "RBBTManagerPeripheralId"
	fileprivate static let outOfRangeHeuristics: Set<CBError.Code> = [.unknown,
																	  .connectionTimeout,
																	  .peripheralDisconnected,
																	  .connectionFailed]
	
	private var centralManager: CBCentralManager?
    var validPeripherals: [CBPeripheral] = [CBPeripheral]()
    
    let central = CBCentralManager(delegate: MyCentralManagerDelegate.shared,
                                   queue: nil,
                                   options: [
                                    CBCentralManagerOptionRestoreIdentifierKey: restoreIdKey,])
    
    public typealias ScanCompletionHandler = (_ result: Result<[CBPeripheral], Error>) -> Void
    public typealias BLEDeviceCompletionHandler = (_ result: Result<BLEDevice, Error>) -> Void
    public typealias SummaryDataCompletionHandler = (_ result: Result<[SummaryData], Error>) -> Void
    
    public var BLEDeviceCompletion: BLEDeviceCompletionHandler?
    public var summaryDataCompletion: SummaryDataCompletionHandler?
    
    public var deviceScanTime = 5;
    // A single packet is respresented by a [UInt8]
    // So, a chunk is a group, or an array of packets [[UInt8]]
    public var packetsReceivedInChunk: [[UInt8]] = [[UInt8]]()
    // So, group of chunks, or the total chunks we receive in a given fetch can be represented by a [[[UInt8]]]
    public var totalPacketChunksReceived: [[[UInt8]]] = [[[UInt8]]]()
    public var missedPackets = [Int]()
    public var recievedAllPackets = false
    
    public var startTimeInMilliseconds: Int64 = Int64((NSDate().timeIntervalSince1970 * 1000.0).rounded())
    
    public init(){}
    
    public var btState: CBManagerState {
        return central.state
    }
    
	/// The 'state machine' for remembering where we're up to.
	var state = State.poweredOff
	enum State {
		case poweredOff
		case restoringConnectingPeripheral(CBPeripheral)
		case restoringConnectedPeripheral(CBPeripheral)
		case disconnected
		case scanning(Countdown)
		case connecting(CBPeripheral, Countdown)
		case discoveringServices(CBPeripheral, Countdown)
		case discoveringCharacteristics(CBPeripheral, Countdown)
		case connected(CBPeripheral)
		case outOfRange(CBPeripheral)
		
		var peripheral: CBPeripheral? {
			switch self {
				case .poweredOff: return nil
				case .restoringConnectingPeripheral(let p): return p
				case .restoringConnectedPeripheral(let p): return p
				case .disconnected: return nil
				case .scanning: return nil
				case .connecting(let p, _): return p
				case .discoveringServices(let p, _): return p
				case .discoveringCharacteristics(let p, _): return p
				case .connected(let p): return p
				case .outOfRange(let p): return p
			}
		}
	}
    
    func scanForBLEDevices(scanTime: Int, completion: @escaping ScanCompletionHandler) {
        let nordicChipServices = BLEDeviceServiceUUIDS.serviceIDNordicChip()
        
        scan(scanTime: scanTime, devicesWithServiceIDs: [nordicChipServices, ResBitSummaryService.uuid, ResBitDeviceInfoService.uuid]) { (result) in
            completion(result)
        }
    }
    
    func getBLEDeviceInfo(peripheral: CBPeripheral, finishedRetrievingData:@escaping BLEDeviceCompletionHandler) {
        BLEDeviceCompletion = finishedRetrievingData
        
        connect(peripheral: peripheral)
    }
    
    func getBLEDeviceSummaryData(device: BLEDevice, finishedRetrievingData:@escaping SummaryDataCompletionHandler) {
        summaryDataCompletion = finishedRetrievingData
        totalPacketChunksReceived.removeAll()
        
        connect(peripheral: device.peripheral)
    }
    
    func getBLEDeviceSummaryData(peripheralUUID: UUID, finishedRetrievingData:@escaping SummaryDataCompletionHandler) {
       summaryDataCompletion = finishedRetrievingData
       totalPacketChunksReceived.removeAll()
        
       connect(peripheralUUID: peripheralUUID)
   }
	
	/**
	Begin scanning here!
	*/
    func scan(scanTime: Int, devicesWithServiceIDs: [CBUUID], completion: @escaping ScanCompletionHandler) {
		guard central.state == .poweredOn else {
            completion(.failure(ResearchBitError.BLEPoweredOff))
			return
		}
		
		// Scan!
        LogToScreen(text: "Starting scan...")
        LogToScreen(text: "Searching for devices with service IDs: " + ResBitSummaryService.uuid.uuidString)
//        LogToScreen(text: "Searching for devices with service IDs: " + BLEDeviceServiceUUIDS.serviceIDNordicChip().uuidString)
        
//        for serviceID in devicesWithServiceIDs {
//            LogToScreen(text: serviceID.uuidString)
//        }
        
        // Create new validPeripherals array for storing all nearby valid peripherals
        validPeripherals = [CBPeripheral]()
        // Start scanning, this will callback to the delegate function 'didDiscover peripheral: CBPeripheral'
        central.scanForPeripherals(withServices: [ResBitSummaryService.uuid], options: nil)
//        central.scanForPeripherals(withServices: [BLEDeviceServiceUUIDS.serviceIDNordicChip()], options: nil)
        // Stop the scan after we've reached our defined time limit
        state = .scanning(Countdown(seconds: TimeInterval(scanTime), closure: {
			self.central.stopScan()
			self.state = .disconnected
            completion(.success(self.validPeripherals))
		}))
	}
	
	/**
	Call this with forget: true to do a proper unpairing such that it won't
	try reconnect next startup.
	*/
	func disconnect(forget: Bool = false) {
		if let peripheral = state.peripheral {
			central.cancelPeripheralConnection(peripheral)
		}
		state = .disconnected
	}
	
    // Connect to a given peripheral, only works if the UUID of the peripheral matches the service UUIDs defined in 'BLEDeviceConnectionUUIDs'
	func connect(peripheral: CBPeripheral) {
		// Connect!
		// Note: We're retaining the peripheral in the state enum because Apple
		// says: "Pending attempts are cancelled automatically upon
		// deallocation of peripheral"
        LogToScreen(text: "Attempting to connect...")
        if let name = peripheral.name {
            LogToScreen(text: name)
        }
        
        
//        DispatchQueue.main.async {
            self.central.connect(peripheral, options: nil)
//        }
        
        state = .connecting(peripheral, Countdown(seconds: 10, closure: {
            self.central.cancelPeripheralConnection(peripheral)
			self.state = .disconnected
            
            if let completionHandler = self.summaryDataCompletion {
                completionHandler(.failure(ResearchBitError.BLEConnectionTimeout))
                self.summaryDataCompletion = nil
            } else if let completionHandler = self.BLEDeviceCompletion {
                completionHandler(.failure(ResearchBitError.BLEConnectionTimeout))
                self.BLEDeviceCompletion = nil
            }
		}))
	}
    
    // Connect to a peripheral with the given UUID. This UUID is given to the peripheral the first time it is discovered during a scan. The UUID is not stored on the peripheral and must be saved locally to the iOS device in order to use it again in the future. This function allows us to connect to peripherals we've previously connected to without having to scan for them again.
    func connect(peripheralUUID: UUID) {
        if let previouslyConnected = central.retrievePeripherals(withIdentifiers: [peripheralUUID]).first {
            RBBTManager.shared.connect(peripheral: previouslyConnected)
        } else {
            if let completionHandler = self.summaryDataCompletion {
                completionHandler(.failure(ResearchBitError.BLEIdentifierNotFound))
                self.summaryDataCompletion = nil
            } else if let completionHandler = self.BLEDeviceCompletion {
                completionHandler(.failure(ResearchBitError.BLEIdentifierNotFound))
                self.BLEDeviceCompletion = nil
            }
        }
    }
	
    // This function requests for the specific services of a given peripheral and calls back to the delegate function 'didDiscoverServices' when they are found.
	func discoverServices(peripheral: CBPeripheral) {
		peripheral.delegate = MyPeripheralDelegate.shared
        
        // Discover a different service depending on which callback is currently active.
        if let callback = RBBTManager.shared.summaryDataCompletion {
            peripheral.discoverServices([ResBitSummaryService.uuid])
            state = .discoveringServices(peripheral, Countdown(seconds: 10, closure: {
                callback(.failure(ResearchBitError.BLEServiceFetchTimeout))
                RBBTManager.shared.summaryDataCompletion = nil
                
                self.disconnect(forget: true)
            }))
        } else if let callback = RBBTManager.shared.BLEDeviceCompletion {
            peripheral.discoverServices([ResBitSummaryService.uuid])
            state = .discoveringServices(peripheral, Countdown(seconds: 10, closure: {
                callback(.failure(ResearchBitError.BLEServiceFetchTimeout))
                RBBTManager.shared.BLEDeviceCompletion = nil
                
                self.disconnect(forget: true)
            }))
        } else {
            LogToScreen(text: "Callback isn't set... not sure how we got here.")
        }
	}
	
    // This function requests for the specific characteristics of a given peripheral and calls back to the delegate function 'didDiscoverCharacteristics' when they are found.
	func discoverCharacteristics(peripheral: CBPeripheral) {
		peripheral.delegate = MyPeripheralDelegate.shared
        if let services = peripheral.services {
            for service in services {
                if let callback = RBBTManager.shared.summaryDataCompletion {
                    if(service.uuid == ResBitSummaryService.uuid) {
                        MyPeripheralDelegate.shared.characteristicsToDiscover =
                            [ResBitSummaryService.charUUIDTransferring,
                            ResBitSummaryService.charUUIDData]
                        
                        peripheral.discoverCharacteristics(
                            MyPeripheralDelegate.shared.characteristicsToDiscover,
                                                           for: service)
                    }
                    
                    state = .discoveringCharacteristics(peripheral, Countdown(seconds: 10, closure: {
                        callback(.failure(ResearchBitError.BLECharacteristicFetchTimeout))
                        RBBTManager.shared.summaryDataCompletion = nil
                        RBBTManager.shared.disconnect(forget: true)
                    }))
                } else if let callback = RBBTManager.shared.BLEDeviceCompletion {
                    if(service.uuid == ResBitSummaryService.uuid) {
                        MyPeripheralDelegate.shared.characteristicsToDiscover =
                            [ResBitSummaryService.charUUIDResbitSerialNumber
                            ]
                        
                        peripheral.discoverCharacteristics(MyPeripheralDelegate.shared.characteristicsToDiscover,
                                                           for: service)
                    }
                    
                    state = .discoveringCharacteristics(peripheral, Countdown(seconds: 10, closure: {
                        callback(.failure(ResearchBitError.BLECharacteristicFetchTimeout))
                        RBBTManager.shared.BLEDeviceCompletion = nil
                        RBBTManager.shared.disconnect(forget: true)
                    }))
                }
            }
        }
	}
    
    func discoverCharacteristic(peripheral: CBPeripheral, serviceUUID: CBUUID, characteristicUUID: CBUUID) {
        if let services = peripheral.services {
            for service in services {
                if(service.uuid == ResBitSummaryService.uuid) {
                    MyPeripheralDelegate.shared.characteristicsToDiscover = [characteristicUUID]
                    peripheral.discoverCharacteristics(MyPeripheralDelegate.shared.characteristicsToDiscover, for: service)
                }
            }
        }
    }
    
    func formatPacketsIntoSummaryData(packetChunks: [[[UInt8]]]) -> [SummaryData] {
        // packets = one full chunk of packets, where each packet is a [UInt8]
        var allSummaryDataEventsReceived = [SummaryData]()
        
        var chunkCount = 1
        for packetChunk in packetChunks {
            let formattedSummaryDataInChunk = getAllSummaryDataEventsFromPacketChunk(packetChunk: packetChunk)
            allSummaryDataEventsReceived.append(contentsOf: formattedSummaryDataInChunk)
            chunkCount += 1
        }
        
        return allSummaryDataEventsReceived
    }
    
    func getAllSummaryDataEventsFromPacketChunk(packetChunk: [[UInt8]]) -> [SummaryData] {
        // We'll take all the packets and pull out the unnecessary data(indexes 0 and 1 of each packet)
        // Then, we'll have the entire summary data stream combined into one object that we can parse through
        var allPacketDataCombined = [UInt8]()
        
        for packet in packetChunk {
            for i in 0...packet.count - 1 {
                //  First values are just total packets and the packet index, we can ignore them
                if(i != 0 && i != 1) {
                    allPacketDataCombined.append(packet[i])
                }
            }
        }
        
        return parsePacketChunkPacketDataIntoSummaryData(allChunkPacketData: allPacketDataCombined);
    }
    
    func parsePacketChunkPacketDataIntoSummaryData(allChunkPacketData: [UInt8]) -> [SummaryData] {
        var allSummaryDataInChunk = [SummaryData]()
        var mutablePacketStream = allChunkPacketData
        
        while mutablePacketStream.count > 0 {
            
            // A single packet holds up to 18 bytes of event summary data. In the worst case, the last received packet may only contain
            // a single byte of event summary data, and the last 17 bytes are just garbage filler data. If we're within the last 17 bytes,
            // we need to check if there's still summary data left, or if its just garbage filler. If its all 0's then its filler and we can ignore it all.
            if(mutablePacketStream.count < 18) {
                // Let's check if there's one more summary event left in here...
                var eventSummaryExists = false
                for i in 0...mutablePacketStream.count - 1 {
                    if(mutablePacketStream[i] != 0) {
                        // Found a value that isn't 0, that means there must be some usable data in here
                        eventSummaryExists = true
                    }
                }
                
                // If the summary event doesn't exists we'll break out of the while loop, otherwise continue to record this last event.
                if(!eventSummaryExists) {
                    break
                }
            }
            
            var summaryEventDataArray = [UInt8]()
            var timeData = [UInt8]()
            // Starting 2 indices will contain summary event ID as a uint16
            let summaryIDDataArray = [mutablePacketStream[0], mutablePacketStream[1]]
            let summaryIDData = NSData(bytes: summaryIDDataArray, length: 2)
            var summaryID: UInt16 = 0
            summaryIDData.getBytes(&summaryID, length: 2)
            summaryID = UInt16(littleEndian: summaryID)
            mutablePacketStream.remove(at: 0)
            mutablePacketStream.remove(at: 0)
            
            if(mutablePacketStream.count == 0) {
                LogToScreen(text: "Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                break
            }
            
            // The next 4 indexes after that are the time value of the event, let's grab those.
            for _ in 0...3 {
                timeData.append(mutablePacketStream[0])
                mutablePacketStream.remove(at: 0)
                if(mutablePacketStream.count == 0) {
                    LogToScreen(text: "Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                    break
                }
            }
            // The next index after the time value is the length of the upcoming data for this event, so grab that
            if(mutablePacketStream.count == 0) {
                LogToScreen(text: "Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                break
            }
            
            let lengthOfData = mutablePacketStream[0]
            mutablePacketStream.remove(at: 0)
            if(mutablePacketStream.count == 0) {
                LogToScreen(text: "Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                break
            }
            
            if(lengthOfData != 0) {
                // Now let's grab all the data that belongs to this summary event
                for _ in 0...lengthOfData - 1 {
                    summaryEventDataArray.append(mutablePacketStream[0])
                    mutablePacketStream.remove(at: 0)
                    if(mutablePacketStream.count == 0) {
                        LogToScreen(text: "Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                        break
                    }
                }
            }
            
            let summaryDataEvent = formatParsedPacketIntoSummaryData(eventType: Int(summaryID), timeData: timeData, dataLength: Int(lengthOfData), eventData: summaryEventDataArray)
            
            allSummaryDataInChunk.append(summaryDataEvent)
        }
        
        return allSummaryDataInChunk
    }
    
    func formatParsedPacketIntoSummaryData(eventType: Int, timeData: [UInt8], dataLength: Int, eventData: [UInt8]) -> SummaryData {
        // We have to convert the timeData 4 byte array into a 32bit integer. This will be time in Unix time.
        var timeValue : UInt32 = 0
        let data = NSData(bytes: timeData, length: 4)
        data.getBytes(&timeValue, length: 4)
        timeValue = UInt32(littleEndian: timeValue)
        
        // Actually create summary data object here
        return SummaryData(type: eventType, dataSize: dataLength, time: Int(timeValue), data: eventData)
    }
}

class MyPeripheralDelegate: NSObject, CBPeripheralDelegate {
	
	static let shared = MyPeripheralDelegate()
    public var characteristicsToDiscover = [CBUUID]()
    
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		// Ignore services discovered late.
		guard case .discoveringServices = RBBTManager.shared.state else {
			return
		}

		if let error = error {
            if let callback = RBBTManager.shared.summaryDataCompletion {
                callback(.failure(error))
                RBBTManager.shared.summaryDataCompletion = nil
            } else if let callback = RBBTManager.shared.BLEDeviceCompletion {
                callback(.failure(error))
                RBBTManager.shared.BLEDeviceCompletion = nil
            }
            
			RBBTManager.shared.disconnect(forget: true)
			return
		}
		
        LogToScreen(text: "Discovering characteristics")
		// Verified our desired service(s) exist for this peripheral, now lets check for our desired characteristics.
		RBBTManager.shared.discoverCharacteristics(peripheral: peripheral)
	}
	
	func peripheral(_ peripheral: CBPeripheral,
					didDiscoverCharacteristicsFor service: CBService,
					error: Error?) {
		// Ignore characteristics arriving late.
		guard case .discoveringCharacteristics =
			RBBTManager.shared.state else { return }
		
		if let error = error {
            if let callback = RBBTManager.shared.summaryDataCompletion {
                callback(.failure(error))
                RBBTManager.shared.summaryDataCompletion = nil
            } else if let callback = RBBTManager.shared.BLEDeviceCompletion {
                callback(.failure(error))
                RBBTManager.shared.BLEDeviceCompletion = nil
            }
            
            RBBTManager.shared.disconnect(forget: true)
            return
        }
		
		// We've found our desired characteristics for this peripheral, let's go ahead and request the data from them. 'readValue' will callback to the 'didUpdateValueFor' delegate function.
        if(service.uuid == ResBitSummaryService.uuid) {
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    if(!characteristicsToDiscover.contains(characteristic.uuid)) {
                        continue
                    }
                    
                    // Subscribe to all this stuff as the resbit device will update it in order to tell us when there's new data or when data transfer is finished.
                    if(characteristic.uuid == ResBitSummaryService.charUUIDData) {
                        // Once transmission starts the data characteristic will update with the first group of packet data
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if(characteristic.uuid == ResBitSummaryService.charUUIDTransferring) {
                        // Transferring value will get set to '1' when transmission of a new group of packet data starts
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if(characteristic.uuid == ResBitSummaryService.charUUIDTransferSummaryData) {
                        // TransferSummaryData gets set to 1 at the beginning of transfer, and back to 0 once ALL groups of packets are received.
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if(characteristic.uuid == ResBitSummaryService.charUUIDResbitSerialNumber) {
                        peripheral.readValue(for: characteristic)
                    } else if(characteristic.uuid == ResBitSummaryService.charUUIDAckNack) {
                        if(RBBTManager.shared.recievedAllPackets) {
                            // If we've received all packets, write a 1 to AckNack to signal the end of transfer
                            var valueToWrite: UInt8 = 1
                            let data = Data(bytes: &valueToWrite, count: MemoryLayout.size(ofValue: valueToWrite))
                            peripheral.writeValue(data, for: characteristic, type: .withResponse)
                            LogToScreen(text: "Writing 1 to Ack/Nack")
                        } else {
                            // If we haven't received all packets, then write a 2 into Ack/nack, and also write the missing packets into Response.
                            // This will tell the client to resend whatever packets are in the Response characteristic.
                            // This will repeat until Ack/nack is written a 1.
                            var valueToWrite: UInt8 = 2
                            // Prepare response to send here
                            let data = Data(bytes: &valueToWrite, count: MemoryLayout.size(ofValue: valueToWrite))
                            peripheral.writeValue(data, for: characteristic, type: .withResponse)
                            LogToScreen(text: "Writing 2 to Ack/Nack")
                        }
                    } else if(characteristic.uuid == ResBitSummaryService.charUUIDResponse) {
                        var valueToWrite: [UInt8] = [1]
                        // Write our missing packets to response
                        for packetIndex in RBBTManager.shared.missedPackets {
                            valueToWrite.append(UInt8(packetIndex))
                        }
                        let data = Data(bytes: &valueToWrite, count: MemoryLayout.size(ofValue: valueToWrite))
                        peripheral.writeValue(data, for: characteristic, type: .withResponse)
                        LogToScreen(text: "Writing to response")
                    }
                }
            }
        } else {
            LogToScreen(text: "Invalid service found when discovering characteristics")
        }
	}
	
	func peripheral(_ peripheral: CBPeripheral,
					didUpdateValueFor characteristic: CBCharacteristic,
					error: Error?) {
		if let error = error {
            LogToScreen(text: error.localizedDescription)
			return
		}
        
        // This is where the peripheral sends you data!
        // Exercise for the reader: handle the characteristic.value, eg buffer
        // and scan for JSON between STX and ETX markers.
        if let value = characteristic.value?[0] {
            let valueAsInt = Int(value)
            if(characteristic.uuid == ResBitSummaryService.charUUIDResbitSerialNumber) {
                if let data = (characteristic.value) {
                    let bytes = [UInt8](data)
                    var stringMinor = ""
                    var stringMajor = ""
                    var stringSerial = ""
                    
                    for val in 0...1 {
                        let byteValue = bytes[val]
                        stringMinor = stringMinor + String(format: "%02X", byteValue)
                    }
                    
                    for val in 2...3 {
                        let byteValue = bytes[val]
                        stringMajor = stringMajor + String(format: "%02X", byteValue)
                    }
                    
                    for val in 0...bytes.count - 1 {
                        let byteValue = bytes[val]
                        stringSerial = stringSerial + String(format: "%02X", byteValue)
                    }
                    
                    if let iBeaconUUID = UUID(uuidString: "152ad1e0-63af-11ea-bc55-0242ac130003"){
                        var iBeaconMajor = 0
                        var iBeaconMinor = 0
                        
                        if let value = UInt64(stringMajor, radix: 16) {
                            iBeaconMajor = Int(value)
                        }
                        
                        if let value = UInt64(stringMinor, radix: 16) {
                            iBeaconMinor = Int(value)
                        }
                        
                        let discoveredDevice = BLEDevice.init(peripheral: peripheral, theSerialID: stringSerial, theiBeaconUUID: iBeaconUUID, theiBeaconMajor: iBeaconMajor, theiBeaconMinor: iBeaconMinor)
                        
                        if let callback = RBBTManager.shared.BLEDeviceCompletion {
                            callback(.success(discoveredDevice))
                            RBBTManager.shared.BLEDeviceCompletion = nil
                        }
                        
                        RBBTManager.shared.disconnect(forget: true)
                    }
                }
            }
            else if(characteristic.uuid == ResBitSummaryService.charUUIDTransferring) {
                // TODO fix to handle sending more than 20 missed packets
                if(valueAsInt == 0) {
                    LogToScreen(text: "Ending data transfer.")
                    // Check to see if we've collected all packets
                    // Total incoming packets is the first value in each received packet array, so just check the first one we received
                    if(RBBTManager.shared.packetsReceivedInChunk.count == 0) {
                        LogToScreen(text: "No packets found in chunk")
                        return
                    }
                    let totalPackets = RBBTManager.shared.packetsReceivedInChunk[0][0]
                    LogToScreen(text: "Total packets received: " + String(RBBTManager.shared.packetsReceivedInChunk.count))
                    if(RBBTManager.shared.packetsReceivedInChunk.count == totalPackets) {
                        let timePassedInMilliseconds = Int64((NSDate().timeIntervalSince1970 * 1000.0).rounded()) - RBBTManager.shared.startTimeInMilliseconds
                                        
                        LogToScreen(text: "Total time for transfer: \(timePassedInMilliseconds) ")
                        
                        LogToScreen(text: "All Packets received, attempting to write a 1 to Ack/Nack.")
                        RBBTManager.shared.recievedAllPackets = true
                        
                        // If we've received all packets, then we're done with the current group of packet data. Notify the device of the completion by writing to the AckNack characteristic
                        RBBTManager.shared.discoverCharacteristic(peripheral: peripheral, serviceUUID: ResBitSummaryService.uuid, characteristicUUID: ResBitSummaryService.charUUIDAckNack)
                    } else {
                        LogToScreen(text: "Missing some packets, preparing response with missing packets.")
                        
                        // If we don't have all the packets, something went wrong during transmission
                        // Let's find which packet we're missing by checking each packet index
                        for i in 0...totalPackets - 1 {
                            // The second value in each packet array is the index of that packet
                            let packetIndex = RBBTManager.shared.packetsReceivedInChunk[Int(i)][1]
                            if(packetIndex == i) {
                                continue
                            } else {
                                RBBTManager.shared.missedPackets.append(Int(i))
                            }
                        }
                        
//                        let stringArrayData = RBBTManager.shared.missedPackets.map {String($0)}
//                        let printableString = stringArrayData.joined(separator: ", ")
//                        LogToScreen(text: "Requesting resend of these packet indexes:")
//                        LogToScreen(text: "[" + printableString + "]")
                        
                        // Now we'll need to request that the device sends the missing packets a second time.
                        RBBTManager.shared.discoverCharacteristic(peripheral: peripheral, serviceUUID: ResBitSummaryService.uuid, characteristicUUID: ResBitSummaryService.charUUIDResponse)
                    }
                } else if(valueAsInt == 1) {
                    LogToScreen(text: "Beginning data transfer.")
                    RBBTManager.shared.missedPackets.removeAll()
                }
            } else if(characteristic.uuid == ResBitSummaryService.charUUIDData) {
                if let data = characteristic.value {
                    let dataAsByteArray = [UInt8](data)
                    RBBTManager.shared.packetsReceivedInChunk.append(dataAsByteArray)
                }
            } else if(characteristic.uuid == ResBitSummaryService.charUUIDTransferSummaryData) {
                LogToScreen(text: "Value change in transferSummaryData: " + String(valueAsInt))
                let timePassedInMilliseconds = Int64((NSDate().timeIntervalSince1970 * 1000.0).rounded()) - RBBTManager.shared.startTimeInMilliseconds
                                
                LogToScreen(text: "Total time for transfer: \(timePassedInMilliseconds) ")
                if valueAsInt == 0 {
                    // If summary data turns to 0, then all packets have been received
                    if let callback = RBBTManager.shared.summaryDataCompletion {
                        callback(.success(RBBTManager.shared.formatPacketsIntoSummaryData(packetChunks: RBBTManager.shared.totalPacketChunksReceived)))
                        RBBTManager.shared.disconnect(forget: true)
                        RBBTManager.shared.summaryDataCompletion = nil
                    }
                }
            }
        }
	}
	
	/**
	Called when .withResponse is used. when writing a value to a peripheral
	*/
	func peripheral(_ peripheral: CBPeripheral,
					didWriteValueFor characteristic: CBCharacteristic,
					error: Error?) {
		if let error = error {
			LogToScreen(text: "Error writing to characteristic: \(error)")
            if let callback = RBBTManager.shared.summaryDataCompletion {
                callback(.failure(error))
                RBBTManager.shared.disconnect(forget: true)
                RBBTManager.shared.summaryDataCompletion = nil
            }
			return
        } else {
            if(characteristic.uuid == ResBitSummaryService.charUUIDResponse) {
                LogToScreen(text: "Successful write to response, preparing write to Ack/Nack")
                // If we wrote to Response, that means we missed some packets and need the device to resend them
                // Discovering AckNack will check to see if we've received all packets, and if not, it'll write a 2 to AckNack to initiate the re-transfer
                RBBTManager.shared.discoverCharacteristic(peripheral: peripheral, serviceUUID: ResBitSummaryService.uuid, characteristicUUID: ResBitSummaryService.charUUIDAckNack)
            } else if(characteristic.uuid == ResBitSummaryService.charUUIDAckNack) {
                LogToScreen(text: "Successful write to Ack/Nack")
                RBBTManager.shared.totalPacketChunksReceived.append(RBBTManager.shared.packetsReceivedInChunk)
//                for packet in RBBTManager.shared.packetsReceivedInChunk {
//                    RBBTManager.shared.totalPacketsReceived.append(packet)
//                }
                
                RBBTManager.shared.packetsReceivedInChunk.removeAll()
            } else if(characteristic.uuid == ResBitSummaryService.charUUIDTransferSummaryData) {
                LogToScreen(text: "Successful write to Transfer Summary Data")
                RBBTManager.shared.startTimeInMilliseconds = Int64((NSDate().timeIntervalSince1970 * 1000.0).rounded())
            }
        }
	}
	
    /**
        Only used when setting notification value for a characteristic of a peripheral.
     */
	func peripheral(_ peripheral: CBPeripheral,
					didUpdateNotificationStateFor characteristic: CBCharacteristic,
					error: Error?) {
		// TODO cancel a setNotifyValue timeout if no error.
        if let theError = error {
            LogToScreen(text: "Couldn't set notify value for characteristic: " + characteristic.description)
            LogToScreen(text: theError.localizedDescription)
        } else {
            LogToScreen(text: "Set notify value for characteristic: " + characteristic.description)
            if(characteristic.uuid == ResBitSummaryService.charUUIDTransferring) {
                RBBTManager.shared.discoverCharacteristic(peripheral: peripheral, serviceUUID: ResBitSummaryService.uuid, characteristicUUID: ResBitSummaryService.charUUIDTransferSummaryData)
            } else if(characteristic.uuid == ResBitSummaryService.charUUIDTransferSummaryData) {
                // Characterstics are discovered in the order they are on the chip. We don't want to start transferring data
                // until we've set the notify property on Data, Transferring, and TransferSummaryData.
                // So, since Transferring is ordered before TransferSummaryData, we wait to discover TransferSummaryData until we've set notify on Transferring.
                // Once notify has been set on TransferSummaryData, we can write to it and start data transfer.
                var value: UInt8 = 1
                let data = Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
                LogToScreen(text: "Writing 1 to Transfer Summary Data")
            }
        }
	}
}


class MyCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
	static let shared = MyCentralManagerDelegate()
    
    // Whenever we successfully connect to a peripheral we'll hit here.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        LogToScreen(text: "Connected successfully")
        RBBTManager.shared.discoverServices(peripheral: peripheral)
        LogToScreen(text: "Discovering services")
        
        NotificationCenter.default.post(name: Notification.Name("UpdatedPeripheralConnection"), object: nil)
    }
    
    // If we fail to connect to a peripheral, we'll hit here.
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        LogToScreen(text: "Failed to connect")
        if let theError = error {
            RBBTManager.shared.state = .disconnected
            if let completionHandler = RBBTManager.shared.summaryDataCompletion {
                completionHandler(.failure(theError))
                RBBTManager.shared.summaryDataCompletion = nil
            } else if let completionHandler = RBBTManager.shared.BLEDeviceCompletion {
                completionHandler(.failure(theError))
                RBBTManager.shared.BLEDeviceCompletion = nil
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
    }
	
	/**
	Apple says: This is the first method invoked when your app is relaunched
	into the background to complete some Bluetooth-related task.
	*/
	func centralManager(_ central: CBCentralManager,
						willRestoreState dict: [String : Any]) {
//		let peripherals: [CBPeripheral] = dict[
//			CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
//		if peripherals.count > 1 {
//			LogToScreen(text: "Warning: willRestoreState called with >1 connection")
//		}
//		// We have a peripheral supplied, but we can't touch it until
//		// `central.state == .poweredOn`, so we store it in the state
//		// machine enum for later use.
//		if let peripheral = peripherals.first {
//			switch peripheral.state {
//				case .connecting: // I've only seen this happen when
//					// re-launching attached to Xcode.
//					RBBTManager.shared.state =
//						.restoringConnectingPeripheral(peripheral)
//
//				case .connected: // Store for connection / requesting
//					// notifications when BT starts.
//					RBBTManager.shared.state =
//						.restoringConnectedPeripheral(peripheral)
//				default: break
//			}
//		}
	}
	
    // This function gets hit whenever we discover a peripheral that contains services matching our desired service UUIDs.
	func centralManager(_ central: CBCentralManager,
						didDiscover peripheral: CBPeripheral,
						advertisementData: [String : Any],
						rssi RSSI: NSNumber) {
        LogToScreen(text: "Found a peripheral")
        
        RBBTManager.shared.validPeripherals.append(peripheral)
    }
	
	func centralManager(_ central: CBCentralManager,
						didDisconnectPeripheral peripheral: CBPeripheral,
						error: Error?) {
        LogToScreen(text: "Disconnected")
        NotificationCenter.default.post(name: Notification.Name("UpdatedPeripheralConnection"), object: nil)
        RBBTManager.shared.state = .disconnected
        
        if let theError = error {
            LogToScreen(text: theError.localizedDescription)
            RBBTManager.shared.disconnect(forget: true)
        }
        
		// Did our currently-connected peripheral just disconnect?
		if RBBTManager.shared.state.peripheral?.identifier ==
			peripheral.identifier {
			// IME the error codes encountered are:
			// 0 = rebooting the peripheral.
			// 6 = out of range.
			if let error = error,
				(error as NSError).domain == CBErrorDomain,
				let code = CBError.Code(rawValue: (error as NSError).code),
				RBBTManager.outOfRangeHeuristics.contains(code) {
				// Try reconnect without setting a timeout in the state machine.
				// With CB, it's like saying 'please reconnect me at any point
				// in the future if this peripheral comes back into range'.
				RBBTManager.shared.central.connect(peripheral, options: nil)
				RBBTManager.shared.state = .outOfRange(peripheral)
			} else {
				// Likely a deliberate unpairing.
				RBBTManager.shared.state = .disconnected
			}
		}
	}
}

/**
Timer wrapper that automatically invalidates when released.
Read more: http://www.splinter.com.au/2019/03/28/timers-without-circular-references-with-pendulum
*/
class Countdown {
	var timer: Timer?

	init(seconds: TimeInterval, closure: @escaping () -> ()) {
        //Using Timer requires the scheduled timer to be executed an a queue with a runloop.
        //TODO: Consider using `DispatchSource.makeTimerSource()` or `DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) { ... }`
        //      See: https://stackoverflow.com/questions/55131532/difference-between-dispatchsourcetimer-timer-and-asyncafter
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in closure() }
        }
	}
    
	deinit {
		timer?.invalidate()
	}
}

extension NSError {
    convenience init(key: String, description: String, failureReason: String) {
        let userInfo: [String : Any] =
            [
                NSLocalizedDescriptionKey :  NSLocalizedString(key, value: description, comment: "") ,
                NSLocalizedFailureReasonErrorKey : NSLocalizedString(key, value: failureReason, comment: "")
        ]
        self.init(domain: "com.kv.resbit", code: 401, userInfo: userInfo)
    }
}

extension NSString {
    public func log() {
        NotificationCenter.default.post(name: Notification.Name("Log"), object: nil, userInfo: ["logText" : self])
    }
}

public func LogToScreen(text: String) {
    print(text)
    NSString(string: text).log()
}
