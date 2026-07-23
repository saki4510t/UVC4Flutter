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

#define LOG_TAG "FlutterPluginJava"

#if 1	// デバッグ情報を出さない時は1
	#ifndef LOG_NDEBUG
		#define	LOG_NDEBUG		// LOGV/LOGD/MARKを出力しない時
	#endif
	#undef USE_LOGALL			// 指定したLOGxだけを出力
	#ifndef LOG_NDEBUG
		#define	LOG_NDEBUG		// LOGV/LOGD/MARKを出力しない時
	#endif
#else
	#define USE_LOGALL
	#define USE_LOGD
	#undef LOG_NDEBUG
	#undef NDEBUG
#endif

// android
#include <android/native_window.h>
#include <android/native_window_jni.h>
// aandusb
#include "utilbase.h"
// common
#include "common/jni_utils.h"
// flutter
#include "flutter_utils.h"
#include "flutter_uac_holder.h"
#include "flutter_uvc_holder.h"
#include "flutter_plugin_java.h"

namespace serenegiant::flutter {

/**
 * コンストラクタ
 */
/*private*/
FlutterPluginJava::FlutterPluginJava(jobject plugin_java)
:	plugin_java(plugin_java),
	m_manager(nullptr),
	uvc_holders(),
	uac_holders()
{
	ENTER();

	m_manager = manager_init(this, on_device_attach, on_device_detach);

	EXIT();
}

/**
 * デストラクタ
 */
FlutterPluginJava::~FlutterPluginJava() noexcept {
	ENTER();

	terminate_all();

	if (m_manager) {
		manager_release(m_manager);
		m_manager = nullptr;
	}

	if (plugin_java) {
		AutoJNIEnv _env;
		JNIEnv *env = _env.get();
		if (env) {
			LOGD("delete global ref of plugin object");
			env->DeleteGlobalRef(plugin_java);
			env->ExceptionClear();
		} else {
			LOGE("Failed to get JNIEnv");
		}
		plugin_java = nullptr;
	}

	EXIT();
}

/**
 * 使用中のＵＶＣ機器があれば終了させる
 */
/*private*/
void FlutterPluginJava::terminate_all() {
	ENTER();
	
	std::lock_guard<std::mutex> lock(m_lock);

	LOGV("release holder(s)");
	for (const auto& iter: uvc_holders) {
		LOGD("stop&remove,%d", iter.first);
		FlutterUVCHolderSp holder = iter.second;
		if (holder) {
			holder->stop();
			holder.reset();
		}
	}
	uvc_holders.clear();

	EXIT();
}

/**
 * 指定したidに対応するUACHolderSpを取得する
 * 存在していない場合にcreate_if_absent=trueならUACHolderSpを生成する
 * @param device_id
 * @param create_if_absent
 * @return
 */
std::shared_ptr<FlutterUACHolder> FlutterPluginJava::get_uac_holder_locked(const int32_t &device_id, const bool &create_if_absent) {
	ENTER();

	LOGD("id=%d,create_if_absent=%d", device_id, create_if_absent);
	LOGD("num holders=%" FMT_SIZE_T, uac_holders.size());

	FlutterUACHolderSp result;
	auto iter = uac_holders.find(device_id);
	if (iter != uac_holders.end()) {
		LOGD("found");
		result = iter->second;
	} else if (create_if_absent) {
		LOGD("UACHolder not found, create new");
		result = std::make_shared<FlutterUACHolder>(m_manager, device_id);
		uac_holders[device_id] = result;
	}

	RET(result);
}

/**
 * 指定したidに対応するUVCHolderSpを取得する
 * 存在していない場合にcreate_if_absent=trueならUVCHolderSpを生成する
 * @param device_id
 * @param create_if_absent
 * @return
 */
/*private*/
FlutterUVCHolderSp FlutterPluginJava::get_uvc_holder_locked(const int32_t &device_id, const bool &create_if_absent) {
	ENTER();

	LOGD("id=%d,create_if_absent=%d", device_id, create_if_absent);
	LOGD("num holders=%" FMT_SIZE_T, uvc_holders.size());

	FlutterUVCHolderSp result;
	auto iter = uvc_holders.find(device_id);
	if (iter != uvc_holders.end()) {
		LOGD("found");
		result = iter->second;
	} else if (create_if_absent) {
		LOGD("UVCHolder not found, create new");
		result = std::make_shared<FlutterUVCHolder>(m_manager, device_id);
		uvc_holders[device_id] = result;
	}

	RET(result);
}

/**
 * UVC機器が接続された時の処理
 * @param info
 */
/*private*/
int FlutterPluginJava::add(const int32_t &device_id) {
	ENTER();

	int result = -1;
	{
		std::lock_guard<std::mutex> lock(m_lock);
		auto holder = get_uvc_holder_locked(device_id, true);
		if (holder) {
			get_uac_holder_locked(device_id, true);
			result = 0;
		}
	}
	if (!result) {
		result = send_on_device_changed(device_id, true);
	}

	RETURN(result, int);
}

/**
 * UVC機器が取り外されたときの処理
 * @param device_id
 */
/*private*/
void FlutterPluginJava::remove(const int32_t &device_id) {
	ENTER();

	FlutterUVCHolderSp uvc_removed;
	FlutterUACHolderSp uac_removed;
	{
		std::lock_guard<std::mutex> lock(m_lock);
		auto uvc_iter = uvc_holders.find(device_id);
		if (uvc_iter != uvc_holders.end()) {
			uvc_removed = uvc_iter->second;
			uvc_holders.erase(device_id);
		}
		auto uac_iter = uac_holders.find(device_id);
		if (uac_iter != uac_holders.end()) {
			uac_removed = uac_iter->second;
			uac_holders.erase(device_id);
		}
	}
	if (uvc_removed) {
		LOGD("remove %d", device_id);
		uvc_removed->stop();
		LOGD("remove: finished");
	}
	if (uac_removed) {
		LOGD("remove %d", device_id);
		uac_removed->stop();
		LOGD("remove: finished");
	}
	if (uvc_removed || uac_removed) {
		send_on_device_changed(device_id, false);
	}

	EXIT();
}

/**
 * 指定したIDに対応するUVC機器が接続されていて利用可能かどうか
 * @param device_id
 * @return
 */
bool FlutterPluginJava::is_available(const int32_t &device_id) {
	ENTER();

	FlutterUVCHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uvc_holder_locked(device_id, false);
		m_lock.unlock();
	}

