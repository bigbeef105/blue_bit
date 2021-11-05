package com.kineticvision.resbitblesdk

import android.bluetooth.*
import android.bluetooth.BluetoothDevice.*
import android.bluetooth.BluetoothGatt.GATT_FAILURE
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.bluetooth.le.ScanSettings.*
import android.content.Context
import android.os.Build
import android.os.Handler
import android.util.Log
import androidx.annotation.RequiresApi
import java.util.*

class ResearchBitImpl(private val context: Context) : ResearchBit {

    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
//    private val bluetoothAdapter = bluetoothManager.adapter
//    private val bluetoothLeScanner = bluetoothAdapter.bluetoothLeScanner

    private var messageListener:MessageListener = { message -> Log.d(TAG, message) }

    private var bluetoothGatt: BluetoothGatt? = null

    private var retryCount: Int = 0
    private val retryMax: Int = 2

    var validPeripherals:List<BLEPeripheral> = emptyList()
    var packetsReceivedInChunk:MutableList<ByteArray> = emptyList<ByteArray>().toMutableList()
    var totalPacketsReceived:MutableList<ByteArray> = emptyList<ByteArray>().toMutableList()
    var missedPackets:MutableList<UByte> = emptyList<UByte>().toMutableList()
    var receivedAllPackets:Boolean = false
    var startTimeInMilliseconds:Long = System.currentTimeMillis()

    private var stopScanningHandler: Handler? = null

    override var state:State = State.PoweredOff()

    sealed class State(val device: BLEDevice?, val name:String, val id:Int) {
        class PoweredOff : State(null, "Powered Off", 0)
        //class RestoringConnectingPeripheral(device: BLEDevice) : State(device, "Restoring Connecting Peripheral", 1)
        //class RestoringConnectedPeripheral(device: BLEDevice) : State(device, "Restoring Connected Peripheral", 2)
        class Disconnected : State(null, "Disconnected", 3)
        class Scanning : State(null, "Scanning", 4)
        class Connecting(device: BLEDevice) : State(device, "Connected", 5)
        class DiscoveringServices(device: BLEDevice) : State(device, "Discovering Services", 6)
        class DiscoveringCharacteristics(device: BLEDevice) : State(device, "Discovering Characteristics", 7)
        class Connected(device: BLEDevice) : State(device, "Connected", 8)
        class OutOfRange(device: BLEDevice) : State(device, "Out of Range", 9)

        fun equals(other:State):Boolean {
            return this.id == other.id
        }
    }

    enum class RequestType {
        SET_TIME,
        DEVICE_INFO,
        DEVICE_SUMMARY;
    }


    override fun isBluetoothEnabled(): Boolean {
        return (bluetoothManager.adapter != null && bluetoothManager.adapter.isEnabled)
    }

    override fun setMessageListener(listener: MessageListener) {
        messageListener = listener
    }

    override fun scanForBLEDevices(scanTime: Long, callback: ResBitScanCallback) {
        scan(scanTime, listOf(ResBitSummaryService.BASE), callback)
    }

    override fun getBLEDevice(peripheral: BLEPeripheral, callback: ResBitDeviceCallback) {
        retryCount = 0
        connect(peripheral, RequestType.DEVICE_INFO, callback)
    }

    override fun setBLEDeviceTime(peripheral: BLEPeripheral, callback: ResBitDeviceCallback) {
        retryCount = 0
        connect(peripheral, RequestType.SET_TIME, callback)
    }

    override fun getBLEDeviceSummaryData(device: BLEDevice, callback: ResBitDeviceCallback) {
        retryCount = 0
        connect(device.peripheral, RequestType.DEVICE_SUMMARY, callback)
    }

    private fun clear() {
        packetsReceivedInChunk.clear()
        totalPacketsReceived.clear()
        missedPackets.clear()
        receivedAllPackets = false
    }

