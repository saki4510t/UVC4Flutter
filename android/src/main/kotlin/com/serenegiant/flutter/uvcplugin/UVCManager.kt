/**
 * Copyright (c) 2020-2026 saki t_saki@serenegiant.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
package com.serenegiant.flutter.uvcplugin

import android.app.Activity
import android.util.Log
import android.util.SparseArray
import android.view.Surface
import android.view.WindowManager
import androidx.annotation.Keep
import androidx.core.util.forEach
import com.serenegiant.usb.DeviceDetector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.lang.ref.WeakReference

/**
 * UVCManager
 */
@Keep
class UVCManager: FlutterPlugin, MethodCallHandler, ActivityAware {
  /**
   * The MethodChannel that will the communication between Flutter and native Android
   * This local reference serves to register the plugin with the Flutter Engine and unregister it
   * when the Flutter Engine is detached from the Activity
   */
  private lateinit var mChannel : MethodChannel
  private lateinit var mTextureRegistry: TextureRegistry
  private lateinit var mActivity: WeakReference<Activity>
  /**
   * デバイスIDとSurfaceProducerのマップ
   */
  private val mSurfaceProducers = SparseArray<TextureRegistry.SurfaceProducer>()
  private var mNeedInitialize = false

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    if (DEBUG) Log.v(TAG, "onAttachedToEngine:")
    NativeLibLoader.loadNative()
    nativeInit()
    mTextureRegistry = flutterPluginBinding.textureRegistry
    mChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL_NAME)
    mChannel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    if (DEBUG) Log.v(TAG, "onDetachedFromEngine:")
    mChannel.setMethodCallHandler(null)
    nativeRelease()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    if (DEBUG) Log.v(TAG, "onAttachedToActivity:")
    mActivity = WeakReference(binding.activity)
    if (mNeedInitialize) {
      mNeedInitialize = false
      // 多分無いと思うけどメソッドコールからの"initialize"が先に来てしまったとき
      if (DEBUG) Log.v(TAG, "onAttachedToActivity:initUVCDeviceDetector")
      DeviceDetector.initUVCDeviceDetector(binding.activity)
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    if (DEBUG) Log.v(TAG, "onDetachedFromActivityForConfigChanges:")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    if (DEBUG) Log.v(TAG, "onReattachedToActivityForConfigChanges:")
    mActivity = WeakReference(binding.activity)
  }

  override fun onDetachedFromActivity() {
    if (DEBUG) Log.v(TAG, "onDetachedFromActivity:")
    mNeedInitialize = false
    releaseTextureAll()
    val a = mActivity.get()
    if (a != null) {
      if (DEBUG) Log.v(TAG, "onDetachedFromActivity:releaseDeviceDetector")
      DeviceDetector.releaseDeviceDetector(a)
    }
  }

  /**
   * MethodCallHandlerインターフェースの実装
   */
  override fun onMethodCall(call: MethodCall, result: Result) {
    if (DEBUG) Log.v(TAG, "onMethodCall:${call.method}")
    when (call.method) {
      "initialize" -> {
        val a = mActivity.get()
        if (a != null) {
          if (DEBUG) Log.v(TAG, "onMethodCall#initialize:initUVCDeviceDetector")
          DeviceDetector.initUVCDeviceDetector(a)
        } else {
          mNeedInitialize = true
        }
      }
      "createTexture" -> {
        val deviceId: Int? = call.argument("deviceId")
        val width: Int? = call.argument("width")
        val height: Int? = call.argument("height")
        if ((deviceId != null) && (width != null) && (height != null)) {
          result.success(createTexture(deviceId, width, height))
        } else {
          result.error("failed to get deviceId/width/height", null, null)
        }
      }
      "releaseTexture" -> {
        val deviceId: Int? = call.argument("deviceId")
        val texId: Any? = call.argument("textureId")
        val textureId = if (texId is Int) texId.toLong() else (texId as Long?)
        if ((deviceId != null) && (textureId != null)) {
          releaseTexture(deviceId, textureId)
        }
        result.success(null)
      }
      "keepScreenOn" -> {
        val activity = mActivity.get()
        if (activity != null) {
          val window = activity.window
          val onoff: Boolean? = call.argument("onoff")
          if (window != null) {
            activity.runOnUiThread {
              if (onoff == true) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
              } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
              }
            }
          }
          result.success(null)
          return
        }
        result.error("No Activity", null, null)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  //--------------------------------------------------------------------------------
  /**
   * Dart側からのメソッドコールの実体
   * Dart側のTextureで表示するためSurfaceTextureを生成しテクスチャidを返す
   * XXX 今の仕様的に１つのUVC機器に対して1つのSurface/テキスチャでしか映像を受け取ることができないので
   *     同じデバイスIDに対して複数回呼び出しても同じテクスチャID(Surface)を返す
   * @param deviceId 対象とするUVC機器のid
   * @param width
   * @param height
   * @return テクスチャid
   */
  private fun createTexture(deviceId: Int, width: Int, height: Int): Long {
    if (DEBUG) Log.v(TAG, "createTexture:deviceId=${deviceId}/(${width}x${height})")
    try {
      val producer = mSurfaceProducers[deviceId] ?: mTextureRegistry.createSurfaceProducer()
      producer.setSize(width, height)
      mSurfaceProducers[deviceId] = producer
      // native側へSurfaceをセット
      nativeSetSurface(deviceId, producer.id(), producer.surface)
      if (DEBUG) Log.v(TAG, "createTexture:producer=${producer}")
      return producer.id()
    } catch (e: Exception) {
      if (DEBUG) Log.w(TAG, e)
      throw e
    }
  }

  /**
   * Dart側からのメソッドコールの実体
   * Dart側でTextureを使って表示するのに使っていたテクスチャ/SurfaceTextureを破棄する
   * @param deviceId 対象とするUVC機器のid
   */
  private fun releaseTexture(deviceId: Int, textureId: Long) {
    if (DEBUG) Log.v(TAG, "releaseTexture:deviceId=${deviceId},textureId=${textureId}")
    nativeSetSurface(deviceId, -1, null)
    val producer = mSurfaceProducers.get(deviceId)
    producer?.release()
    mSurfaceProducers.remove(deviceId)
  }

  /**
   * テクスチャ/Surfaceが生成されていれば破棄する
   * activityからデタッチされるときに呼び出す
   */
  private fun releaseTextureAll() {
    if (DEBUG) Log.v(TAG, "releaseTextureAll:")
    mSurfaceProducers.forEach { _, producer ->
      producer.release()
    }
    mSurfaceProducers.clear()
  }

  @Keep
  external fun nativeInit(): Int

  @Keep
  external fun nativeRelease(): Int

  @Keep
  external fun nativeSetSurface(deviceId: Int, texId: Long, surface: Surface?): Int

  companion object {
    private const val DEBUG = false // set false on production
    private val TAG = UVCManager::class.java.simpleName

    private const val METHOD_CHANNEL_NAME = "com.serenegiant.flutter/aandusb_method"
  }
}
