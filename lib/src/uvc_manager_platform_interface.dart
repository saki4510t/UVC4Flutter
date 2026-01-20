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

import 'dart:ui';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uvc_manager/uvc_manager.dart';

abstract class UVCControllerInterface {
  int get deviceId => throw UnimplementedError('deviceId has not been implemented.');

  /// UVC機器が取り外された時の処理
  Future<void> detached() async {
    throw UnimplementedError('detached() has not been implemented.');
  }

  device_state state() {
    throw UnimplementedError('state() has not been implemented.');
  }

  /// UVC機器からの映像取得を開始
  Future<int> start() async {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// UVC機器からの映像取得を終了
  Future<int> stop() async {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// 対応する解像度設定一覧を取得
  Future<List<VideoSize>> getSupportedSize() async {
    throw UnimplementedError('getSupportedSize() has not been implemented.');
  }

  /// 対応するUVCコントロール一覧を取得
  Future<List<ControlInfo>> getSupportedControls() async {
    throw UnimplementedError('getSupportedControls() has not been implemented.');
  }

  /// 映像設定を適用
  Future<VideoSize> setSize(int frameType, int width, int height) async {
    throw UnimplementedError('setSize() has not been implemented.');
  }

  /// 現在の映像設定を取得
  Future<VideoSize> getCurrentSize() async {
    throw UnimplementedError('getCurrentSize() has not been implemented.');
  }

  /// 指定したUVCコントロール機能へ設定を適用
  /// 返値のisValidがfalseなら無効
  /// XXX 露出時間設定など現在のUVC機器の設定状態によっては適用できない場合もあるので注意
  /// @param type 設定するUVCコントロール機能の種類
  /// @param value 設定する値
  Future<ControlInfo> setCtrlValue(int type, int value) async {
    throw UnimplementedError('setCtrlValue() has not been implemented.');
  }

  /// 現在のUVCコントロール機能の設定値を取得
  /// 返値のisValidがfalseなら無効
  /// @param type 設定するUVCコントロール機能の種類
  Future<ControlInfo> getCtrlValue(int type) async {
    throw UnimplementedError('getCtrlValue() has not been implemented.');
  }

  /// 機器情報を取得
  DeviceInfo getDeviceInfo() {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  /// 映像取得用のテクスチャを生成する
  Future<int> createTexture(int width, int height) async {
    throw UnimplementedError('createTexture() has not been implemented.');
  }

  /// テクスチャを破棄
  Future<Null> releaseTexture() async {
    throw UnimplementedError('releaseTexture() has not been implemented.');
  }

  /// UACの接続状態を取得
  device_state uacState() {
    throw UnimplementedError('uac_state() has not been implemented.');
  }

  /// UVC機器からの音声取得を開始
  Future<int> startUAC(int sendPort) async {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// UVC機器からの音声取得を終了
  Future<int> stopUAC() async {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// UAC情報を取得
  UACInfo getUACInfo() {
    throw UnimplementedError('getUACInfo() has not been implemented.');
  }
}

abstract class UVCManagerPlatform extends PlatformInterface {
  /// Constructs a UvcManagerPlatform.
  UVCManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static UVCManagerPlatform _instance = UVCManager();

  /// The default instance of [UVCManagerPlatform] to use.
  ///
  /// Defaults to [UVCManager].
  static UVCManagerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UVCManagerPlatform] when
  /// they register themselves.
  static set instance(UVCManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void addListener(VoidCallback listener) {
    throw UnimplementedError('addListener() has not been implemented.');
  }

  void removeListener(VoidCallback listener) {
    throw UnimplementedError('removeListener() has not been implemented.');
  }

  /// 接続されているUVC機器の数
  int getAvailableCount() {
    throw UnimplementedError('getAvailableCount() has not been implemented.');
  }

  /// 接続されているUVC機器一覧を取得する
  List<UVCControllerInterface> getControllers() {
    throw UnimplementedError('getControllers() has not been implemented.');
  }

  /// 接続されているUVC機器の指定した位置に対応するUVCControllerを取得する
  UVCControllerInterface getControllerAt(int index) {
    throw UnimplementedError('getControllerAt() has not been implemented.');
  }

  /// 機器識別IDを指定してUVCControllerを取得する
  UVCControllerInterface getController(int deviceId) {
    throw UnimplementedError('getController() has not been implemented.');
  }

  /// 画面の自動消灯のON/OFF
  Future<Null> keepScreenOn(bool onoff) async {
    throw UnimplementedError('keepScreenOn() has not been implemented.');
  }

}
