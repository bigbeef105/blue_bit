import Foundation
import CoreBluetooth
import Cocoa
import PlaygroundSupport


var str = "Hello, playground"

var bt = RBBTManager()

bt.scan()


/**
The helper for dealing with Bluetooth and talking to sensor.
Also the Adaptee in the Adapter Pattern

- SeeAlso - [This class is based on the example code found here.](http://www.splinter.com.au/2019/06/06/bluetooth-sample-code/)

*/
class RBBTManager {
	
	static let shared = RBBTManager()
	
	fileprivate static let restoreIdKey = "RBBTManager"
	fileprivate static let peripheralIdDefaultsKey = "RBBTManagerPeripheralId"
	fileprivate static let myDesiredServiceId = CBUUID(string: "12345678-0000-0000-0000-000000000000")
	fileprivate static let myDesiredCharacteristicId = CBUUID(string: "12345678-0000-0000-0000-000000000000")
	fileprivate static let desiredManufacturerData = Data(base64Encoded: "foobar==")!
	fileprivate static let outOfRangeHeuristics: Set<CBError.Code> = [.unknown,
																	  .connectionTimeout,
																	  .peripheralDisconnected,
																	  .connectionFailed]
	
	// MARK: - For PLaygrounds
	let managerDelegate: PlaygroundBluetoothCentralManagerDelegate = MyCentralManagerDelegate.shared
	
	let manager = PlaygroundBluetoothCentralManager(services: nil)
	manager.delegate = managerDelegate
	
	
	private var centralManager: CBCentralManager!
	private var peripheral: CBPeripheral!
	
	let central = CBCentralManager(delegate: MyCentralManagerDelegate.shared,
								   queue: nil,
								   options: [
									CBCentralManagerOptionRestoreIdentifierKey: restoreIdKey,])
	
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
	
