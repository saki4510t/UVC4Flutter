// Copyright (c) 2020-2026 saki t_saki@serenegiant.com
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'package:uvc_manager/uvc_manager.dart';

/// UVC機器から取得したUVC機器コントロールの設定値を保持する
class ControlInfo {
  /// UVCコントロールの種類(CTRL_XXXまたはPU_XXX)
  final int type;

  /// 初期化済みかどうか
  final int initialized;

  /// 最大最小値を持つかどうか
  final int hasMinMax;

  /// デフォルト値
  final int def;

  /// 現在値
  int _current;
  int get current => _current;
  set current(int cur) {
    if (isValid()) {
      // 有効なUVCコントロールの場合のみcurrentを変更可能
      _current = cur;
    }
  }

  /// 分解能
  final int res;

  /// 最小値
  final int min;

  /// 最大値
  final int max;

  ControlInfo(this.type, this.initialized, this.hasMinMax, this.def,
      this._current, this.res, this.min, this.max);

  bool isValid() {
    return type != 0;
  }

  @override
  String toString() {
    return 'ControlInfo{type:${typeString(type)}($type), initialized:$initialized, hasMinMax:$hasMinMax, def:$def, current:$current, res:$res, min:$min, max:$max}';
  }

  /// 無効なUVCコントロール
  static final ControlInfo INVALID = ControlInfo(0, 0, 0, 0, 0, 0, 0, 0);

  /// UVCコントロールの種類文字列を取得するヘルパー関数
  /// @param type
  static String typeString(int type) {
    switch(type) {
    case FLG_CTRL_SCANNING: return "CTRL_SCANNING";
    case FLG_CTRL_AE: return "CTRL_AE";
    case FLG_CTRL_AE_PRIORITY: return "CTRL_AE_PRIORITY";
    case FLG_CTRL_AE_ABS: return "CTRL_AE_ABS";
    case FLG_CTRL_FOCUS_ABS: return "CTRL_FOCUS_ABS";
    case FLG_CTRL_IRIS_ABS: return "CTRL_IRIS_ABS";
    case FLG_CTRL_ZOOM_ABS: return "CTRL_ZOOM_ABS";
    case FLG_CTRL_PAN_ABS: return "CTRL_PAN_ABS";
    case FLG_CTRL_TILT_ABS: return "CTRL_TILT_ABS";
    case FLG_CTRL_ROLL_ABS: return "CTRL_ROLL_ABS";
    case FLG_CTRL_FOCUS_AUTO: return "CTRL_FOCUS_AUTO";
    case FLG_CTRL_PRIVACY: return "CTRL_PRIVACY";
    case FLG_PU_BRIGHTNESS: return "PU_BRIGHTNESS";
    case FLG_PU_CONTRAST: return "PU_CONTRAST";
    case FLG_PU_HUE: return "PU_HUE";
    case FLG_PU_SATURATION: return "PU_SATURATION";
    case FLG_PU_SHARPNESS: return "PU_SHARPNESS";
    case FLG_PU_GAMMA: return "PU_GAMMA";
    case FLG_PU_WB_TEMP: return "PU_WB_TEMP";
    case FLG_PU_WB_COMPO: return "PU_WB_COMPO";
    case FLG_PU_BACKLIGHT: return "PU_BACKLIGHT";
    case FLG_PU_GAIN: return "PU_GAIN";
    case FLG_PU_POWER_LF: return "PU_POWER_LF";
    case FLG_PU_HUE_AUTO: return "PU_HUE_AUTO";
    case FLG_PU_WB_TEMP_AUTO: return "PU_WB_TEMP_AUTO";
    case FLG_PU_WB_COMPO_AUTO: return "PU_WB_COMPO_AUTO";
    case FLG_PU_CONTRAST_AUTO: return "PU_CONTRAST_AUTO";
    default: return "UNKNOWN($type)";
    }
  }
}