    private fun scan(scanTime: Long, serviceIDs:List<ResearchBitUUID>, callback:ResBitScanCallback) {
        if (isBluetoothEnabled()) {
            messageListener("Starting Scan...")
            messageListener("Searching for devices with service IDs: ${serviceIDs.joinToString()}")

            validPeripherals = emptyList()

            val scanCallback = object : ScanCallback() {
                override fun onBatchScanResults(results: MutableList<ScanResult>?) {
                    super.onBatchScanResults(results)
                    stopScanningHandler?.removeCallbacksAndMessages(null)
                    Log.i(TAG, "Scan: Batch Results Received")
                    state = State.Disconnected()
                    handleScanResults(this, callback, results)
                }

                override fun onScanResult(callbackType: Int, result: ScanResult?) {
                    super.onScanResult(callbackType, result)
                    stopScanningHandler?.removeCallbacksAndMessages(null)

                    Log.i(TAG, "Scan: Single Result Received")
                    state = State.Disconnected()
                    if (result != null) {
                        handleScanResults(this, callback, listOf(result))
                    }
                }

                override fun onScanFailed(errorCode: Int) {
                    super.onScanFailed(errorCode)
                    stopScanningHandler?.removeCallbacksAndMessages(null)

                    state = State.Disconnected()
                    Log.i(TAG, "Scan: Failed")
//                    TODO("Map Errors")
                    callback.onFailure(ResearchBitError.CONNECTION_TIMEOUT)
                }
            }

            if (!state.equals(State.Scanning())) {

                val scanSettings = ScanSettings.Builder()
                    .setScanMode(SCAN_MODE_LOW_LATENCY)
                    .setCallbackType(CALLBACK_TYPE_ALL_MATCHES)
                    .setMatchMode(MATCH_MODE_AGGRESSIVE)
                    .setNumOfMatches(MATCH_NUM_ONE_ADVERTISEMENT)
                    .setReportDelay(scanTime)
                    .build()
                Log.i(TAG, "Scan: Actually starting")
                state = State.Scanning()
                bluetoothManager.adapter.bluetoothLeScanner.startScan(createScanFiltersForIDs(serviceIDs), scanSettings, scanCallback)

                stopScanningHandler = Handler(this.context.mainLooper)
                var myRunnable = Runnable {
                    state = State.Disconnected()
                    bluetoothManager.adapter.bluetoothLeScanner.stopScan(scanCallback)
                }

                stopScanningHandler!!.postDelayed(myRunnable, scanTime+5000)
            }
            else {
                state = State.Disconnected()
                bluetoothManager.adapter.bluetoothLeScanner.stopScan(scanCallback)
            }
        }
        else {
            callback.onFailure(ResearchBitError.POWERED_OFF)
        }
    }

    private fun handleScanResults(scanCallback:ScanCallback, resultCallback: ResBitScanCallback, results: List<ScanResult>?) {
        if (results != null && results.count() > 0) {
            val peripheralString = if (results.count() == 1) "peripheral" else "peripherals"
            messageListener("Found ${results.count()} $peripheralString")

            this.validPeripherals = results.map { BLEPeripheral(it) }
            resultCallback.onPeripheralsFound(validPeripherals)
        }
        else {
            messageListener("No peripherals found")
        }

        bluetoothManager.adapter.bluetoothLeScanner.stopScan(scanCallback)
        resultCallback.onScanFinished()
    }

    private fun disconnect(forget: Boolean = false) {
        val device = state.device ?: return
        device.bondState
        bluetoothGatt?.disconnect()

        messageListener("Disconnected")
        state = State.Disconnected()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun connect(peripheral: BLEPeripheral, requestType: RequestType, callback:ResBitDeviceCallback) {
        messageListener("Attempting to connect...")

        clear()

        if (!peripheral.name.isNullOrBlank()) {
            messageListener(peripheral.name)
        }

        state = State.Connecting(BLEDevice(peripheral))
        val device = bluetoothManager.adapter.getRemoteDevice(peripheral.address)
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.FROYO) {
            messageListener("Creating BOND")
            device.createBond()
        }

        if (bluetoothGatt != null) {
            disconnect()
        }

        bluetoothGatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                super.onServicesDiscovered(gatt, status)

                messageListener("Discovered services")

                if (requestType == RequestType.SET_TIME) {
                    val deviceInfoService = gatt?.services?.firstOrNull { it.uuid == ResBitDeviceInfoService.BASE.uuid }
                    if (deviceInfoService != null) {
                        handleCharacteristics(deviceInfoService.characteristics.filter { it.uuid == ResBitDeviceInfoService.CHAR_UUID_TIME.uuid })
                    }
                } else {
                    val summaryService =
                            gatt?.services?.firstOrNull { it.uuid == ResBitSummaryService.BASE.uuid }
                    if (summaryService != null) {
                        state = State.DiscoveringCharacteristics(BLEDevice(peripheral))

                        if (requestType == RequestType.DEVICE_INFO) {
                            handleCharacteristics(summaryService.characteristics.filter { it.uuid == ResBitSummaryService.CHAR_UUID_RESBIT_SERIAL_NUMBER.uuid })
                        } else if (requestType == RequestType.DEVICE_SUMMARY) {
                            val characteristicUUIDsToDiscover = listOf(
                                    ResBitSummaryService.CHAR_UUID_DATA.uuid
                            )
                            handleCharacteristics(summaryService.characteristics.filter {
                                characteristicUUIDsToDiscover.contains(
                                        it.uuid
                                )
                            })
                        }
                    }
                }
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt?,
                characteristic: BluetoothGattCharacteristic?,
                status: Int
            ) {
                super.onCharacteristicRead(gatt, characteristic, status)

                didReadValueForCharacteristic(characteristic!!, callback)
            }