	RETURN(holder != nullptr, bool);
}

/**
 * UVC機器との接続状態を取得する
 * @param device_id
 * @return
 */
device_state_t FlutterPluginJava::get_device_state(const int32_t &device_id) {
	ENTER();

	device_state_t result = DISCONNECTED;
	FlutterUVCHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uvc_holder_locked(device_id, false);
		m_lock.unlock();
	}
	result = holder && holder->is_running() ? STREAMING : CONNECTED;

	RETURN(result, device_state);
}

usb_device_info_t FlutterPluginJava::get_device_info(const int32_t &device_id) {
	ENTER();

	usb_device_info_t result;
	usb_get_device_info(m_manager, device_id, &result);

	RET(result);
}

/**
 * 映像取得開始
 * レンダーコールバックを呼び出さないと実際には描画されない
 * @param device_id
 * @return
 */
/*public*/
int32_t FlutterPluginJava::start(const int32_t &device_id) {
	ENTER();

	int32_t  result = -1;
	FlutterUVCHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uvc_holder_locked(device_id, false);
		m_lock.unlock();
	}
	if (holder) {
		result = holder->start();
	} else {
		LOGW("failed to get UVCHolder");
	}

	RETURN(result, int32_t);
}

/**
 * 映像取得終了
 * @param info
 * @return
 */
/*public*/
int32_t FlutterPluginJava::stop(const int32_t &device_id) {
	ENTER();

	FlutterUVCHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uvc_holder_locked(device_id, false);
		m_lock.unlock();
	}
	if (holder) {
		holder->stop();
	}

	RETURN(0, int32_t);
}

/**
 * UVC機器からの映像サイズの変更要求
 * @param info
 * @param width
 * @param height
 * @return
 */
/*private*/
int32_t FlutterPluginJava::set_video_size(const int32_t &device_id,
	const uvc_raw_frame_t &frame_type,
	const uint32_t &width, const uint32_t &height) {

	ENTER();

	LOGV("id=%d,type=%d,sz(%dx%d)", device_id, frame_type, width, height);
	int result = -1;
	std::lock_guard<std::mutex> lock(m_lock);
	auto iter = uvc_holders.find(device_id);
	if (iter != uvc_holders.end()) {
		FlutterUVCHolderSp holder = iter->second;
		if (holder) {
			result = holder->set_video_size(frame_type, width, height);
		} else {
			LOGW("Failed to get UVCHolder");
		}
	} else {
		LOGW("UVCHolder not found, already detached?");
	}

	RETURN(result, int32_t);
}

