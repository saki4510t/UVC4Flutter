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

import 'package:permission_handler/permission_handler.dart';

/// 元々はカメラパーミッションしか要求していなかったので名前がCameraPermissionsHandlerだけど
/// 今はカメラパーミッションと音声取得パーミッションの２つを要求する
class CameraPermissionsHandler {
  // シングルトンパターンでアクセスできるようにする
  static final CameraPermissionsHandler _instance = CameraPermissionsHandler._internal();
  // ファクトリーコンストラクタ
  factory CameraPermissionsHandler() => _instance;

  // 内部使用のコンストラクタ
  CameraPermissionsHandler._internal();

  Future<bool> get isGranted async {
    final micStatus = await Permission.microphone.status;
    final cameraStatus = await Permission.camera.status;
    return (micStatus == PermissionStatus.granted || micStatus == PermissionStatus.limited)
        && (cameraStatus == PermissionStatus.granted || cameraStatus == PermissionStatus.limited);
  }

  Future<Map<Permission, PermissionStatus>> request() {
    return [
      Permission.camera,
      Permission.microphone,
    ].request();
  }
}
