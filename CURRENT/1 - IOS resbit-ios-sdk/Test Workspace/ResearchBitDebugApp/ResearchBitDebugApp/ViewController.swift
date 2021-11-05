//
//  ViewController.swift
//  ResearchBitDebugApp
//
//  Created by Stan Rosenbaum on 11/18/19.
//  Copyright © 2019 Stan Rosenbaum. All rights reserved.
//

import UIKit
import ResearchBit
import CoreBluetooth

class ViewController: UIViewController {
    
    var BLEDevices: [BLEDevice] = [BLEDevice]()
    var researchBit: ResearchBit = ResearchBit()
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textLog: UITextView!
    
    override func viewDidLoad() {
		super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatedPeripheralConnection), name: Notification.Name("UpdatedPeripheralConnection"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateLog), name: NSNotification.Name("Log"), object: nil)
        
        textLog.isScrollEnabled = true
	}
    
    @objc func updateLog(_ notification: Notification) {
        if let text = notification.userInfo?["logText"] {
            let existingText = textLog.text
            textLog.text = existingText! + "\n" + (text as! String)
        }
        
    }
    @IBAction func pressedClearLog(_ sender: Any) {
        textLog.text = ""
    }
    
    @IBAction func pressedScan(_ sender: Any) {
        researchBit.scanForBLEDevices(scanTime: 5) { (result) in
            switch result {
                case .success(let peripherals):
                    if peripherals.count == 0 {
                        LogToScreen(text: "No peripherals found")
                        return
                    }
                    
                    for peripheral in peripherals {
                        self.researchBit.getBLEDevice(peripheral: peripheral) { (result) in
                            switch result {
                            case .success(let BLEDevice):
                                self.BLEDevices.append(BLEDevice)
                                LogToScreen(text: "Received BLEDevice object")
                            case .failure(let error):
                                LogToScreen(text: error.localizedDescription)
                            }
                            
                            if(peripheral == peripherals[peripherals.count - 1]) {
                                if(self.BLEDevices.count > 0) {
                                    UserDefaults.standard.set(self.BLEDevices[peripherals.count - 1].peripheral.identifier.uuidString,
                                                              forKey: "peripheralIDKey")
                                    UserDefaults.standard.synchronize()
                                }
                                self.tableView.reloadData()
                            }
                        }
                    }
                case .failure(let error):
                    LogToScreen(text: error.localizedDescription)
            }
        }
    }
    
    @IBAction func pressedGetDeviceSummaryData(_ sender: Any) {
        if(BLEDevices.count > 0) {
            getDeviceSummaryDataForIndex(index: 0)
        }
    }
    
    @IBAction func pressedConnectByUUID(_ sender: Any) {
        if let peripheralIdStr = UserDefaults.standard.object(forKey: "peripheralIDKey") as? String,
            let peripheralId = UUID(uuidString: peripheralIdStr) {
            researchBit.getBLEDeviceSummaryData(peripheralUUID: peripheralId) { (result) in
                switch result {
                    case .success(let summaryData):
                        // do something with data
                        LogToScreen(text: "Received summary data")
                        var count = 0
                        for summaryEvent in summaryData {
                            LogToScreen(text: "Summary Event #" + String(count))
                            LogToScreen(text: "     ID: " + String(summaryEvent.eventType))
                            LogToScreen(text: "     Data Size: " + String(summaryEvent.eventDataSize))
                            
                            let dateFormatter : DateFormatter = {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yy/MM/dd HH:mm:ss"
                                return formatter
                            }()
                            
                            LogToScreen(text: "     Wakeup Time: " + dateFormatter.string(from: summaryEvent.eventWakeupTime))
                            if(summaryEvent.eventType == 0) {
                                if summaryEvent.eventFields.count > 0 {
                                    LogToScreen(text: "     Awake Time: " + String(summaryEvent.eventFields[0].value))
                                }
                            } else if(summaryEvent.eventType == 1) {
                                if summaryEvent.eventFields.count > 0 {
                                    LogToScreen(text: "     Trigger Pulls: " + String(summaryEvent.eventFields[0].value))
                                }
                            }
                            
                            count += 1
                        }
                        break
                    case .failure(let error):
                        LogToScreen(text: error.localizedDescription)
                }
                
            }
        }
    }
    
    func getDeviceSummaryDataForIndex(index: Int) {
        let device = BLEDevices[index]
        if(device.dataIsAvailable) {
            researchBit.getBLEDeviceSummaryData(device: device) { (result) in
                switch result {
                    case .success(let summaryData):
                        LogToScreen(text: "Received summary data")
                        for data in summaryData {
                           // do something with the data
                        }

                        self.tableView.reloadData()
                       
                        if(index < self.BLEDevices.count - 1) {
                            let nextIndex = index + 1
                            self.getDeviceSummaryDataForIndex(index: nextIndex)
                        }
                        break
                    case .failure(let error):
                        LogToScreen(text: error.localizedDescription)
                }
            }
        } else if(index < self.BLEDevices.count - 1) {
                let nextIndex = index + 1
                self.getDeviceSummaryDataForIndex(index: nextIndex)
        }
    }
    
    @objc func updatedPeripheralConnection() {
        tableView.reloadData()
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 66
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return BLEDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let deviceCell: BLEDeviceCell = tableView.dequeueReusableCell(withIdentifier: "BLEDeviceCell", for: indexPath) as! BLEDeviceCell
        
        let device: BLEDevice = BLEDevices[indexPath.row]
        
        deviceCell.labelDeviceName.text = (BLEDevices[indexPath.row]).deviceName
        
        if(device.peripheral.state == .connected) {
            deviceCell.imageBluetoothConnectionnStatus.backgroundColor = UIColor.green
        } else {
            deviceCell.imageBluetoothConnectionnStatus.backgroundColor = UIColor.red
        }
        
        return deviceCell
    }
}

class BLEDeviceCell: UITableViewCell  {
    @IBOutlet weak var labelDeviceName: UILabel!
    @IBOutlet weak var imageBluetoothConnectionnStatus: UIImageView!
}
