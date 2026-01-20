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

#ifndef AANDUSB_FLUTTER_PLUGIN_JAVA_H
#define AANDUSB_FLUTTER_PLUGIN_JAVA_H

// 標準ライブラリ
#include <mutex>
#include <memory>
#include <unordered_map>
#include <jni.h>

//--------------------------------------------------------------------------------
// 外部クラスの前方宣言
namespace serenegiant::flutter {
class FlutterUACHolder;
class FlutterUVCHolder;
}
// 外部クラスの前方宣言ここまで
//--------------------------------------------------------------------------------

namespace serenegiant::flutter {

/**
 * Flutter用のUVCプラグインのJava側インスタンスへアクセスするためのヘルパークラス
 */
class FlutterPluginJava {
private:
	mutable std::mutex m_lock;
	jobject plugin_java;
	usb_manager_t *m_manager;
	/**
	 * UVC機器のidとUVCHolderSpのペアを保持
	 */
	std::unordered_map <int32_t, std::shared_ptr<FlutterUACHolder>> uac_holders;
	/**
	 * UVC機器のidとUVCHolderSpのペアを保持
	 */
	std::unordered_map <int32_t, std::shared_ptr<FlutterUVCHolder>> uvc_holders;

	/**
	 * 使用中のＵＶＣ機器があれば終了させる
	 */
	void terminate_all();
	/**
	 * 指定したidに対応するUACHolderSpを取得する
	 * 存在していない場合にcreate_if_absent=trueならUACHolderSpを生成する
	 * @param device_id
	 * @param create_if_absent
	 * @return
	 */
	std::shared_ptr<FlutterUACHolder> get_uac_holder_locked(const int32_t &device_id, const bool &create_if_absent);
	/**
	 * 指定したidに対応するUVCHolderSpを取得する
	 * 存在していない場合にcreate_if_absent=trueならUVCHolderSpを生成する
	 * @param device_id
	 * @param create_if_absent
	 * @return
	 */
	std::shared_ptr<FlutterUVCHolder> get_uvc_holder_locked(const int32_t &device_id, const bool &create_if_absent);
	/**
	 * UVC機器が接続された時の処理
	 * @param device_id
	 */
	int add(const int32_t &device_id);
	/**
	 * UVC機器が取り外されたときの処理
	 * @param device_id
	 */
	void remove(const int32_t &device_id);
	/**
	 * USB機器が接続されたときのコールバック関数
	 * @param callback_args UVCMainへのポインタ
	 * @param device_id
	 */
	static void on_device_attach(usb_manager_t*, void *callback_args, int32_t device_id);
	/**
	 * USB機器が取り外されたときのコールバック関数
	 * @param callback_args UVCMainへのポインタ
	 * @param device_id
	 */
	static void on_device_detach(usb_manager_t*, void *callback_args, int32_t device_id);
protected:
public:
	/**
	 * コンストラクタ
	 */
	explicit FlutterPluginJava(jobject plugin_java);
	/**
	 * デストラクタ
	 */
	~FlutterPluginJava() noexcept;

	/**
	 * 指定したIDに対応するUVC機器が接続されていて利用可能かどうか
	 * @param device_id
	 * @return
	 */
	bool is_available(const int32_t &device_id);
	/**
	 * UVC機器との接続状態を取得する
	 * @param device_id
	 * @return
	 */
	device_state_t get_device_state(const int32_t &device_id);
	/**
	 * 接続機器情報を取得する
	 * @param device_id
	 * @return
	 */
	usb_device_info_t get_device_info(const int32_t &device_id);
	/**
	 * 映像取得開始
	 * レンダーコールバックを呼び出さないと実際には描画されない
	 * @param device_id
	 * @return
	 */
	int32_t start(const int32_t &device_id);
	/**
	 * 映像取得終了
	 * @param device_id
	 * @return
	 */
	int32_t stop(const int32_t &device_id);
	/**
	 * UVC機器からの映像サイズの変更要求
	 * @param device_id
	 * @param frame_type
	 * @param width
	 * @param height
	 * @return
	 */
	int32_t set_video_size(const int32_t &device_id,
		const uvc_raw_frame_t &frame_type,
		const uint32_t &width, const uint32_t &height);
	/**
	 * 現在の映像サイズ設定を取得
	 * @param device_id
	 * @param data 映像サイズ設定を書き込むためのflutter_video_size_t構造体へのポインタ
	 * @return 0: 成功, 負: エラーコード
	 */
	int get_current_size(const int &device_id, uvc_video_size_t *data);
	/**
	 * 映像取得用のSurfaceをセットする
	 * @param device_id
	 * @param tex_id
	 * @param window nullable
	 * @return
	 */
	int32_t set_preview_window(const int32_t &device_id,
		const int64_t &tex_id,
		ANativeWindow *window);

