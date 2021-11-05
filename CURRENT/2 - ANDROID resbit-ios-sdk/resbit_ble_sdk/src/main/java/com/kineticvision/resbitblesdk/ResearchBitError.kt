package com.kineticvision.resbitblesdk

enum class ResearchBitError {
    POWERED_OFF {
        override fun description(): String {
            return "BLE Powered Off"
        }
    },
    CONNECTION_TIMEOUT {
        override fun description(): String {
            return "BLE Connection Timed Out"
        }
    },
    IDENTIFIER_NOT_FOUND {
        override fun description(): String {
            return "BLE Identifier Not Found"
        }
    },
    SERVICE_FETCH_TIMEOUT {
        override fun description(): String {
            return "BLE Timed out while attempting to fetch services"
        }
    },
    CHARACTERISTIC_FETCH_TIMEOUT {
        override fun description(): String {
            return "BLE timed out while attempting to fetch characteristics for this peripheral"
        }
    },
    DEVICE_UNEXPECTEDLY_DISCONNECTED {
        override fun description(): String {
            return "No GATT connection"
        }
    };


    abstract fun description():String
}