	/**
	Begin scanning here!
	*/
	func scan() {
		guard central.state == .poweredOn else {
			print("Cannot scan, BT is not powered on")
			return
		}
		
		// Scan!
		central.scanForPeripherals(withServices: [RBBTManager.myDesiredServiceId], options: nil)
		state = .scanning(Countdown(seconds: 10, closure: {
			self.central.stopScan()
			self.state = .disconnected
			print("Scan timed out")
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
		if forget {
			UserDefaults.standard.removeObject(forKey: RBBTManager.peripheralIdDefaultsKey)
			UserDefaults.standard.synchronize()
		}
		state = .disconnected
	}
	
	func connect(peripheral: CBPeripheral) {
		// Connect!
		// Note: We're retaining the peripheral in the state enum because Apple
		// says: "Pending attempts are cancelled automatically upon
		// deallocation of peripheral"
		central.connect(peripheral, options: nil)
		state = .connecting(peripheral, Countdown(seconds: 10, closure: {
			self.central.cancelPeripheralConnection(peripheral)
			self.state = .disconnected
			print("Connect timed out")
		}))
	}
	
	func discoverServices(peripheral: CBPeripheral) {
		peripheral.delegate = MyPeripheralDelegate.shared
		peripheral.discoverServices([RBBTManager.myDesiredServiceId])
		state = .discoveringServices(peripheral, Countdown(seconds: 10, closure: {
			self.disconnect()
			print("Could not discover services")
		}))
	}
	
	func discoverCharacteristics(peripheral: CBPeripheral) {
		guard let myDesiredService = peripheral.myDesiredService else {
			self.disconnect()
			return
		}
		peripheral.delegate = MyPeripheralDelegate.shared
		peripheral.discoverCharacteristics([RBBTManager.myDesiredCharacteristicId],
										   for: myDesiredService)
		state = .discoveringCharacteristics(peripheral, Countdown(seconds: 10,
																  closure: {
																	self.disconnect()
																	print("Could not discover characteristics")
		}))
	}
	
	func setConnected(peripheral: CBPeripheral) {
		guard let myDesiredCharacteristic = peripheral.myDesiredCharacteristic
			else {
				print("Missing characteristic")
				disconnect()
				return
		}
		
		// Remember the ID for startup reconnecting.
		UserDefaults.standard.set(peripheral.identifier.uuidString,
								  forKey: RBBTManager.peripheralIdDefaultsKey)
		UserDefaults.standard.synchronize()
		
		// Ask for notifications when the peripheral sends us data.
		// TODO another state waiting for this?
		peripheral.delegate = MyPeripheralDelegate.shared
		peripheral.setNotifyValue(true, for: myDesiredCharacteristic)
		
		state = .connected(peripheral)
	}
	
	/**
	Write data to the peripheral.
	*/
	func write(data: Data) throws {
		guard case .connected(let peripheral) = state else {
			throw Errors.notConnected
		}
		guard let characteristic = peripheral.myDesiredCharacteristic else {
			throw Errors.missingCharacteristic
		}
		peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
		// .withResponse is more expensive but gives you confirmation.
		// It's an exercise for the reader to ask for a response and handle
		// timeouts waiting for said response.
		// I found it simpler to deal with that at a higher level in a
		// messaging framework.
	}
	
	enum Errors: Error {
		case notConnected
		case missingCharacteristic
	}
	
}

extension CBPeripheral {
	
	/**
	Helper to find the service we're interested in.
	*/
	var myDesiredService: CBService? {
		guard let services = services else { return nil }
		return services.first { $0.uuid == RBBTManager.myDesiredServiceId }
	}
	
	/**
	Helper to find the characteristic we're interested in.
	*/
	var myDesiredCharacteristic: CBCharacteristic? {
		guard let characteristics = myDesiredService?.characteristics else {
			return nil
		}
		return characteristics.first { $0.uuid == RBBTManager.myDesiredCharacteristicId }
	}
}

class MyPeripheralDelegate: NSObject, CBPeripheralDelegate {
	
	static let shared = MyPeripheralDelegate()
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		// Ignore services discovered late.
		guard case .discoveringServices = RBBTManager.shared.state else {
			return
		}
		
		if let error = error {
			print("Failed to discover services: \(error)")
			RBBTManager.shared.disconnect()
			return
		}
		guard peripheral.myDesiredService != nil else {
			print("Desired service missing")
			RBBTManager.shared.disconnect()
			return
		}
		
		// Progress to the next step.
		RBBTManager.shared.discoverCharacteristics(peripheral: peripheral)
	}
	
	func peripheral(_ peripheral: CBPeripheral,
					didDiscoverCharacteristicsFor service: CBService,
					error: Error?) {
		// Ignore characteristics arriving late.
		guard case .discoveringCharacteristics =
			RBBTManager.shared.state else { return }
		
		if let error = error {
			print("Failed to discover characteristics: \(error)")
			RBBTManager.shared.disconnect()
			return
		}
		guard peripheral.myDesiredCharacteristic != nil else {
			print("Desired characteristic missing")
			RBBTManager.shared.disconnect()
			return
		}
		
		// Ready to go!
		RBBTManager.shared.setConnected(peripheral: peripheral)
	}
	
	func peripheral(_ peripheral: CBPeripheral,
					didUpdateValueFor characteristic: CBCharacteristic,
					error: Error?) {
		if let error = error {
			print(error)
			return
		}
		
		// This is where the peripheral sends you data!
		// Exercise for the reader: handle the characteristic.value, eg buffer
		// and scan for JSON between STX and ETX markers.
	}
	
	/**
	Called when .withResponse is used.
	*/
	func peripheral(_ peripheral: CBPeripheral,
					didWriteValueFor characteristic: CBCharacteristic,
					error: Error?) {
		if let error = error {
			print("Error writing to characteristic: \(error)")
			return
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral,
					didUpdateNotificationStateFor characteristic: CBCharacteristic,
					error: Error?) {
		// TODO cancel a setNotifyValue timeout if no error.
	}
}


class MyCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
	
	static let shared = MyCentralManagerDelegate()
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		if central.state == .poweredOn {
			// Are we transitioning from BT off to BT ready?
			if case .poweredOff = RBBTManager.shared.state {
				// Firstly, try to reconnect:
				if let peripheralIdStr = UserDefaults.standard
					.object(forKey: RBBTManager.peripheralIdDefaultsKey) as? String,
					let peripheralId = UUID(uuidString: peripheralIdStr),
					let previouslyConnected = central
						.retrievePeripherals(withIdentifiers: [peripheralId])
						.first {
					RBBTManager.shared.connect(
						peripheral: previouslyConnected)
					
					// Next, try for ones that are connected to the system:
				} else if let systemConnected = central
					.retrieveConnectedPeripherals(withServices:
						[RBBTManager.myDesiredServiceId]).first {
					RBBTManager.shared.connect(peripheral: systemConnected)
					
				} else {
					// Not an error, simply the case that they've never paired
					// before, or they did a manual unpair:
					RBBTManager.shared.state = .disconnected
				}
			}
			
			// Did CoreBluetooth wake us up with a peripheral that was connecting?
			if case .restoringConnectingPeripheral(let peripheral) =
				RBBTManager.shared.state {
				RBBTManager.shared.connect(peripheral: peripheral)
			}
			
			// CoreBluetooth woke us with a 'connected' peripheral, but we had
			// to wait until 'poweredOn' state:
			if case .restoringConnectedPeripheral(let peripheral) =
				RBBTManager.shared.state {
				if peripheral.myDesiredCharacteristic == nil {
					RBBTManager.shared.discoverServices(
						peripheral: peripheral)
				} else {
					RBBTManager.shared.setConnected(peripheral: peripheral)
				}
			}
		} else { // Turned off.
			RBBTManager.shared.state = .poweredOff
		}
	}
	
	/**
	Apple says: This is the first method invoked when your app is relaunched
	into the background to complete some Bluetooth-related task.
	*/
	func centralManager(_ central: CBCentralManager,
						willRestoreState dict: [String : Any]) {
		let peripherals: [CBPeripheral] = dict[
			CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
		if peripherals.count > 1 {
			print("Warning: willRestoreState called with >1 connection")
		}
		// We have a peripheral supplied, but we can't touch it until
		// `central.state == .poweredOn`, so we store it in the state
		// machine enum for later use.
		if let peripheral = peripherals.first {
			switch peripheral.state {
				case .connecting: // I've only seen this happen when
					// re-launching attached to Xcode.
					RBBTManager.shared.state =
						.restoringConnectingPeripheral(peripheral)
				
				case .connected: // Store for connection / requesting
					// notifications when BT starts.
					RBBTManager.shared.state =
						.restoringConnectedPeripheral(peripheral)
				default: break
			}
		}
	}
	
	func centralManager(_ central: CBCentralManager,
						didDiscover peripheral: CBPeripheral,
						advertisementData: [String : Any],
						rssi RSSI: NSNumber) {
		guard case .scanning = RBBTManager.shared.state else { return }
		
		// You might want to skip this manufacturer data check.
		guard let mfgData =
			advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
			mfgData == RBBTManager.desiredManufacturerData else {
				print("Missing/wrong manufacturer data")
				return
		}
		
		central.stopScan()
		RBBTManager.shared.connect(peripheral: peripheral)
	}
	
	func centralManager(_ central: CBCentralManager,
						didConnect peripheral: CBPeripheral) {
		if peripheral.myDesiredCharacteristic == nil {
			RBBTManager.shared.discoverServices(peripheral: peripheral)
		} else {
			RBBTManager.shared.setConnected(peripheral: peripheral)
		}
	}
	
	func centralManager(_ central: CBCentralManager,
						didFailToConnect peripheral: CBPeripheral,
						error: Error?) {
		RBBTManager.shared.state = .disconnected
	}
	
	func centralManager(_ central: CBCentralManager,
						didDisconnectPeripheral peripheral: CBPeripheral,
						error: Error?) {
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
	let timer: Timer
	
	init(seconds: TimeInterval, closure: @escaping () -> ()) {
		timer = Timer.scheduledTimer(withTimeInterval: seconds,
									 repeats: false, block: { _ in
										closure()
		})
	}
	
	deinit {
		timer.invalidate()
	}
}