            override fun onCharacteristicChanged(
                gatt: BluetoothGatt?,
                characteristic: BluetoothGattCharacteristic?
            ) {
                super.onCharacteristicChanged(gatt, characteristic)

                didReadValueForCharacteristic(characteristic!!, callback)
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt?,
                characteristic: BluetoothGattCharacteristic?,
                status: Int
            ) {
                super.onCharacteristicWrite(gatt, characteristic, status)
                didWriteCharacteristic(characteristic!!, callback)
            }

            override fun onDescriptorWrite(
                gatt: BluetoothGatt?,
                descriptor: BluetoothGattDescriptor?,
                status: Int
            ) {
                super.onDescriptorWrite(gatt, descriptor, status)
                didUpdateNotificationState(descriptor!!.characteristic)
            }

            override fun onConnectionStateChange(
                gatt: BluetoothGatt?,
                status: Int,
                newState: Int
            ) {
                super.onConnectionStateChange(gatt, status, newState)
                messageListener("Got change")
                if (status == GATT_SUCCESS) {
                    messageListener("gatt success")
                    if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        messageListener("Disconnected")
                        gatt?.close()
                        Log.d(TAG, "Gatt closed after disconnect")
                        state = State.Disconnected()
                        if (gatt != null) {
                            val device = gatt!!.device
                            callback.onConnectionClosed(BLEDevice(peripheral))
                            bluetoothGatt = null
                            messageListener("Disconnected")
                        } else {
                            callback.onFailure(ResearchBitError.DEVICE_UNEXPECTEDLY_DISCONNECTED)
                            messageListener("Unexpectedly Disconnected")
                        }
                    }
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        val bleDevice = BLEDevice(peripheral)
                        state = State.Connected(bleDevice)
                        messageListener("Connected successfully")
                        bluetoothGatt = gatt
                        gatt?.discoverServices()
                        messageListener("Discovering services...")
                        state = State.DiscoveringServices(bleDevice)
                    }
                }
                if (status == GATT_FAILURE) {
                    messageListener("Failed to connect")
                    disconnect()
                    callback.onFailure(ResearchBitError.CONNECTION_TIMEOUT)
                    state = State.PoweredOff()
                    return
                }

                if(status == 133) {
                    Log.d(TAG, "Error 133")
                    disconnect()
                    if (retryCount < retryMax) {
                        retryCount++
                        connect(peripheral, requestType, callback)
                    }
                    else {
                        callback.onFailure(ResearchBitError.CONNECTION_TIMEOUT)
                    }
                }

                messageListener(status.toString())
            }
        })
    }

    private fun handleCharacteristics(characteristics:List<BluetoothGattCharacteristic>) {
        if (characteristics.count() == 0) {
            Log.d(TAG, "No Characteristics to handle. disconnecting.")
            disconnect(true)
            clear()
            return
        }
        for (characteristic in characteristics) {
            when (characteristic.uuid) {
                ResBitSummaryService.CHAR_UUID_DATA.uuid,
                ResBitSummaryService.CHAR_UUID_TRANSFERRING.uuid,
                ResBitSummaryService.CHAR_UUID_TRANSFER_SUMMARY_DATA.uuid-> {
                    bluetoothGatt?.setCharacteristicNotification(characteristic, true)

                    val descriptor = characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    bluetoothGatt?.writeDescriptor(descriptor)
                }
                ResBitSummaryService.CHAR_UUID_RESBIT_SERIAL_NUMBER.uuid -> {
                    bluetoothGatt?.readCharacteristic(characteristic)
                }
                ResBitSummaryService.CHAR_UUID_ACK_NACK.uuid -> {
                    if (receivedAllPackets) {
                        // If we've received all packets, write a 1 to AckNack to signal the end of transfer
                        characteristic.value = ByteArray(1) { pos -> 1.toByte()}
                        bluetoothGatt?.writeCharacteristic(characteristic)
                        messageListener("Writing 1 to Ack/Nack")
                    }
                    else {
                        // If we haven't received all packets, then write a 2 into Ack/nack, and also write the missing packets into Response.
                        // This will tell the client to resend whatever packets are in the Response characteristic.
                        // This will repeat until Ack/nack is written a 1.
                        characteristic.value = ByteArray(1) { pos -> 2.toByte()}
                        bluetoothGatt?.writeCharacteristic(characteristic)
                        messageListener("Writing 2 to Ack/Nack")
                    }
                }
                ResBitSummaryService.CHAR_UUID_RESPONSE.uuid -> {
                    var valueToWrite = listOf<UByte>(1u).toMutableList()
                    for (packetIndex in missedPackets) {
                        valueToWrite.add(packetIndex.toUByte())
                    }
                    characteristic.value = ByteArray(valueToWrite.size) { pos -> valueToWrite[pos].toByte() }
                    bluetoothGatt?.writeCharacteristic(characteristic)
                    messageListener("Writing to response")
                }
                ResBitDeviceInfoService.CHAR_UUID_TIME.uuid -> {
                    val valueToWrite = longToUInt32ByteArray(System.currentTimeMillis() / 1000L)
                    characteristic.value = valueToWrite
                    bluetoothGatt?.writeCharacteristic(characteristic)
                }
            }
        }
    }


    private fun didReadValueForCharacteristic(characteristic: BluetoothGattCharacteristic, callback: ResBitDeviceCallback) {
        when (characteristic.uuid) {
            ResBitSummaryService.CHAR_UUID_RESBIT_SERIAL_NUMBER.uuid -> decodeDeviceDetails(characteristic, callback)
            ResBitSummaryService.CHAR_UUID_TRANSFERRING.uuid -> decodeTransferring(characteristic, callback)
            ResBitSummaryService.CHAR_UUID_DATA.uuid -> decodeData(characteristic, callback)
            ResBitSummaryService.CHAR_UUID_TRANSFER_SUMMARY_DATA.uuid -> decodeTransferSummaryData(characteristic, callback)
        }
    }

    private fun decodeDeviceDetails(characteristic: BluetoothGattCharacteristic, callback: ResBitDeviceCallback) {
        val data = characteristic.value

        var stringMinor = ""
        var stringMajor = ""
        var stringSerial = ""

        if (data.count() < 4) { return }

        for (position in 0..1) {
            val byteValue = data[position]
            stringMinor += String.format("%02X", byteValue)
        }

        for (position in 2..3) {
            val byteValue = data[position]
            stringMajor += String.format("%02X", byteValue)
        }

        for (position in 0 until data.count()) {
            val byteValue = data[position]
            stringSerial += String.format("%02X", byteValue)
        }

        val iBeaconUUID = UUID.fromString("152ad1e0-63af-11ea-bc55-0242ac130003")
        var iBeaconMajor = 0
        var iBeaconMinor = 0

        val major = stringMajor.toUInt(16)
        iBeaconMajor = major.toInt()

        val minor = stringMinor.toUInt(16)
        iBeaconMinor = minor.toInt()

        var device = state.device
        device!!.serialID = stringSerial
        device!!.iBeaconUUID = iBeaconUUID
        device!!.iBeaconMajor = iBeaconMajor
        device!!.iBeaconMinor = iBeaconMinor

        state = State.DiscoveringCharacteristics(device!!)

        callback.onConnectionEstablished(device)
        disconnect(false)
    }

    @ExperimentalUnsignedTypes
    private fun decodeTransferring(characteristic: BluetoothGattCharacteristic, callback: ResBitDeviceCallback) {
        val value = characteristic.value.toUByteArray()
        val valueAsLong = uByteArrayToLong(value)

        if (valueAsLong == 0.toLong()) {
            messageListener("Ending data transfer.")
            // Check to see if we've collected all packets
            // Total incoming packets is the first value in each received packet array, so just check the first one we received
            if (packetsReceivedInChunk.count() == 0) {
                messageListener("No packets found in chunk")
                return
            }

            val totalPackets = packetsReceivedInChunk[0][0]
            messageListener("Total packets received: ${packetsReceivedInChunk.count()}")

            if (packetsReceivedInChunk.count().toUInt() == totalPackets.toUInt()) {
                val timePassedInMillis = System.currentTimeMillis() - startTimeInMilliseconds
                messageListener("Total time for transfer: ${timePassedInMillis} milliseconds")
                messageListener("All packets received, attempting to write a 1 to Ack/Nack.")
                receivedAllPackets = true

                // If we've received all packets, then we're done. Notify the device of the completion by writing to the AckNack characteristic
                handleCharacteristic(ResBitSummaryService.BASE.uuid, ResBitSummaryService.CHAR_UUID_ACK_NACK.uuid)
            }
            else {
                messageListener("Missing some packets, preparing response with missing packets.")
                // If we don't have all the packets, something went wrong during transmission
                // Let's find which packet we're missing by checking each packet index
                for (i in 0 until totalPackets.toInt()) {
                    // The second value in each packet array is the index of that packet
                    val packetIndex = packetsReceivedInChunk[i][1]
                    if (packetIndex == 1u.toByte()) {
                        continue
                    }
                    else {
                        missedPackets.add(i.toUByte())
                    }
                }
                // Now we'll need to request that the device sends the missing packets a second time.
                handleCharacteristic(ResBitSummaryService.BASE.uuid, ResBitSummaryService.CHAR_UUID_RESPONSE.uuid)
            }
        }
        else if (valueAsLong == 1.toLong()) {
            messageListener("Beginning data transfer.")
            missedPackets.clear()
        }
    }

    private fun decodeData(characteristic: BluetoothGattCharacteristic, callback: ResBitDeviceCallback) {
        val data = characteristic.value.toUByteArray()
        packetsReceivedInChunk.add(data.asByteArray())
    }

    private fun decodeTransferSummaryData(characteristic: BluetoothGattCharacteristic, callback: ResBitDeviceCallback) {
        val value = characteristic.value.toUByteArray()
        val valueAsLong = uByteArrayToLong(value)
        messageListener("Value change in transferSummaryData: $valueAsLong")

        val timePassedInMillis = System.currentTimeMillis() - startTimeInMilliseconds
        messageListener("Total time to transfer: ${timePassedInMillis} milliseconds")
        if(valueAsLong == 0.toLong()) {
            // If summary data turns to 0, then all packets have been received

            //callback.onSummaryDataReceived(formatPacketsIntoSummaryData(totalPacketsReceived))
            //disconnect(true)
        }
    }

    private fun formatPacketsIntoSummaryData(packets: MutableList<ByteArray>): List<SummaryData> {
        var entirePacketStream:MutableList<Byte> = emptyList<Byte>().toMutableList()

        for (packet in packets) {
            //  First 2 values (positions 0 and 1) are just total packets and the packet index, we can ignore them
            for (i in 2 until packet.count()) {
                entirePacketStream.add(packet[i])
            }
        }

        return getAllSummaryDataEvents(entirePacketStream.toByteArray())
    }

    private fun getAllSummaryDataEvents(entirePacketStream:ByteArray):List<SummaryData> {
        var allSummaryDataEvents:MutableList<SummaryData> = emptyList<SummaryData>().toMutableList()

        var mutablePacketStream = entirePacketStream.toMutableList()
        // count must be greater than 6 because we need 1 byte for ID, 4 bytes for time, and 1 byte for data length.
        // So, at minimum we need 6 bytes to create an event.
        while (mutablePacketStream.count() > 0) {
            // A single packet holds up to 18 bytes of event summary data. In the worst case, the last received packet may only contain
            // a single byte of event summary data, and the last 17 bytes are just garbage filler data. If we're within the last 17 bytes,
            // we need to check if there's still summary data left, or if its just garbage filler. If its all 0's then its filler and we can ignore it all.
            if(mutablePacketStream.count() < 18) {
                // Let's check if there's one more summary event left in here...
                var eventSummaryExists = false
                for(i in 0 until mutablePacketStream.count()) {
                    if(mutablePacketStream[i] == 0u.toByte()) {
                        // Found a value that isn't 0, that means there must be some usable data in here
                        eventSummaryExists = true
                        break
                    }
                }
                // If the summary event doesn't exists we'll break out of the while loop, otherwise continue to record this last event.
                if(!eventSummaryExists) {
                    break
                }
            }
            var summaryEventData = emptyList<Byte>().toMutableList()
            var timeData = emptyList<Byte>().toMutableList()

            // Start index will contain summary event ID
            val summaryIDData = listOf<Byte>(mutablePacketStream[0],mutablePacketStream[1])
            val summaryID = uByteArrayToLong(summaryIDData.toByteArray().asUByteArray()).toUInt()

            mutablePacketStream.removeAt(0)
            mutablePacketStream.removeAt(0)

            if(mutablePacketStream.count() == 0) {
                messageListener("Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                break
            }

            // The next 4 indexes after that are the time value of the event, let's grab those.
            for(i in 0..3) {
                timeData.add(mutablePacketStream[0])
                mutablePacketStream.removeAt(0)

                if(mutablePacketStream.count() == 0) {
                    messageListener("Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                    break
                }
            }
            // The next index after the time value is the length of the upcoming data for this event, so grab that
            if(mutablePacketStream.count() == 0) {
                messageListener("Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                break
            }

            val lengthOfData = mutablePacketStream[0].toUByte()
            mutablePacketStream.removeAt(0)
            if(mutablePacketStream.count() == 0) {
                messageListener("Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                break
            }

            if(lengthOfData != 0u.toUByte()) {
                val length = lengthOfData.toUInt()
                // Now let's grab all the data that belongs to this summary event
                for(i in 0 until length.toInt()) {
                    summaryEventData.add(mutablePacketStream[0])
                    mutablePacketStream.removeAt(0)

                    if(mutablePacketStream.count() == 0) {
                        messageListener("Ran out of data in data stream. Data count was off. Ignoring this last summary event.")
                        break
                    }
                }
            }

            val summaryDataEvent = formatParsedPacketIntoSummaryData(summaryID, timeData.toByteArray(), lengthOfData.toUInt(), summaryEventData.toByteArray())
            allSummaryDataEvents.add(summaryDataEvent)
        }
        return allSummaryDataEvents
    }

    private fun formatParsedPacketIntoSummaryData(eventType: UInt, timeData: ByteArray, dataLength:UInt, eventData: ByteArray):SummaryData {
        var timeValue:Long = uByteArrayToLong(timeData.asUByteArray())

        return SummaryData(eventType, dataLength, timeValue, eventData)
    }

    private fun handleCharacteristic(serviceUUID:UUID, characteristicUUID:UUID) {
        val service = bluetoothGatt?.getService(serviceUUID)
        val characteristic = service?.getCharacteristic(characteristicUUID)

        if (characteristic != null) {
            handleCharacteristics(listOf(characteristic))
        }
    }

    private fun didWriteCharacteristic(characteristic:BluetoothGattCharacteristic, callback: ResBitDeviceCallback) {
        when(characteristic.uuid) {
            ResBitSummaryService.CHAR_UUID_RESPONSE.uuid -> {
                messageListener("Successful write to response, preparing write to Ack/Nack")
                // If we wrote to Response, that means we missed some packets and need the device to resend them
                // Discovering AckNack will check to see if we've received all packets, and if not, it'll write a 2 to AckNack to initiate the re-transfer
                handleCharacteristic(ResBitSummaryService.BASE.uuid, ResBitSummaryService.CHAR_UUID_ACK_NACK.uuid)
            }
            ResBitSummaryService.CHAR_UUID_ACK_NACK.uuid -> {
                messageListener("Successful write to Ack/Nack")
                totalPacketsReceived.addAll(packetsReceivedInChunk)
                packetsReceivedInChunk.clear()

                if (receivedAllPackets) {
                    callback.onSummaryDataReceived(formatPacketsIntoSummaryData(totalPacketsReceived))
                    messageListener("Summary done, disconnecting")
                    disconnect(true)
                    clear()
                }
            }
            ResBitSummaryService.CHAR_UUID_TRANSFER_SUMMARY_DATA.uuid -> {
                messageListener("Successful write to Transfer Summary Data")
                startTimeInMilliseconds = System.currentTimeMillis()
            }
            ResBitDeviceInfoService.CHAR_UUID_TIME.uuid -> {
                messageListener("Successful write to Time Characteristic")
                disconnect(true)
                clear()
            }
        }
    }

    private fun didUpdateNotificationState(characteristic: BluetoothGattCharacteristic) {
        messageListener("Set notify value for characteristic: ${characteristic.uuid}")
        when(characteristic.uuid) {
            ResBitSummaryService.CHAR_UUID_DATA.uuid -> {
                handleCharacteristic(ResBitSummaryService.BASE.uuid, ResBitSummaryService.CHAR_UUID_TRANSFERRING.uuid)
            }
            ResBitSummaryService.CHAR_UUID_TRANSFERRING.uuid -> {
                handleCharacteristic(ResBitSummaryService.BASE.uuid, ResBitSummaryService.CHAR_UUID_TRANSFER_SUMMARY_DATA.uuid)
            }
            ResBitSummaryService.CHAR_UUID_TRANSFER_SUMMARY_DATA.uuid -> {
                // Characteristics are discovered in the order they are on the chip. We don't want to start transferring data
                // until we've set the notify property on Data, Transferring, and TransferSummaryData.
                // So, since Transferring is ordered before TransferSummaryData, we wait to discover TransferSummaryData until we've set notify on Transferring.
                // Once notify has been set on TransferSummaryData, we can write to it and start data transfer.
                characteristic.value = ByteArray(1) { pos -> 1.toByte()}
                bluetoothGatt?.writeCharacteristic(characteristic)
                messageListener("Writing 1 to Transfer Summary Data")
            }
        }
    }

    fun UInt.toUByteArray(isBigEndian: Boolean = true): UByteArray {
        var bytes = ubyteArrayOf()

        var n = this

        if (n == 0x00u) {
            bytes += n.toUByte()
        } else {
            while (n != 0x00u) {
                val b = n.toUByte()

                bytes += b

                n = n.shr(Byte.SIZE_BITS)
            }
        }

        val padding = 0x00u.toUByte()
        var paddings = ubyteArrayOf()
        repeat(UInt.SIZE_BYTES - bytes.count()) {
            paddings += padding
        }

        return if (isBigEndian) {
            paddings + bytes.reversedArray()
        } else {
            paddings + bytes
        }
    }

    private fun createScanFiltersForIDs(serviceIDs:List<ResearchBitUUID>):List<ScanFilter> {
        val filters : MutableList<ScanFilter> = emptyList<ScanFilter>().toMutableList()
        
        for (uuid in serviceIDs) {
            val filter = ScanFilter.Builder()
                .setServiceUuid(uuid.toParcelUuid())
                .build()
            filters.add(filter)
        }

        return filters
    }

    private fun uByteArrayToLong(bytes: UByteArray): Long {
        var result:Long = 0
        var shift = 0
        for (byte in bytes) {
            result = result or (byte.toLong() shl shift)
            shift += 8
        }
        return result
    }

    private fun longToUInt32ByteArray(value: Long): ByteArray {
        val bytes = ByteArray(4)
        bytes[0] = (value and 0xFFFF).toByte()
        bytes[1] = ((value ushr 8) and 0xFFFF).toByte()
        bytes[2] = ((value ushr 16) and 0xFFFF).toByte()
        bytes[3] = ((value ushr 24) and 0xFFFF).toByte()
        return bytes
    }

    companion object {
        private const val TAG = "ResearchBit SDK"

        @Volatile private var instance: ResearchBitImpl? = null

        fun getInstance(context: Context): ResearchBitImpl =
            instance ?: synchronized(this) {
                instance ?: ResearchBitImpl(context).also { instance = it }
            }

        fun destroyInstance() {
            instance = null
        }
    }
}