/**
 * 現在の映像サイズ設定を取得
 * @param device_id
 * @param data 映像サイズ設定を書き込むためのflutter_video_size_t構造体へのポインタ
 * @return 0: 成功, 負: エラーコード
 */
int FlutterPluginJava::get_current_size(
	const int &device_id,
	uvc_video_size_t *data) {

	ENTER();

	int result = -1;
	if (LIKELY(data)) {
		std::lock_guard<std::mutex> lock(m_lock);
		auto iter = uvc_holders.find(device_id);
		if (iter != uvc_holders.end()) {
			auto &holder = iter->second;
			if (holder) {
				*data = holder->get_current_size();
				result = 0;
			} else {
				LOGW("Failed to get UVCHolder");
			}
		} else {
			LOGW("UVCHolder not found, already detached?");
		}
	}

	RETURN(result, int32_t);
}

/**
 * 映像取得用のSurfaceをセットする
 * @param device_id
 * @param tex_id
 * @param window nullable
 * @return
 */
int32_t FlutterPluginJava::set_preview_window(
	const int32_t &device_id,
	const int64_t &tex_id,
	ANativeWindow *window) {

	ENTER();

	LOGV("id=%d,tex_id=%" FMT_INT64_T ",window=%p", device_id, tex_id, window);
	int result = -1;
	FlutterUVCHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uvc_holder_locked(device_id, false);
		m_lock.unlock();
	}
	if (holder) {
		result = holder->set_preview_surface(window);
	}


	RETURN(result, int32_t);
}

/**
 * コントロール機能でサポートしている機能を取得
 * @param device_id
 * @return
 */
/*public*/
uint64_t FlutterPluginJava::get_ctrl_supports(const int &device_id) {
	ENTER();

	if (LIKELY(device_id)) {
		FlutterUVCHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uvc_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			return holder->get_ctrl_supports();
		} else {
			LOGD("FlutterUVCHolder not found! id=%d", device_id);
		}
	}

	RETURN(0, uint64_t);
}

/**
 * プロセッシングユニットでサポートしている機能を取得
 * @param device_id
 * @return
 */
/*public*/
uint64_t FlutterPluginJava::get_proc_supports(const int &device_id) {
	ENTER();

	if (LIKELY(device_id)) {
		FlutterUVCHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uvc_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			return holder->get_proc_supports();
		} else {
			LOGD("FlutterUVCHolder not found! id=%d", device_id);
		}
	}

	RETURN(0, uint64_t);
}

/**
 * native側でUVC設定機能へアクセスするときのヘルパー関数
 * @param device_id
 * @param info
 * @return 0: 成功, 負: エラーコード
 */
/*public*/
int FlutterPluginJava::get_control_info(const int &device_id, uvc_control_info_t &info) {
	ENTER();

	int result = -5;
	if (LIKELY(device_id)) {
		FlutterUVCHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uvc_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			result = holder->get_control_info(info);
		} else {
			LOGD("FlutterUVCHolder not found! id=%d", device_id);
		}
	}

	RETURN(result, int);
}

/**
 * native側でUVC設定機能へアクセスするときのヘルパー関数
 * @param device_id
 * @param type
 * @param value
 * @return 0: 成功, 負: エラーコード
 */
/*public*/
int FlutterPluginJava::set_control_value(const int &device_id, const uint64_t &type, const int32_t &value) {
	ENTER();

	int result = -5;
	if (LIKELY(device_id)) {
		FlutterUVCHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uvc_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			result = holder->set_control_value(type, value);
		} else {
			LOGD("FlutterUVCHolder not found! id=%d", device_id);
		}
	}

	RETURN(result, int);
}

/**
 * native側でUVC設定機能へアクセスするときのヘルパー関数
 * @param device_id
 * @param type
 * @param value
 * @return 0: 成功, 負: エラーコード
 */
/*public*/
int FlutterPluginJava::get_control_value(const int &device_id, const uint64_t &type, int32_t &value) {
	ENTER();

	int result = -5;
	if (LIKELY(device_id)) {
		FlutterUVCHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uvc_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			result = holder->get_control_value(type, value);
		} else {
			LOGD("FlutterUVCHolder not found! id=%d", device_id);
		}
	}

	RETURN(result, int);
}

/**
 * native側でUVC映像サイズ設定へアクセスするときのヘルパー関数
 * @param device_id
 * @param index 映像サイズ設定のインデックス
 * @param num_supported 対応している映像サイズ設定の数を入れるuint32_tへのポインタ
 * @param data 映像サイズ設定を書き込むためのflutter_video_size_t構造体へのポインタ
 * @return 0: 成功, 負: エラーコード
 */
