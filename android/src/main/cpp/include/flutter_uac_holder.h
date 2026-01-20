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

#ifndef AANDUSB_FLUTTER_UAC_HOLDER_H_
#define AANDUSB_FLUTTER_UAC_HOLDER_H_

// 標準ライブラリ
#include <memory>
// aandusb-native
#include "aandusb_native.h"

namespace serenegiant::flutter {

class FlutterUACHolder {
private:
	const int32_t m_device_id;
	usb_manager_t *m_manager;
	int64_t m_send_port;

	static void on_uac_data_func(
		usb_manager_t *manager, int32_t device_id,
		void *callback_args,
		uint8_t *data, uint32_t data_len, int64_t pts_us);
	void on_uac_data(
		const usb_manager_t *manager, const int32_t &device_id,
		const uint8_t *data, const uint32_t &data_len, const int64_t &pts_us);
protected:
public:
	/**
	 * コンストラクタ
	 */
	explicit FlutterUACHolder(usb_manager_t *manager, const int32_t &device_id);
	/**
	 * デストラクタ
	 */
	virtual ~FlutterUACHolder() noexcept;

	/**
	 * 音声取得中かどうかを取得
	 * @return
	 */
	[[nodiscard]]
	bool is_running() const;

	/**
	 * 音声取得開始
	 * @param send_port
	 * @return
	 */
	int start(const int64_t &send_port);
	/**
	 * 音声取得終了
	 * @return
	 */
	int stop();

	/**
	 * 音声フレームをフレームキューから読み取る
	 * @param data nullptrなら*lenにフレームデータのバイト数をセットするだけで実際の読み取りは行わない
	 * @param data_len 音声フレームのバイト数
	 * @param pts_us 音声データ受信時のシステムタイム[マイクロ秒]
	 * @return
	 */
	int get_uac_frame(uint8_t *data, uint32_t *data_len, int64_t *pts_us);

	/**
	 * Flutterへ引き渡す形式の音声取得設定を取得
	 * @param info
	 * @return
	 */
	int get_uac_info(uac_info_t &info);
};

using FlutterUACHolderSp = std::shared_ptr<FlutterUACHolder>;
using FlutterUACHolderUp = std::unique_ptr<FlutterUACHolder>;

} // serenegiant::flutter

#endif //AANDUSB_FLUTTER_UAC_HOLDER_H_
