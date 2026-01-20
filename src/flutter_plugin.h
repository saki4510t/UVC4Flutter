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

/**
 * フレームインターバル/フレームレートの最大数
 * とりあえず128に制限
 */
#define MAX_NUM_INTERVALS (128)

/**
 * UVC機器との接続状態
 * should match to device_state_t in aandusb_native.h
 */
typedef enum device_state {
	/**
	 * プラグインが初期化されていない
	 */
	UNINITIALIZED = -1,
	/**
	 * 指定した機器が接続されていない
	 */
	DISCONNECTED = 0,
	/**
	 * 指定した機器が接続されている(映像取得中ではない)
	 */
	CONNECTED = 1,
	/**
	 * 指定した機器が接続されており映像取得中
	 */
	STREAMING = 2,
} device_state_t;

// Camera Terminal DescriptorのbmControlsフィールドのビットマスク
#define	FLG_CTRL_SCANNING		(0x00000001)	// D0:  Scanning Mode
#define	FLG_CTRL_AE				(0x00000002)	// D1:  Auto-Exposure Mode
#define	FLG_CTRL_AE_PRIORITY	(0x00000004)	// D2:  Auto-Exposure Priority
#define	FLG_CTRL_AE_ABS			(0x00000008)	// D3:  Exposure Time (Absolute)
#define FLG_CTRL_FOCUS_ABS    	(0x00000020)	// D5:  Focus (Absolute)
#define FLG_CTRL_IRIS_ABS		(0x00000080)	// D7:  Iris (Absolute)
#define	FLG_CTRL_ZOOM_ABS		(0x00000200)	// D9:  Zoom (Absolute)
#define	FLG_CTRL_PAN_ABS		(0x01000800)	// D11: PanTilt (Absolute)
#define	FLG_CTRL_TILT_ABS		(0x02000800)	// D11: PanTilt (Absolute)
#define FLG_CTRL_ROLL_ABS		(0x00002000)	// D13: Roll (Absolute)
#define FLG_CTRL_FOCUS_AUTO		(0x00020000)	// D17: Focus, Auto
#define FLG_CTRL_PRIVACY		(0x00040000)	// D18: Privacy

// Processing Unit DescriptorのbmControlsフィールドのビットマスク
#define FLG_PU_BRIGHTNESS		(0x80000001)	// D0: Brightness
#define FLG_PU_CONTRAST			(0x80000002)	// D1: Contrast
#define FLG_PU_HUE				(0x80000004)	// D2: Hue
#define	FLG_PU_SATURATION		(0x80000008)	// D3: Saturation
#define FLG_PU_SHARPNESS		(0x80000010)	// D4: Sharpness
#define FLG_PU_GAMMA			(0x80000020)	// D5: Gamma
#define	FLG_PU_WB_TEMP			(0x80000040)	// D6: White Balance Temperature
#define	FLG_PU_WB_COMPO			(0x80000080)	// D7: White Balance Component
#define	FLG_PU_BACKLIGHT		(0x80000100)	// D8: Backlight Compensation
#define FLG_PU_GAIN				(0x80000200)	// D9: Gain
#define FLG_PU_POWER_LF			(0x80000400)	// D10: Power Line Frequency
#define FLG_PU_HUE_AUTO			(0x80000800)	// D11: Hue, Auto
#define FLG_PU_WB_TEMP_AUTO		(0x80001000)	// D12: White Balance Temperature, Auto
#define FLG_PU_WB_COMPO_AUTO	(0x80002000)	// D13: White Balance Component, Auto
#define FLG_PU_CONTRAST_AUTO	(0x80040000)	// D18: Contrast, Auto

#define FLG_PU_MASK				(0x80000000)

