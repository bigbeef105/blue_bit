package com.kineticvision.resbitblesdk

import android.os.Parcel
import android.os.ParcelUuid
import android.os.Parcelable
import java.util.*

class ResearchBitUUIDHelpers {
    companion object {
        fun fullUUIDForID(id: String): UUID {
            return UUID.fromString("240F$id-2498-4B36-BC0C-EDCCC32D0635")
        }
    }
}

interface ResearchBitUUID {
    val uuid: UUID

    fun toParcelUuid(): ParcelUuid {
        return ParcelUuid(uuid)
    }
}

enum class ResBitSummaryService(override val uuid: UUID) : ResearchBitUUID {
    BASE(ResearchBitUUIDHelpers.fullUUIDForID("AA00")),

    CHAR_UUID_DATA(ResearchBitUUIDHelpers.fullUUIDForID("AA01")),
    CHAR_UUID_TRANSFER_SUMMARY_DATA(ResearchBitUUIDHelpers.fullUUIDForID("AA02")),
    CHAR_UUID_TRANSFERRING(ResearchBitUUIDHelpers.fullUUIDForID("AA03")),
    CHAR_UUID_ACK_NACK(ResearchBitUUIDHelpers.fullUUIDForID("AA04")),
    CHAR_UUID_RESPONSE(ResearchBitUUIDHelpers.fullUUIDForID("AA05")),
    CHAR_UUID_REGISTERED(ResearchBitUUIDHelpers.fullUUIDForID("AA06")),
    CHAR_UUID_ENABLE_DEBUG(ResearchBitUUIDHelpers.fullUUIDForID("AA07")),
    CHAR_UUID_RESBIT_SERIAL_NUMBER(ResearchBitUUIDHelpers.fullUUIDForID("AA08")),
    CHAR_UUID_RESBIT_TRANSFER_ERROR(ResearchBitUUIDHelpers.fullUUIDForID("AA09"));

    override fun toString(): String {
        return uuid.toString()
    }
}

enum class DeviceInfoService(override val uuid: UUID) : ResearchBitUUID {
    BASE(ResearchBitUUIDHelpers.fullUUIDForID("180A")), // TBD

    CHAR_UUID_MANUFACTURER_NAME(ResearchBitUUIDHelpers.fullUUIDForID("2A29")),
    CHAR_UUID_MODULE_NUMBER(ResearchBitUUIDHelpers.fullUUIDForID("2A24")),
    CHAR_UUID_SERIAL_NUMBER(ResearchBitUUIDHelpers.fullUUIDForID("2A25")),
    CHAR_UUID_HARDWARE_REVISION(ResearchBitUUIDHelpers.fullUUIDForID("2A27")),
    CHAR_UUID_FIRMWARE_REVISION(ResearchBitUUIDHelpers.fullUUIDForID("2A26")),
    CHAR_UUID_SOFTWARE_REVISION(ResearchBitUUIDHelpers.fullUUIDForID("2A28")),
    CHAR_UUID_SYSTEM_ID(ResearchBitUUIDHelpers.fullUUIDForID("2A23"));

    override fun toString(): String {
        return uuid.toString()
    }
}

enum class ResBitDeviceInfoService(override val uuid: UUID) : ResearchBitUUID {
    BASE(ResearchBitUUIDHelpers.fullUUIDForID("AC00")),

    CHAR_UUID_FIRMWARE_REVISION(ResearchBitUUIDHelpers.fullUUIDForID("AC01")),
    CHAR_UUID_HARDWARE_REVISION(ResearchBitUUIDHelpers.fullUUIDForID("AC02")),
    CHAR_UUID_MODEL_NUMBER(ResearchBitUUIDHelpers.fullUUIDForID("AC03")),
    CHAR_UUID_SERIAL_NUMBER(ResearchBitUUIDHelpers.fullUUIDForID("AC04")),
    CHAR_UUID_TIME(ResearchBitUUIDHelpers.fullUUIDForID("AC05"));

    override fun toString(): String {
        return uuid.toString()
    }
}

enum class BLEDeviceServiceUUIDs(override val uuid: UUID) : ResearchBitUUID {
    DEVICE_INFO_SERVICE(ResearchBitUUIDHelpers.fullUUIDForID("180A")),
    SUMMARY_SERVICE(ResearchBitUUIDHelpers.fullUUIDForID("180A")),

    NORDIC_CHIP_SERVICE(UUID.fromString("00001523-1212-EFDE-1523-785FEABCD123")),
    RESBIT_SERVICE(UUID.fromString("00000000-1212-EFDE-1523-785FEABCD123"));

    override fun toString(): String {
        return uuid.toString()
    }

    companion object {
        fun allServices(): List<BLEDeviceServiceUUIDs> {
            return listOf(NORDIC_CHIP_SERVICE, RESBIT_SERVICE)
        }
    }
}

enum class BLEDeviceCharacteristicUUIDs(override val uuid: UUID) : ResearchBitUUID {
    DATA(UUID.fromString("00001524-1212-EFDE-1523-785FEABCD123")), // TBD
    BUTTON_STATE(UUID.fromString("00001524-1212-EFDE-1523-785FEABCD123")),
    LED_STATE(UUID.fromString("00001525-1212-EFDE-1523-785FEABCD123")),
    SHOULD_TRANSFER_SUMMARY_DATA(UUID.fromString("00001525-1212-EFDE-1523-785FEABCD123"));

    override fun toString(): String {
        return uuid.toString()
    }

    companion object {
        fun nordicChipCharacteristicIDs(): List<BLEDeviceCharacteristicUUIDs> {
            return listOf(BUTTON_STATE, LED_STATE)
        }

        fun resBitCharacteristicIDs(): List<BLEDeviceCharacteristicUUIDs> {
            return listOf(SHOULD_TRANSFER_SUMMARY_DATA)
        }
    }
}
