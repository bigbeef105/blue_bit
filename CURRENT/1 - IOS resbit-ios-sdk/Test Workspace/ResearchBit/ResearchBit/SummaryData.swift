//
//  SummaryData.swift
//  ResearchBit
//
//  Created by Grant Courts on 11/26/19.
//  Copyright © 2019 Stan Rosenbaum. All rights reserved.
//

import UIKit

open class SummaryData: NSObject, Codable {
    public var eventType: Int
    public var eventUUID: String
    public var eventDataSize: Int
    public var eventWakeupTime: Date
    public var eventFields: [EventField] = [EventField]()
    
    init(type: Int, dataSize: Int, time: Int, data: [UInt8]) {
        eventType = type
        eventUUID = UUID().uuidString
        eventDataSize = dataSize
        
        let timeAsDate = Date(timeIntervalSince1970: TimeInterval(time))
        eventWakeupTime = timeAsDate
        
        var dataIntValue : UInt32 = 0
        let dataAsBytes = NSData(bytes: data, length: 4)
        dataAsBytes.getBytes(&dataIntValue, length: 4)
        dataIntValue = UInt32(littleEndian: dataIntValue)
        
        if(eventType == 0) {
            let eventField = EventField(Name: "Awake Time", Value: Int(dataIntValue))
            eventFields = [eventField]
        } else if(eventType == 1) {
            let eventField = EventField(Name: "Trigger Pulls", Value: Int(dataIntValue))
            eventFields = [eventField]
        }
    }
    
    override public var debugDescription: String {
        return "type: \(eventType) / dataSize: \(eventDataSize) / wakeTime: \(eventWakeupTime) / fields: \(eventFields)"
    }
}

open class EventField: NSObject, Codable {
    public var name: String
    public var value: Int
    
    init(Name: String, Value: Int) {
        name = Name
        value = Value
    }
}
