package com.serenegiant.usb
/**
 * aAndUsb
 * Copyright (c) 2014-2026 saki t_saki@serenegiant.com
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

import android.app.Activity
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbInterface
import android.os.Bundle
import android.util.Log
import androidx.annotation.Keep
import androidx.annotation.XmlRes
import com.serenegiant.uvc_manager.R
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Java側でUSB関係のイベントを処理してnative側へ引き渡すための
 * ヘルパークラス
 */
@Keep
class DeviceDetector private constructor() {
	//--------------------------------------------------------------------------------
	/**
	 * native側からから呼び出されたときの通知用インターフェース
	 */
	@Keep
	interface DeviceDetectorCallback {
		fun onRequestRefreshDevices()
		fun onRequestClaimInterfaces(
			device: UsbDevice,
			interfaces: List<UsbInterface?>
		): Boolean

		fun onRequestReleaseInterfaces(
			device: UsbDevice,
			interfaces: List<UsbInterface?>
		): Boolean
	}

	//--------------------------------------------------------------------------------
	private val mCallbacks: MutableSet<DeviceDetectorCallback> = CopyOnWriteArraySet()
	private val mDevices: MutableMap<String, UsbDevice> = HashMap()

	/**
	 * コンストラクタ
	 */
	init {
		if (DEBUG) Log.v(TAG, "DeviceDetector:")
		nativeCreate()
	}

	private fun release() {
		if (DEBUG) Log.v(TAG, "release:")
		nativeRelease()
	}

	/**
	 * UsbDeviceが検出＆パーミッション取得できたときの処理
	 * @param device 接続されたUSB機器を示すUsbDevice
	 * @param fileDescriptor USB機器へアクセスするためのファイルディスクリプタ
	 */
	fun add(device: UsbDevice, fileDescriptor: Int) {
		val name = device.deviceName
		if (DEBUG) Log.v(TAG, "add:$name")
		mDevices[name] = device
		nativeAdd(name, fileDescriptor)
	}

	/**
	 * UsbDeviceが取り外されたときの処理
	 * @param device 取り外されたUSB機器を示すUsbDevice
	 */
	fun remove(device: UsbDevice) {
		val name = device.deviceName
		if (DEBUG) Log.v(TAG, "remove:$name")
		nativeRemove(name)
		mDevices.remove(name)
	}

	fun clearAll() {
		if (DEBUG) Log.v(TAG, "clearAll:")
		nativeClearAll()
	}

	fun add(callback: DeviceDetectorCallback) {
		if (DEBUG) Log.v(TAG, "add:$callback")
		mCallbacks.add(callback)
	}

	fun remove(callback: DeviceDetectorCallback) {
		if (DEBUG) Log.v(TAG, "remove:$callback")
		mCallbacks.remove(callback)
	}

	/**
	 * native側からの接続機器リフレッシュ要求
	 */
	/*CallByNative*/
	@Keep
	private fun onRequestRefreshDevice() {
		if (DEBUG) Log.v(TAG, "onRequestRefreshDevice:")
		for (callback in mCallbacks) {
			callback.onRequestRefreshDevices()
		}
	}

	/**
	 * native側からのインターフェースclaim要求
	 * @param name
	 * @param clazz
	 * @param subClass
	 * @param protocol
	 */
	/*CallByNative*/
	@Keep
	private fun onRequestClaimInterfaces(
		name: String,
		clazz: Int, subClass: Int, protocol: Int
	) {
		val device = if (mDevices.containsKey(name)) mDevices[name] else null
		if (DEBUG) Log.v(TAG, "onRequestClaimInterfaces:${ (device?.deviceName ?: "")}")
		if (device != null) {
			val interfaces = UsbUtils.findInterfaces(device, clazz, subClass, protocol)
			for (callback in mCallbacks) {
				callback.onRequestClaimInterfaces(device, interfaces)
			}
		}
	}

	/**
	 * native側からのインターフェースrelease要求
	 * @param name
	 * @param clazz
	 * @param subClass
	 * @param protocol
	 */
	/*CallByNative*/
	@Keep
	private fun onRequestReleaseInterfaces(
		name: String,
		clazz: Int, subClass: Int, protocol: Int
	) {
		val device = if (mDevices.containsKey(name)) mDevices[name] else null
		if (DEBUG) Log.v(TAG, "onRequestReleaseInterfaces:${(device?.deviceName ?: "")}")
		if (device != null) {
			val interfaces = UsbUtils.findInterfaces(device, clazz, subClass, protocol)
			for (callback in mCallbacks) {
				callback.onRequestReleaseInterfaces(device, interfaces)
			}
		}
	}

	/**
	 * nativeCreateはnative側へJava側のDeviceDetectorオブジェクトを引き渡すためstaticメソッドではない
	 * @return
	 */
	private external fun nativeCreate(): Int
	private external fun nativeRelease(): Int
	private external fun nativeClearAll(): Int
	private external fun nativeAdd(name: String, fileDescriptor: Int): Int
	private external fun nativeRemove(name: String): Int

	companion object {
		private const val DEBUG = false // set false on production
		private val TAG: String = DeviceDetector::class.java.simpleName

		private const val ARGS_DEVICE_FILTERS = "ARGS_DEVICE_FILTERS"

		/**
		 * DeviceDetectorをUVC機器用に初期化(非UI Fragmentを使ってシングルトン的にアクセスする)
		 * @param activity
		 */
		@Keep
		fun initUVCDeviceDetector(
			activity: Activity
		) {
			initDeviceDetector(activity, R.xml.device_filter_uvc)
		}

		/**
		 * DeviceDetectorを初期化(非UI Fragmentを使ってシングルトン的にアクセスする)
		 * @param activity
		 * @param filters
		 * @return
		 */
		@Suppress("deprecation")
		@Keep
		fun initDeviceDetector(
			activity: Activity, @XmlRes filtersXml: Int
		) {
			if (DEBUG) Log.v(TAG, "initDeviceDetector:")
			val fm = activity.fragmentManager
			var detector = fm.findFragmentByTag(DeviceDetectorFragment::class.java.name)
			if (detector !is DeviceDetectorFragment) {
				val ft = fm.beginTransaction()
				if (detector != null) {
					ft.remove(detector)
				}
				detector = DeviceDetectorFragment()
				val args = Bundle()
				if (filtersXml != 0) {
					val filters = ArrayList(DeviceFilter.getDeviceFilters(activity, filtersXml))
					args.putParcelableArrayList(ARGS_DEVICE_FILTERS, filters)
				}
				detector.setArguments(args)
				ft.add(detector, DeviceDetectorFragment::class.java.name).commit()
			}
		}

		/**
		 * DeviceDetectorを解放する
		 * @param activity
		 */
		@Suppress("deprecation")
		@Keep
		fun releaseDeviceDetector(activity: Activity) {
			if (DEBUG) Log.v(TAG, "releaseDeviceDetector:")
			val fm = activity.fragmentManager
			val detector = fm.findFragmentByTag(DeviceDetectorFragment::class.java.name)
			if (detector != null) {
				val ft = fm.beginTransaction()
				ft.remove(detector)
				ft.commit()
			}
		}

		/**
		 * DeviceDetectorインスタンスを生成する
		 * XXX DeviceDetectorを自前で生成することは基本的にないはず
		 * 代わりにinitDeviceDetector/initUVCDeviceDetectorを使って
		 * 非UIフラグメントで生成・保持させる
		 * @return
		 */
		@Synchronized
		fun createInstance(): DeviceDetector {
			return DeviceDetector()
		}
	}
}