	/**
	 * コントロール機能でサポートしている機能を取得
	 * @param device_id
	 * @return
	 */
	uint64_t get_ctrl_supports(const int &device_id);

	/**
	 * プロセッシングユニットでサポートしている機能を取得
	 * @param device_id
	 * @return
	 */
	uint64_t get_proc_supports(const int &device_id);
	/**
	 * native側でUVC設定機能へアクセスするときのヘルパー関数
	 * @param device_id
	 * @param info
	 * @return 0: 成功, 負: エラーコード
	 */
	int get_control_info(const int &device_id, uvc_control_info_t &info);
	/**
	 * native側でUVC設定機能へアクセスするときのヘルパー関数
	 * @param device_id
	 * @param type
	 * @param value
	 * @return 0: 成功, 負: エラーコード
	 */
	int set_control_value(const int &device_id, const uint64_t &type, const int32_t &value);
	/**
	 * native側でUVC設定機能へアクセスするときのヘルパー関数
	 * @param device_id
	 * @param type
	 * @param value
	 * @return 0: 成功, 負: エラーコード
	 */
	int get_control_value(const int &device_id, const uint64_t &type, int32_t &value);
	/**
	 * native側でUVC映像サイズ設定へアクセスするときのヘルパー関数
	 * @param device_id
	 * @param index 映像サイズ設定のインデックス
	 * @param num_supported 対応している映像サイズ設定の数を入れるuint32_tへのポインタ
	 * @param data 映像サイズ設定を書き込むためのflutter_video_size_t構造体へのポインタ
	 * @return 0: 成功, 負: エラーコード
	 */
	int get_supported_size(const int &device_id, const int32_t &index, int32_t *num_supported, uvc_video_size_t *data);
	//--------------------------------------------------------------------------------
	/**
	 * UAC機器との接続状態を取得する
	 * @param device_id
	 * @return
	 */
	device_state_t get_uac_state(const int32_t &device_id);
	/**
	 * 音声取得開始
	 * レンダーコールバックを呼び出さないと実際には描画されない
	 * @param device_id UVC機器識別用のID
	 * @param send_port
	 * @return
	 */
	int start_uac(const int32_t &device_id, const int64_t &send_port);
	/**
	 * 音声取得終了
	 * @param device_id UVC機器識別用のID
	 * @return
	 */
	int stop_uac(const int32_t &device_id);
	/**
	 * Flutterへ引き渡す形式の音声取得設定を取得
	 * @param device_id UVC機器識別用のID
	 * @param info
	 * @return
	 */
	int get_uac_info(const int32_t &device_id, uac_info_t &info);
	/**
	 * 音声フレームをフレームキューから読み取る
	 * @param device_id UVC機器識別用のID
	 * @param data nullptrなら*lenにフレームデータのバイト数をセットするだけで実際の読み取りは行わない
	 * @param data_len 音声フレームのバイト数
	 * @param pts_us 音声データ受信時のシステムタイム[マイクロ秒]
	 * @return
	 */
	int get_uac_frame(const int32_t &device_id, uint8_t *data, uint32_t *data_len, int64_t *pts_us);
};

using FlutterPluginJavaSp = std::shared_ptr<FlutterPluginJava>;
using FlutterPluginJavaUp = std::unique_ptr<FlutterPluginJava>;

}	// namespace serenegiant::flutter

#endif //AANDUSB_FLUTTER_PLUGIN_JAVA_H
