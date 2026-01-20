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

#ifndef AANDUSB_FLUTTER_PLUGIN_H
#define AANDUSB_FLUTTER_PLUGIN_H

#ifdef __cplusplus
#include <cstdint>
#if defined(_WIN32)
#define EXTERN_C extern "C" __declspec(dllexport)
#else
#define EXTERN_C extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif
#else
#include <stdint.h>
#define EXTERN_C
#endif

#include "aandusb_native.h"
/**
 * フレームインターバル/フレームレートの最大数
 * 規格上はこれより多い可能性があるけどとりあえず128に制限
 */
#define MAX_INTERVALS (128)

//--------------------------------------------------------------------------------
// DartのFlutterプラグイン部分から呼ばれる関数

EXTERN_C
int64_t initialize_dart_api(void *data);

EXTERN_C
void set_dart_api_message_port(int64_t port);

EXTERN_C
int32_t get_state(int32_t device_id);

EXTERN_C
int32_t  get_device_info(int32_t device_id, usb_device_info_t *info_out);

EXTERN_C
int64_t start(int32_t device_id);

EXTERN_C
int32_t stop(int32_t device_id);

EXTERN_C
int set_video_size(
	int32_t device_id,
	uint32_t type,
	uint32_t width, uint32_t height);

EXTERN_C
int get_current_size(
	int32_t device_id,
	uvc_video_size_t *data);

/**
 * コントロール機能でサポートしている機能を取得
 * @param device_id
 * @return
 */
EXTERN_C
uint64_t get_ctrl_supports(int32_t device_id);

/**
 * プロセッシングユニットでサポートしている機能を取得
 * @param device_id
 * @return
 */
EXTERN_C
uint64_t get_proc_supports(int32_t device_id);

/**
 * 指定した機能の設定情報を取得
 * @param device_id
 * @param value
 * @return
 */
EXTERN_C
int32_t get_ctrl_info(int32_t device_id, uvc_control_info_t *value);

/**
 * 指定した機能の設定値を適用
 * @param device_id
 * @param type
 * @param value
 * @return
 */
EXTERN_C
int32_t set_ctrl_value(int32_t device_id, uint64_t type, int32_t value);

/**
 * 指定した機能の設定値を取得
 * @param device_id
 * @param type
 * @param value
 * @return
 */
EXTERN_C
int32_t get_ctrl_value(int32_t device_id, uint64_t type, int32_t *value);

/**
 * native側でUVC映像サイズ設定へアクセスするときのヘルパー関数
 * 主にUnityやFlutterからのアクセスを想定
 * @param device_id
 * @param index 映像サイズ設定のインデックス
 * @param num_supported 対応している映像サイズ設定の数を入れるuint32_tへのポインタ
 * @param data 映像サイズ設定を書き込むためのunity_video_size_t構造体へのポインタ
 * @return 0: 成功, 負: エラーコード
 */
EXTERN_C
int32_t get_supported_size(
	int32_t device_id,
	int32_t index, int32_t *num_supported, uvc_video_size_t *data);

/**
 * 映像取得用のsurfaceをセットする
 * @param device_id UVC機器の識別子
 * @param tex_id   テクスチャID
 * @param jsurface Java側のSurfaceオブジェクト
 */
EXTERN_C
int32_t set_preview_surface(
	int32_t device_id,	// jint
	int64_t tex_id,		// jlong
	void *jsurface);	// jobject jsurface

/**
 * UAC機器との接続状態を取得する
 * @param device_id
 * @return
 */
EXTERN_C
int32_t get_uac_state(int32_t device_id);

/**
 * 音声取得開始
 * 音声データを受信するたびにRegister時に指定したuac_callbackが呼び出される
 * @param device_id
 * @param send_port
 * @return
 */
EXTERN_C
int32_t start_uac(int32_t device_id, int64_t send_port);

/**
 * 音声取得終了
 * @param device_id
 * @return
 */
EXTERN_C
int32_t stop_uac(int32_t device_id);

/**
 * 指定した機能の設定情報を取得
 * XXX StartUACを呼んだ後でないと正しい値が返らないので注意
 * @param device_id
 * @param value
 * @return
 */
EXTERN_C
int32_t get_uac_info(int32_t device_id, uac_info_t *value);

/**
 * 音声フレームをフレームキューから読み取る
 * @param device_id
 * @param data nullptrなら*lenにフレームデータのバイト数をセットするだけで実際の読み取りは行わない
 * @param data_len 音声フレームのバイト数
 * @param pts_us 音声データ受信時のシステムタイム[マイクロ秒]
 * @return
 */
EXTERN_C
int32_t get_uac_frame(int32_t device_id, uint8_t *data, uint32_t *data_len, int64_t *pts_us);

#endif //AANDUSB_FLUTTER_PLUGIN_H
