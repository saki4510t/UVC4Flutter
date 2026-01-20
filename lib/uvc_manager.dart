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

export './src/uvc_control_info.dart';
export './src/uvc_controller.dart';
export './src/uvc_device_info.dart';
export './src/uvc_video_size.dart';
export './src/uac_info.dart';
export './src/uvc_manager_platform_interface.dart'
  show  UVCManagerPlatform,
        UVCControllerInterface;
export './src/uvcplugin_bindings_generated.dart'
  show  device_state,
        FLG_CTRL_SCANNING,
        FLG_CTRL_AE,
        FLG_CTRL_AE_PRIORITY,
        FLG_CTRL_AE_ABS,
        FLG_CTRL_FOCUS_ABS,
        FLG_CTRL_IRIS_ABS,
        FLG_CTRL_ZOOM_ABS,
        FLG_CTRL_PAN_ABS,
        FLG_CTRL_TILT_ABS,
        FLG_CTRL_ROLL_ABS,
        FLG_CTRL_FOCUS_AUTO,
        FLG_CTRL_PRIVACY,
        FLG_PU_BRIGHTNESS,
        FLG_PU_CONTRAST,
        FLG_PU_HUE,
        FLG_PU_SATURATION,
        FLG_PU_SHARPNESS,
        FLG_PU_GAMMA,
        FLG_PU_WB_TEMP,
        FLG_PU_WB_COMPO,
        FLG_PU_BACKLIGHT,
        FLG_PU_GAIN,
        FLG_PU_POWER_LF,
        FLG_PU_HUE_AUTO,
        FLG_PU_WB_TEMP_AUTO,
        FLG_PU_WB_COMPO_AUTO,
        FLG_PU_CONTRAST_AUTO,
        FRAME_TYPE_UNKNOWN,
        FRAME_TYPE_UNCOMPRESSED_YUYV,
        FRAME_TYPE_UNCOMPRESSED_NV21,
        FRAME_TYPE_UNCOMPRESSED_NV12,
        FRAME_TYPE_UNCOMPRESSED_RGB565,
        FRAME_TYPE_UNCOMPRESSED_RGBX,
        FRAME_TYPE_MJPEG,
        FRAME_TYPE_H264
        ;
