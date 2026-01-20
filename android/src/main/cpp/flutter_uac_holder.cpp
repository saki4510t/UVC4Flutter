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

#define LOG_TAG "FlutterUACHolder"

#if 1	// デバッグ情報を出さない時は1
	#ifndef LOG_NDEBUG
		#define	LOG_NDEBUG		// LOGV/LOGD/MARKを出力しない時
	#endif
	#undef USE_LOGALL			// 指定したLOGxだけを出力
#else
//	#define USE_LOGALL
	#undef LOG_NDEBUG
	#undef NDEBUG
#endif

// aandusb
#include "utilbase.h"
// dart
#include "dartAPIDL/dart_api_dl.h"
#include "dartAPIDL/dart_native_api.h"
// Flutter plugin
#include "flutter_uac_holder.h"

namespace serenegiant::flutter {

/**
 * コンストラクタ
 */
/*public*/
FlutterUACHolder::FlutterUACHolder(usb_manager_t *manager, const int32_t &device_id)
:	m_manager(manager),
	m_device_id(device_id),
	m_send_port(0)
{
	ENTER();
	EXIT();
}

/**
 * デストラクタ
 */
/*public*/
FlutterUACHolder::~FlutterUACHolder() noexcept {
	ENTER();

	uac_stop(m_manager, m_device_id);

	EXIT();
}

/**
 * 音声取得中かどうかを取得
 * @return
 */
bool FlutterUACHolder::is_running() const {
	ENTER();

	const auto state = uac_get_device_state(m_manager, m_device_id);

	RETURN(state > CONNECTED , bool);
}

/**
 * 音声取得開始
 * @param send_port
 * @return
 */
int FlutterUACHolder::start(const int64_t &send_port) {
	ENTER();

	m_send_port = send_port;
	auto callback = send_port != 0 ? on_uac_data_func : nullptr;

	RETURN(uac_start_callback(m_manager, m_device_id, callback, this), int);
}

/**
 * 音声取得終了
 * @return
 */
int FlutterUACHolder::stop() {
	ENTER();
	RETURN(uac_stop(m_manager, m_device_id), int);
}

/**
 * 音声フレームをフレームキューから読み取る
 * @param data nullptrなら*lenにフレームデータのバイト数をセットするだけで実際の読み取りは行わない
 * @param data_len 音声フレームのバイト数
 * @param pts_us 音声データ受信時のシステムタイム[マイクロ秒]
 * @return
 */
int FlutterUACHolder::get_uac_frame(uint8_t *data, uint32_t *data_len, int64_t *pts_us) {
//	ENTER();
	return uac_get_frame(m_manager, m_device_id, data, data_len, pts_us);
// RETURN(uac_get_frame(m_manager, m_device_id, data, &data_len, &pts_us), int);
}

/**
 * Unityへ引き渡す形式の音声取得設定を取得
 * @param info
 * @return
 */
/*public*/
int FlutterUACHolder::get_uac_info(uac_info_t &info) {
	ENTER();
	RETURN(uac_get_info(m_manager, m_device_id, &info), int);
}

/*private,static*/
void FlutterUACHolder::on_uac_data_func(
	usb_manager_t *manager, int32_t device_id,
	void *callback_args,
	uint8_t *data, uint32_t data_len, int64_t pts_us) {

	auto holder = reinterpret_cast<FlutterUACHolder *>(callback_args);
	if (holder) {
		holder->on_uac_data(manager, device_id, data, data_len, pts_us);
	}
}

/*private*/
void FlutterUACHolder::on_uac_data(
	const usb_manager_t *manager, const int32_t &device_id,
	const uint8_t *data, const uint32_t &data_len, const int64_t &pts_us) {
//	ENTER();

	const auto send_port = m_send_port;

#if !defined(LOG_NDEBUG)
	static uint32_t cnt = 0;
		static uint32_t total_bytes = 0;
		total_bytes += data_len;
		if ((++cnt % 1500) == 0) {
			LOGI("audio data received,%u bytes,total=%u,send_port=%" FMT_INT64_T, data_len, total_bytes, send_port);
		}
#endif

	if (LIKELY((m_manager == manager) && (m_device_id == device_id) && (send_port != 0))) {
		//
		Dart_CObject data_obj = {
			.type = Dart_CObject_kTypedData,
			.value {
				.as_typed_data {
					.type = Dart_TypedData_kUint8,
					.length = (intptr_t)data_len,
					.values = data,
				}
			}
		};

		Dart_PostCObject_DL(send_port, &data_obj);
	}

//	EXIT();
}

} // serenegiant::unity