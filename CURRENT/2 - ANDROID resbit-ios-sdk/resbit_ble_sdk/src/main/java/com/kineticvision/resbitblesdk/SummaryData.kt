package com.kineticvision.resbitblesdk

import android.os.Build
import android.util.Base64.NO_WRAP
import android.util.Base64.URL_SAFE
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.*


class SummaryData(val eventType: UInt, val eventDataSize: UInt, eventTime: Long, data: ByteArray) {
    var eventUUID : UUID = UUID.randomUUID()
    var eventWakeupTime : Date = Date(eventTime * 1000)

    var eventFields : List<EventField<*>> = emptyList()
    init {

        when (eventType) {
            0u -> {
                var dataValue = littleEndianConversionUInt(data)
                val eventField = EventField("Awake Time", dataValue)
                eventFields = listOf(eventField)
            }
            1u -> {
                var dataValue = littleEndianConversionUInt(data)
                val eventField = EventField("Trigger Pulls", dataValue)
                eventFields = listOf(eventField)
            }
            2u -> {
                var dataValue = littleEndianConversionUIntList(data)
                val eventField = EventField("Tilt Angle", dataValue)
                eventFields = listOf(eventField)
            }
            3u -> {
                var dataValue = base64Conversion(data)
                val eventField = EventField("Blob UInt", dataValue)
                eventFields = listOf(eventField)
            }
            4u -> {
                var dataValue = base64Conversion(data)
                val eventField = EventField("Blob Float", dataValue)
                eventFields = listOf(eventField)
            }
        }
    }

    private fun littleEndianConversionUInt(bytes: ByteArray): UInt {
        var byteCopy = bytes.copyOf(4) // pads to 4 bytes if necessary
        return ByteBuffer.wrap(byteCopy).order(ByteOrder.LITTLE_ENDIAN).int.toUInt()
    }

    private fun littleEndianConversionFloat(bytes: ByteArray): Float {
        var byteCopy = bytes.copyOf(4) // pads to 4 bytes if necessary
        return ByteBuffer.wrap(byteCopy).order(ByteOrder.LITTLE_ENDIAN).float
    }

    private fun littleEndianConversionUIntList(bytes: ByteArray): List<UInt> {
        var list = emptyList<UInt>().toMutableList()
        for (i in 0 until bytes.count() step 4) {
            val byteRange = bytes.copyOfRange(i, i+4)
            list.add(littleEndianConversionUInt(byteRange))
        }
        return list
    }

    private fun littleEndianConversionFloatList(bytes: ByteArray): List<Float> {
        var list = emptyList<Float>().toMutableList()
        for (i in 0 until bytes.count() step 4) {
            val byteRange = bytes.copyOfRange(i, i+4)
            list.add(littleEndianConversionFloat(byteRange))
        }
        return list
    }

    private fun hexConversion(bytes:ByteArray): String {
        var hexString = ""
        for (b in bytes) {
            val st = String.format("%02X", b)
            hexString += st
        }
        return hexString
    }

    private fun base64Conversion(bytes:ByteArray): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Base64.getEncoder().encodeToString(bytes)
        } else {
            android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
        }
    }
}
