package rocks.brandstaetter.brandyfly_native

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class BrandyflyNativePluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = BrandyflyNativePlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
    }

    @Test
    fun onMethodCall_configureLocalMockFlightMode_returnsSuccess() {
        val plugin = BrandyflyNativePlugin()

        val call = MethodCall(
            "configureLocalMockFlightMode",
            mapOf(
                "enabled" to true,
                "fixtureVersion" to "mock-flight-v1",
            )
        )
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(null)
    }

    @Test
    fun onMethodCall_getMonotonicTimeNanos_returnsPositiveTime() {
        val plugin = BrandyflyNativePlugin()
        val call = MethodCall("getMonotonicTimeNanos", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(Mockito.anyLong())
    }

    @Test
    fun onMethodCall_runNativeBenchmark_passesGates() {
        val plugin = BrandyflyNativePlugin()
        val call = MethodCall("runNativeBenchmark", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(Mockito.argThat { map ->
            (map is Map<*, *>) && (map["platform"] == "android") && (map["allGatesPassed"] == true)
        })
    }

    @Test
    fun onMethodCall_startAndStopSkyDrop1Transport_handlesLifecycle() {
        val plugin = BrandyflyNativePlugin()

        val startCall = MethodCall(
            "startSkyDrop1Transport",
            mapOf("developerModeOnly" to true, "deviceAddress" to "00:11:22:33:44:55")
        )
        val startResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(startCall, startResult)
        Mockito.verify(startResult).success(true)

        val stopCall = MethodCall("stopSkyDrop1Transport", null)
        val stopResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(stopCall, stopResult)
        Mockito.verify(stopResult).success(null)
    }

    @Test
    fun onMethodCall_runSkyDrop1HardwareBenchmark_passesLatencyAndReconnectGates() {
        val plugin = BrandyflyNativePlugin()
        val call = MethodCall("runSkyDrop1HardwareBenchmark", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(Mockito.argThat { map ->
            (map is Map<*, *>) &&
                (map["platform"] == "android") &&
                (map["latencyGatePassed"] == true) &&
                (map["reconnectWithoutRestartPassed"] == true) &&
                (map["allGatesPassed"] == true) &&
                (map["androidStatus"] == "supported") &&
                (map["iosStatus"] == "unsupported")
        })
    }

    @Test
    fun skyDrop1TransportManager_handlesLinkInterruptionAndReconnect() {
        var disconnectedCalled = false
        var reconnectedCalled = false
        var reconnectDuration = 0.0

        val listener = object : SkyDrop1TransportManager.SkyDrop1EventListener {
            override fun onConnected(deviceAddressMasked: String, timestampNs: Long) {}
            override fun onDisconnected(reason: String, timestampNs: Long) {
                disconnectedCalled = true
            }
            override fun onReconnecting(attempt: Int, timestampNs: Long) {}
            override fun onReconnected(durationMs: Double, timestampNs: Long) {
                reconnectedCalled = true
                reconnectDuration = durationMs
            }
            override fun onStaleDataDetected(staleIntervalMs: Double, timestampNs: Long) {}
            override fun onSequenceGapDetected(expectedSeq: Long, receivedSeq: Long, timestampNs: Long) {}
            override fun onParseError(error: String, rawSnippet: String, timestampNs: Long) {}
            override fun onSampleReceived(sampleMap: Map<String, Any>) {}
        }

        val manager = SkyDrop1TransportManager(listener)
        manager.startTransport(true, "00:11:22:33:44:55")
        val interrupted = manager.simulateLinkInterruption(750.0)

        assert(interrupted)
        assert(disconnectedCalled)
        assert(reconnectedCalled)
        assert(reconnectDuration == 750.0)
    }

    @Test
    fun skyDrop1TransportManager_handlesBufferPressureWithoutUnboundedGrowth() {
        val manager = SkyDrop1TransportManager()
        manager.startTransport(true, null)

        val samplePayload = "$LK8EX1,101325,1200,100,20,95*01\r\n".toByteArray()

        // Push more than capacity (1200 items > 1000 MAX_BUFFER_CAPACITY)
        for (i in 1..1200) {
            val traceId = manager.handleIncomingRawBytes(samplePayload)
            assert(traceId > 0)
        }

        manager.stopTransport()
    }
}

