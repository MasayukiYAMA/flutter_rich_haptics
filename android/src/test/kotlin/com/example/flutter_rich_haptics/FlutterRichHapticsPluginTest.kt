package com.example.flutter_rich_haptics

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito

internal class FlutterRichHapticsPluginTest {
  @Test
  fun onMethodCall_supportsHaptics_returnsBoolean() {
    val plugin = FlutterRichHapticsPlugin()

    val call = MethodCall("supportsHaptics", null)
    val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).success(Mockito.anyBoolean())
  }
}
