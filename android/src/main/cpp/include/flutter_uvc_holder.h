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

#ifndef AANDUSB_FLUTTER_UVC_HOLDER_H
#define AANDUSB_FLUTTER_UVC_HOLDER_H

// 標準ライブラリ
#include <memory>
#include <vector>
// android
#include <android/native_window.h>
// aandusb-native
#include "aandusb_native.h"
// flutter
#include "flutter_utils.h"

namespace serenegiant::flutter {

#define DEFAULT_WIDTH (640)
#define DEFAULT_HEIGHT (480)

class FlutterUVCHolder {
private:
	const int32_t m_device_id;
	usb_manager_t *m_manager;
	uvc_video_size_t m_current_size;
	std::vector<const uvc_video_size_t> m_supported_size;
	std::vector<uint64_t> m_supported_ctrls;
	/**
	 * 対応しているUVC設定機能一覧を更新する
	 */
	void update_supported_ctrls();
protected:
public:
	/**
	 * コンストラクタ
	 * @param manager
	 * @param device_id
	 * @param frame_type
	 * @param width
	 * @param height
	 */
	explicit FlutterUVCHolder(
		usb_manager_t *manager, const int32_t &device_id,
		const uvc_raw_frame_t &frame_type = RAW_FRAME_MJPEG,
		const uint32_t &width = DEFAULT_WIDTH,
		const uint32_t &height = DEFAULT_HEIGHT);
	/**
	 * デストラクタ
	 */
	virtual ~FlutterUVCHolder() noexcept;

	/**
	 * 対応解像度一覧を取得
	 * @return
	 */
	[[nodiscard]]
	inline const std::vector<const uvc_video_size_t> &supported_size() const { return m_supported_size; };

	/**
	 * 対応しているUVC設定機能一覧を取得する
	 * @return
	 */
	[[nodiscard]]
	inline const std::vector<uint64_t> &supported_ctrls() const { return m_supported_ctrls; };

	[[nodiscard]]
	inline uvc_raw_frame_t frame_type() const { return (uvc_raw_frame_t)m_current_size.frame_type; };

	[[nodiscard]]
	inline uint32_t width() const { return m_current_size.width; };

	[[nodiscard]]
	inline uint32_t height() const { return m_current_size.height; };

	[[nodiscard]]
	bool is_running() const;

	int set_config(const int32_t &enabled, const bool &use_first_config);

	/**
	 * コントロールユニットの対応機能フラグを取得
	 * @return
	 */
	uint64_t get_ctrl_supports();

	/**
	 * プロセッシングユニットの対応機能フラグを取得
	 * @return
	 */
	uint64_t get_proc_supports();

	/**
	 * UVC設定機能の情報を取得
	 * @param info
	 * @return 0: 成功, 負: エラーコード
	 */
	int get_control_info(uvc_control_info_t &info) const;

	/**
	 * UVC設定機能へ値を適用
	 * @param type
	 * @param value
	 * @return 0: 成功, 負: エラーコード
	 */
	[[nodiscard]]
	int set_control_value(const uint64_t &type, const int32_t &value) const;

	/**
	 * UVC設定機能の現在の値を取得
	 * @param type
	 * @param value
	 * @return 0: 成功, 負: エラーコード
	 */
	int get_control_value(const uint64_t &type, int32_t &value) const;

	/**
	 * UVC機器からの映像を受け取るためのSurface(ANativeWindow*)をセット
	 * @param preview_window
	 * @param mvp_matrix モデルビュー変換行列、要素数16以上, nullptrなら単位行列をセットする
	 * @return
	 */
	int set_preview_surface(ANativeWindow *preview_window, const float *mvp_matrix = nullptr);

	/**
	 * モデルビュー変換行列を設定
	 * Surface(ANativeWindow)で映像を受け取るときのみ有効
	 * @param mvp_matrix モデルビュー変換行列、要素数16以上, nullptrなら単位行列をセットする
	 * @return
	 */
	int set_mvp_matrix(const float *mvp_matrix);

	/**
	 * 映像設定
	 * @param frame_type
	 * @param width
	 * @param height
	 * @return
	 */
	int set_video_size(
		const uvc_raw_frame_t &frame_type,
		const uint32_t &width, const uint32_t  &height);

	/**
	 * 現在の映像設定を取得
	 * @return
	 */
	const uvc_video_size_t &get_current_size();

	/**
	 * 対応解像度を取得
	 * @param index
	 * @param num_supported
	 * @param data
	 * @return
	 */
	int get_supported_size(
		const int32_t &index, int32_t *num_supported,
		uvc_video_size_t *data) const;

	/**
	 * 映像取得開始
	 * @return
	 */
	int start();

	/**
	 * 映像至徳終了
	 * @return
	 */
	int stop();

};

using FlutterUVCHolderSp = std::shared_ptr<FlutterUVCHolder>;
using FlutterUVCHolderUp = std::unique_ptr<FlutterUVCHolder>;

} // namespace serenegiant::flutter
#endif //AANDUSB_FLUTTER_UVC_HOLDER_H