/** 不明なフレームフォーマット, 0x000000 */
#define FRAME_TYPE_UNKNOWN              (0x00000000),
/** 0x010005, YUY2/YUYV/V422/YUV422, インターリーブ */
#define FRAME_TYPE_UNCOMPRESSED_YUYV    (0x00010005),
/** 0x050005, YVU420 SemiPlanar(y->vu), YVU420sp */
#define FRAME_TYPE_UNCOMPRESSED_NV21    (0x00050005),
/** 0x0b0005, YUV420 SemiPlanar(y->uv) NV21とU/Vが逆 */
#define FRAME_TYPE_UNCOMPRESSED_NV12    (0x000b0005),
/** 0x0d0005, 8ビットインターリーブRGB(16ビット/5+6+5カラー) */
#define FRAME_TYPE_UNCOMPRESSED_RGB565  (0x000d0005),
/** 0x100005, 8ビットインターリーブRGBX(32ビットカラー), RGBX32 */
#define FRAME_TYPE_UNCOMPRESSED_RGBX    (0x00100005),
/** mjpeg */
#define FRAME_TYPE_MJPEG                (0x00000007),
/** H.264単独フレーム */
#define FRAME_TYPE_H264                 (0x00000014),

/**
 * Flutterのc#側とUVCコントロール機能の設定値等をやりとりするための構造体定義
 * Flutterのc#側にも同じ構造体を定義する必要がある
 * should match to uvc_control_info_t in aandusb_native.h
 */
typedef struct flutter_control_info {
	uint64_t type;			// UVCコントロールの種類(CTRL_XXXまたはPU_XXX)
	int32_t initialized;	// 初期化済みかどうか
	int32_t has_min_max;	// 最大最小値を持つかどうか
	int32_t def;			// デフォルト値
	int32_t current;		// 現在値
	int32_t res;			// 分解能
	int32_t min;			// 最小値
	int32_t max;			// 最大値
} __attribute__((__packed__)) flutter_control_info_t;

/**
 * Flutterのc#側と映像サイズ設定をやりとりするための構造体定義
 * Flutterのc#側にも同じ構造体を定義する必要がある
 * should match to uvc_video_size_t in aandusb_native.h
 */
typedef struct flutter_video_size {
	uint32_t frame_type;
	/**
	 * フレームインデックス
	 */
	int32_t frame_index;
	/**
	 * 映像幅[ピクセル数]
	 */
	uint32_t width;
	/**
	 * 映像高さ[ピクセル数]
	 */
	uint32_t height;
	/**
	 * フレームレートのタイプ
	 * 0: min/max/stepの3つのuint32_tで指定
	 * 正数: フレームインターバルデータの個数
	 */
	int32_t frame_interval_type;
	/**
	 * フレームインターバルデータ
	 */
	uint32_t frame_intervals[MAX_NUM_INTERVALS];
	/**
	 * フレームインターバルデータの個数
	 */
	int32_t num_frame_intervals;
	/**
	 * フレームレート
	 */
	float fps[MAX_NUM_INTERVALS];
	/**
	 * フレームレートの個数
	 */
	int32_t num_fps;
} __attribute__((__packed__)) flutter_video_size_t;

/**
 * 接続しているUSB機器情報
 * should match to usb_device_info_t in aandusb_native.h
 */
typedef struct flutter_device_info {
	uint32_t vendor_id;
	uint32_t product_id;
	uint8_t device_class;
	uint8_t device_subclass;
	uint8_t device_protocol;
	uint8_t reserved1;
	uint8_t name[128];
	uint8_t manufacturer_name[128];
	uint8_t product_name[128];
	uint8_t serial[128];
} __attribute__((__packed__)) flutter_device_info_t;

/**
 * UAC情報
 * should match to uac_info_t in aandusb_native.h
 */
typedef struct flutter_uac_info {
	int32_t device_id;
	int32_t channels;
	int32_t resolution;
	uint32_t sampling_freq;
	int32_t packet_bytes;
} __attribute__((__packed__)) flutter_uac_info_t;

//--------------------------------------------------------------------------------
// DartのFlutterプラグイン部分から呼ばれる関数

EXTERN_C
int64_t initialize_dart_api(void *data);

EXTERN_C
void set_dart_api_message_port(int64_t port);

EXTERN_C
int32_t get_state(int32_t device_id);

EXTERN_C
int32_t  get_device_info(int32_t device_id, flutter_device_info_t *info_out);

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
	flutter_video_size_t *data);

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
int32_t get_ctrl_info(int32_t device_id, flutter_control_info_t *value);

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
	int32_t index, int32_t *num_supported, flutter_video_size_t *data);

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
 * XXX start_uacを呼んだ後でないと正しい値が返らないので注意
 * @param device_id
 * @param value
 * @return
 */
EXTERN_C
int32_t get_uac_info(int32_t device_id, flutter_uac_info_t *value);

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