int FlutterPluginJava::get_supported_size(
	const int &device_id,
	const int32_t &index, int32_t *num_supported,
	uvc_video_size_t *data) {

	ENTER();

	int result = -5;
	FlutterUVCHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uvc_holder_locked(device_id, false);
		m_lock.unlock();
	}
	if (holder) {
		result = holder->get_supported_size(index, num_supported, data);
	} else {
		LOGD("FlutterUVCHolder not found! id=%d", device_id);
	}

	RETURN(result, int);
}

//--------------------------------------------------------------------------------
/**
 * UAC機器との接続状態を取得する
 * @param device_id
 * @return
 */
device_state_t FlutterPluginJava::get_uac_state(const int32_t &device_id) {
	ENTER();

	device_state result = DISCONNECTED;
	FlutterUACHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uac_holder_locked(device_id, false);
		m_lock.unlock();
	}
	result = holder && holder->is_running() ? STREAMING : CONNECTED;

	RETURN(result, device_state);
}

/**
 * 音声取得開始
 * @param device_id UAC機器識別用のID
 * @param send_port
 * @return
 */
/*public*/
int FlutterPluginJava::start_uac(const int32_t &device_id, const int64_t &send_port) {
	ENTER();

	int result = -1;
	FlutterUACHolderSp holder = nullptr;
	if (m_lock.try_lock()) {
		holder = get_uac_holder_locked(device_id, false);
		m_lock.unlock();
	}
	if (holder && !holder->is_running()) {
		// まだ音声取得開始していないとき
		result = holder->start(send_port);
	}

	RETURN(result, int);
}

/**
 * 音声取得終了
 * @param device_id UAC機器識別用のID
 * @return
 */
/*public*/
int FlutterPluginJava::stop_uac(const int32_t &device_id) {
	ENTER();

	if (LIKELY(device_id)) {
		FlutterUACHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uac_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			holder->stop();
		}
	}

	RETURN(0, int);
}

/**
 * Flutterへ引き渡す形式の音声取得設定を取得
 * @param device_id UAC機器識別用のID
 * @param info
 * @return
 */
/*public*/
int FlutterPluginJava::get_uac_info(const int32_t &device_id, uac_info_t &info) {
	ENTER();

	int result = -4;
	if (LIKELY(device_id)) {
		FlutterUACHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uac_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			result = holder->get_uac_info(info);
		} else {
			LOGD("FlutterUACHolder not found! id=%d", device_id);
		}
	}

	RETURN(result, int);
}

/**
 * 音声フレームをフレームキューから読み取る
 * @param device_id UAC機器識別用のID
 * @param data nullptrなら*lenにフレームデータのバイト数をセットするだけで実際の読み取りは行わない
 * @param data_len 音声フレームのバイト数
 * @param pts_us 音声データ受信時のシステムタイム[マイクロ秒]
 * @return
 */
/*public*/
int FlutterPluginJava::get_uac_frame(const int32_t &device_id, uint8_t *data, uint32_t *data_len, int64_t *pts_us) {
//	ENTER();

	int result = -4;
	if (LIKELY(device_id)) {
		FlutterUACHolderSp holder = nullptr;
		if (m_lock.try_lock()) {
			holder = get_uac_holder_locked(device_id, false);
			m_lock.unlock();
		}
		if (holder) {
			result = holder->get_uac_frame(data, data_len, pts_us);
		} else {
			LOGD("FlutterUACHolder not found! id=%d", device_id);
		}
	}

	return result; // RETURN(result, int);
}

/**
 * USB機器が接続されたときのコールバック関数
 * @param callback_args FlutterPluginJavaへのポインタ
 * @param device_id
 */
/*private,static*/
void FlutterPluginJava::on_device_attach(usb_manager_t*, void *callback_args, int32_t device_id) {
	ENTER();

	auto plugin = reinterpret_cast<FlutterPluginJava *>(callback_args);
	if (plugin) {
		plugin->add(device_id);
	}

	EXIT();
}

/**
 * USB機器が取り外されたときのコールバック関数
 * @param callback_args FlutterPluginJavaへのポインタ
 * @param device_id
 */
/*static, private*/
void FlutterPluginJava::on_device_detach(usb_manager_t*, void *callback_args, int32_t device_id) {
	ENTER();

	auto plugin = reinterpret_cast<FlutterPluginJava *>(callback_args);
	if (plugin) {
		plugin->remove(device_id);
	}

	EXIT();
}

}	// namespace serenegiant::flutter
