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

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:ffi/ffi.dart' as ffi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

import './uvc_manager_platform_interface.dart';
import './uvcplugin_bindings_generated.dart';
import './uvc_device_info.dart';
import './uvc_control_info.dart';
import './uvc_video_size.dart';
import './uac_info.dart';

//--------------------------------------------------------------------------------
// 定数達
const String _libName = 'flutter-uvc-plugin';
const String _methodChannelName = 'com.serenegiant.flutter/aandusb_method';
const bool _debug = false;

const _supportedCtrls = <int>[
  FLG_CTRL_SCANNING,
  FLG_CTRL_AE,
  FLG_CTRL_AE_PRIORITY,
  FLG_CTRL_AE_ABS,
  FLG_CTRL_FOCUS_AUTO,
  FLG_CTRL_FOCUS_ABS,
  FLG_CTRL_IRIS_ABS,
  FLG_CTRL_ZOOM_ABS,
  FLG_CTRL_PAN_ABS,
  FLG_CTRL_TILT_ABS,
  FLG_CTRL_ROLL_ABS,
  FLG_CTRL_PRIVACY,
];

const _supportedProcs = <int>[
  FLG_PU_BRIGHTNESS,
  FLG_PU_CONTRAST_AUTO,
  FLG_PU_CONTRAST,
  FLG_PU_HUE_AUTO,
  FLG_PU_HUE,
  FLG_PU_SATURATION,
  FLG_PU_SHARPNESS,
  FLG_PU_GAMMA,
  FLG_PU_WB_TEMP_AUTO,
  FLG_PU_WB_TEMP,
  FLG_PU_WB_COMPO_AUTO,
  FLG_PU_WB_COMPO,
  FLG_PU_BACKLIGHT,
  FLG_PU_GAIN,
  FLG_PU_POWER_LF,
];

/// デバッグログ出力設定
final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 3,
      dateTimeFormat: DateTimeFormat.none,
      excludeBox: {
        Level.trace: true,
        Level.debug: true,
        Level.info: true,
        Level.warning: false,
        Level.error: false,
      },
    )
);

/// 内部使用の解像度設定
class _VideoParam {
  final int frameType;
  final int width;
  final int height;

  _VideoParam(this.frameType, this.width, this.height);

  @override
  String toString() {
    return '_VideoParam{frameType:$frameType, width:$width, height:$height}';
  }
}

//--------------------------------------------------------------------------------
// ヘルパー関数
/// 指定したライブラリ名からプラットフォームに対応したパスを生成して読み込む
final ffi.DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return ffi.DynamicLibrary.open('build/macos/Build/Products/Debug'
          '/$_libName/$_libName.framework/$_libName');
    }
    return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return ffi.DynamicLibrary.open(
          'build/linux/x64/debug/bundle/lib/lib$_libName.so');
    }
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return ffi.DynamicLibrary.open(p.canonicalize(
          p.join(r'build\windows\runner\Debug', '$_libName.dll')));
    }
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final UVCPluginBindings _binding = UVCPluginBindings(_dylib);
final MethodChannel _channel = MethodChannel(_methodChannelName);

/// native側からの非同期呼び出しを受け取ることができるように初期化する
void _initNativeApi(ReceivePort port) async {
  if (_debug) _logger.d("initNativeApi:");
  // initialize the native dart API
  if (_binding.initialize_dart_api(ffi.NativeApi.initializeApiDLData) != 0) {
    throw "Failed to initialize Dart API";
  }

  final nativePort = port.sendPort.nativePort;
  if (_debug) _logger.d("set send port,$nativePort");
  _binding.set_dart_api_message_port(nativePort);
  if (_debug) _logger.d("initNativeApi:finished");
}

//--------------------------------------------------------------------------------
/// UVC機器からの映像および音声取得開始/停止や設定を行うためのコントローラークラス
class UVCController implements UVCControllerInterface {
  /// 機器識別ID
  @override
  final int deviceId;
  /// UVC機器からの映像表示用テクスチャID
  int textureId = -1;
  /// 対応解像度設定一覧
  final _supportedSize = <VideoSize>[];             // List<VideoSize>
  /// 対応UVC機器コントロール設定一覧
  final _supportedControls = <int, ControlInfo>{};  // Map<int, ControlInfo>

  /// コンストラクタ
  UVCController({
    required this.deviceId,
  });

  /// UVC機器が取り外された時の処理
  @override
  Future<void> detached() async {
    if (_debug) _logger.d("UVCController#detached:");
    await stop();
    if (textureId >= 0) {
      await releaseTexture();
    }
  }

  /// 現在の接続状態を取得する
  @override
  device_state state() {
    return device_state.fromValue(_binding.get_state(deviceId));
  }

  /// UVC機器からの映像取得を開始
  @override
  Future<int> start() async {
    if (_debug) _logger.d("UVCController#start:deviceId=$deviceId,textureId=$textureId,state=${state()}");
    if ((state() == device_state.CONNECTED) && (textureId >= 0)) {
      return compute(_start, deviceId);
    } else {
      return 0;
    }
  }

  /// UVC機器からの映像取得を終了
  @override
  Future<int> stop() async {
    if (_debug) _logger.d("UVCController#stop:deviceId=$deviceId,state=${state()}");
    // stopをcomputeで非同期呼び出しするとテクスチャ/Surfaceの破棄の
    // タイミングと合わないので直接呼び出す
    return _binding.stop(deviceId);
  }

  /// 対応する解像度設定一覧を取得
  @override
  Future<List<VideoSize>> getSupportedSize() async {
    await Future.delayed(Duration(milliseconds: 300));
    return compute(_updateSupportedSize, 0);
  }

  /// 対応するUVCコントロール一覧を取得
  @override
  Future<List<ControlInfo>> getSupportedControls() async {
    if (_supportedControls.isEmpty) {
      await Future.delayed(Duration(milliseconds: 300));
      _supportedControls.addAll(await compute(_updateSupportedControls, 0));
    }
    final result = _supportedControls.values.toList();
    return result;
  }

  /// 映像設定を適用
  @override
  Future<VideoSize> setSize(int frameType, int width, int height) async {
    if (_debug) _logger.d('UVCController#setSize:frameType=$frameType,width=$width,height=$height');
    return compute(_setSize, _VideoParam(frameType, width, height));
  }

  /// 現在の映像設定を取得
  @override
  Future<VideoSize> getCurrentSize() async {
    return compute(_getCurrentSize, 0);
  }

  /// 指定したUVCコントロール機能へ設定を適用
  /// 返値のisValidがfalseなら無効
  /// XXX 露出時間設定など現在のUVC機器の設定状態によっては適用できない場合もあるので注意
  /// @param type 設定するUVCコントロール機能の種類
  /// @param value 設定する値
  @override
  Future<ControlInfo> setCtrlValue(int type, int value) async {
    if (_supportedControls.containsKey(type)) {
      var ctrl = _supportedControls[type] ?? ControlInfo.INVALID;
      ctrl.current = value;
      return compute(_setCtrlValue, ctrl);
    } else {
      return ControlInfo.INVALID;
    }
  }

  /// 現在のUVCコントロール機能の設定値を取得
  /// 返値のisValidがfalseなら無効
  /// @param type 設定するUVCコントロール機能の種類
  @override
  Future<ControlInfo> getCtrlValue(int type) async {
    return compute(_getCtrlValue, type);
  }

  /// 機器情報を取得
  @override
  DeviceInfo getDeviceInfo() {
    late DeviceInfo result;
    var info = ffi.malloc<flutter_device_info_t>();
    try {
      _binding.get_device_info(deviceId, info);
      result = _createDeviceInfoFrom(info.ref);
    } finally {
      ffi.malloc.free(info);
    }

    return result;
  }

  /// 映像取得用のテクスチャを生成する
  @override
  Future<int> createTexture(int width, int height) async {
    if (_debug) _logger.d("UVCController#createTexture:deviceId=$deviceId");
    if (textureId < 0) {
      textureId = await _channel.invokeMethod('createTexture', {
        'deviceId': deviceId,
        'width': width,
        'height': height,
      });
      if (_debug) _logger.d("UVCController#createTexture:textureId=$textureId");
    }
    return textureId;
  }

  /// テクスチャを破棄
  @override
  Future<Null> releaseTexture() async {
    if (_debug) _logger.d("UVCController#releaseTexture:deviceId=$deviceId,textureId=$textureId");
    var texId = textureId;
    textureId = -1;
    if (texId >= 0) {
      return _channel.invokeMethod('releaseTexture', {
        'deviceId': deviceId,
        'textureId': texId,
      });
    }
  }

  /// UACの接続状態を取得
  @override
  device_state uacState() {
    return device_state.fromValue(_binding.get_uac_state(deviceId));
  }

  /// UAC機器からの音声取得を開始
  @override
  Future<int> startUAC(int sendPort) async {
    var state = uacState();
    if (_debug) _logger.d("UVCController#start:deviceId=$deviceId,state=$state");
    if ((state == device_state.CONNECTED)) {
      return compute(_startUac, sendPort);
    } else {
      return 0;
    }
  }

  /// UAC機器からの音声取得を終了
  @override
  Future<int> stopUAC() async {
    if (_debug) _logger.d("UVCController#stop:deviceId=$deviceId,state=${state()}");
    // stopをcomputeで非同期呼び出しするとテクスチャ/Surfaceの破棄の
    // タイミングと合わないので直接呼び出す
    return _binding.stop_uac(deviceId);
  }

  /// UAC情報を取得
  @override
  UACInfo getUACInfo() {
    late UACInfo result;
    var info = ffi.malloc<flutter_uac_info>();
    try {
      _binding.get_uac_info(deviceId, info);
      result = _createUACInfoFrom(info.ref);
    } finally {
      ffi.malloc.free(info);
    }

    return result;
  }

  /// startの下請け
  /// computeの引数にffiのバインディングを渡すとクラッシュするので通常のdart関数としてラップ
  int _start(int id) {
    return _binding.start(id);
  }

  /// uacStartの下請け
  /// computeの引数にffiのバインディングを渡すとクラッシュするので通常のdart関数としてラップ
  int _startUac(int sendPort) {
    return _binding.start_uac(deviceId, sendPort);
  }

  /// 映像設定を適用
  /// computeで別スレッド処理するには引数が1つでないとだめなのでラップ
  /// computeの引数にffiのバインディングを渡すとクラッシュするので通常のdart関数としてラップ
  VideoSize _setSize(_VideoParam sz) {
    if (_debug) _logger.d("UVCController#_setSize:$sz");
    _binding.set_video_size(deviceId, sz.frameType, sz.width, sz.height);
    return _getCurrentSize(0);
  }

  /// 現在の解像度設定を取得する
  VideoSize _getCurrentSize(int dummy) {
    VideoSize result = VideoSize.INVALID;
    var sz = ffi.malloc<flutter_video_size_t>();
    try {
      var r = _binding.get_current_size(deviceId, sz);
      if (r == 0) {
        result = createVideoSizeFrom(sz.ref);
      }
    } finally {
      ffi.malloc.free(sz);
    }

    if (_debug) _logger.d("UVCController#_getCurrentSize:$result");
    return result;
  }

  /// UVCコントロール機能の値を変更
  /// XXX 露出時間設定など現在のUVC機器の設定状態によっては適用できない場合もあるので注意
  ControlInfo _setCtrlValue(ControlInfo info) {
    if (info.isValid() && _supportedControls.containsKey(info.type)) {
      var r = _binding.set_ctrl_value(deviceId, info.type, info.current);
      if (r == 0) {
        info = _getCtrlValue(info.type);
      } else {
        info = ControlInfo.INVALID;
      }
    } else {
      info = ControlInfo.INVALID;
    }

    return info;
  }

  /// UVCコントロール機能の現在値を取得
  ControlInfo _getCtrlValue(int type) {
    if (_supportedControls.containsKey(type)) {
      final value = ffi.calloc<ffi.Int32>();
      try {
        var r = _binding.get_ctrl_value(deviceId, type, value);
        if (r == 0) {
          _supportedControls[type]?.current = value.value;
        }
      } finally {
        ffi.calloc.free(value);
      }
      return _supportedControls[type] ?? ControlInfo.INVALID;
    } else {
      return ControlInfo.INVALID;
    }
  }

  /// 対応する解像度設定一覧を更新する
  List<VideoSize> _updateSupportedSize(int dummy) {
    if (_supportedSize.isEmpty) {
      // dart_ffi.Pointer<dart_ffi.Int32> numSupported = arena.allocate<dart_ffi.Int32>(1);
      var numSupported = ffi.calloc<ffi.Int32>();
      _binding.get_supported_size(deviceId, 0, numSupported, ffi.nullptr);
      if (_debug) _logger.d("UVCController#_initSupportedSize:numSupported=${numSupported.value}");
      if (numSupported.value > 0) {
        var sz = ffi.malloc<flutter_video_size_t>();
        for (int i = 0; i < numSupported.value; i++) {
          var r = _binding.get_supported_size(deviceId, i, numSupported, sz);
          if (r == 0) {
            var size = createVideoSizeFrom(sz.ref);
            _supportedSize.add(size);
          }
        }
        ffi.malloc.free(sz);
      }
      ffi.calloc.free(numSupported);
    }
    return _supportedSize;
  }

  /// 対応するUVCコントロール一覧を更新する
  Map<int, ControlInfo> _updateSupportedControls(int dummy) {
    final result = <int, ControlInfo>{};  // Map<int, ControlInfo>
    var info = ffi.malloc<flutter_control_info_t>();
    try {
      var ctrlSupport = _binding.get_ctrl_supports(deviceId);
      for (int type in _supportedCtrls) {
        if ((ctrlSupport & type) != 0) {
          info.ref.type = type;
          var r = _binding.get_ctrl_info(deviceId, info);
          if (r == 0) {
            var ctrl = _createControlInfoFrom(info.ref);
            result[ctrl.type] = ctrl;
          }
        }
      }
      var procSupport = _binding.get_proc_supports(deviceId);
      for (int type in _supportedProcs) {
        if ((procSupport & type) != 0) {
          info.ref.type = 0x80000000 | type;
          var r = _binding.get_ctrl_info(deviceId, info);
          if (r == 0) {
            var ctrl = _createControlInfoFrom(info.ref);
            result[ctrl.type] = ctrl;
          }
        }
      }
    } finally {
      ffi.malloc.free(info);
    }

    return result;
  }

  @override
  String toString() {
    return 'UVCController{'
        'deviceId:$deviceId, '
        'textureId:$textureId}';
  }
}

//--------------------------------------------------------------------------------
/// UVC機器の接続管理を行うマネージャークラス
class UVCManager with ChangeNotifier, WidgetsBindingObserver implements UVCManagerPlatform {
  // シングルトンパターンでアクセスできるようにする
  static final UVCManager _instance = UVCManager._internal();
  // ファクトリーコンストラクタ
  factory UVCManager() => _instance;

  //----------------------------------------------------------------------
  final Map<int, UVCControllerInterface> _availableControllers = {};
  final ReceivePort _nativeMessagePort = ReceivePort();

  // 内部使用のコンストラクタ
  UVCManager._internal() {
    if (_debug) _logger.d("UVCManager#_internal:");
    _initNativeApi(_nativeMessagePort);
    _nativeMessagePort
        .listen((message) => _handleNativeMessage(message));
    _channel.invokeMethod('initialize');
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_debug) _logger.d("didChangeAppLifecycleState:state=$state");
    // アプリがバックグラウンドになるときは
    //     inactive -> hidden -> paused -> detached
    // resumeが来る時は
    //     inactive -> resume
    switch (state) {
      case AppLifecycleState.resumed:
        // アプリがポーズ中にUVC機器が取り外された時の処理
        final List<int> removed = <int>[];
        for (var entry in _availableControllers.entries) {
          final state = entry.value.state();
          _logger.d("state=$state");
          if ((state == device_state.UNINITIALIZED)
              || (state == device_state.DISCONNECTED)) {
            removed.add(entry.key);
          }
        }
        if (removed.isNotEmpty) {
          for (final int deviceId in removed) {
            _availableControllers.remove(deviceId);
          }
          notifyListeners();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// native側からのメッセージ受信処理
  void _handleNativeMessage(final message) {
    if (_debug) _logger.d("UVCManager#handleNativeMessage:$message");
    final action = message[0];
    switch (action) {
      case 'on_device_changed':
        // 機器接続・切断イベントメッセージを受信したときの処理
        final int deviceId = message[1];
        final bool attached = message[2];
        if (attached) {
          _handleOnDeviceAttached(deviceId);
        } else {
          _handleOnDeviceDetached(deviceId);
        }
        break;
      default:
        if (_debug) _logger.d('unknown received message:$message');
        break;
    }
  }

  /// 接続されているUVC機器の数
  @override
  int getAvailableCount() {
    return _availableControllers.length;
  }

  /// 接続されているUVC機器一覧を取得する
  @override
  List<UVCControllerInterface> getControllers() {
    List<UVCControllerInterface> list = [];
    list.addAll(_availableControllers.values.toList());
    if (_debug) _logger.d("UVCManager#getControllers:$list");
    return list;
  }

  /// 接続されているUVC機器の指定した位置に対応するUVCControllerを取得する
  @override
  UVCControllerInterface getControllerAt(int index) {
    if (_debug) _logger.d("getControllerAt:index=$index,num=${_availableControllers.length}");
    if ((index < 0) || (index > _availableControllers.length)) {
      throw Exception("Index is out of bounds");
    }
    UVCControllerInterface? result;
    int i = 0;
    for (var entry in _availableControllers.entries) {
      if (i == index) {
        result = entry.value;
        if (_debug) _logger.d("getControllerAt:found,$result");
        break;
      }
    }
    if (result == null) {
      throw Exception("UVCController not found");
    }
    if (_debug) _logger.d("UVCManager#getControllerAt:${result.toString()}");
    return result;
  }

  /// 機器識別IDを指定してUVCControllerを取得する
  @override
  UVCControllerInterface getController(int deviceId) {
    if (_availableControllers.containsKey(deviceId)) {
      return _availableControllers[deviceId]!;
    } else {
      throw Exception("UVCController not found");
    }
  }

  /// 画面の自動消灯のON/OFF
  @override
  Future<Null> keepScreenOn(bool onoff) async {
    if (_debug) _logger.d("UVCController#keepScreenOn:onoff=$onoff");
    return _channel.invokeMethod('keepScreenOn', {
      'onoff': onoff,
    });
  }

  /// USB機器が接続されたときの処理
  void _handleOnDeviceAttached(int deviceId) {
    if (_debug) _logger.d('_handleOnDeviceAttached:deviceId=$deviceId');
    if (!_availableControllers.containsKey(deviceId)) {
      if (_debug) _logger.d("_handleOnDeviceAttached:create UVCController");
      var connector = UVCController(deviceId: deviceId);
      _availableControllers[deviceId] = connector;
      // if (_debug) _logger.d("info=${connector.getDeviceInfo()}");
    }
    notifyListeners();
  }

  /// USB機器が取り外されたときの処理
  void _handleOnDeviceDetached(int deviceId) {
    if (_debug) _logger.d('_handleOnDeviceDetached:deviceId=$deviceId');
    var controller = _availableControllers.remove(deviceId);
    controller?.detached();
    notifyListeners();
  }
}

void keepScreenOn(bool onoff) {
  UVCManagerPlatform.instance.keepScreenOn(onoff);
}

//--------------------------------------------------------------------------------
/// FFI経由で読み取ったバックエンド側の情報からDeviceInfoを生成するヘルパー関数
DeviceInfo _createDeviceInfoFrom(flutter_device_info info) {
  return DeviceInfo(
  info.vendor_id, info.product_id,
  info.device_class, info.device_subclass, info.device_protocol,
  info.reserved1,
  _arrayToString(info.name),
  _arrayToString(info.manufacturer_name),
  _arrayToString(info.product_name),
  _arrayToString(info.serial));
}

/// FFI経由で読み取ったバックエンド側の情報からUACInfoを生成するヘルパー関数
UACInfo _createUACInfoFrom(flutter_uac_info info) {
  return UACInfo(
      info.device_id,
      info.channels,
      info.resolution,
      info.sampling_freq,
      info.packet_bytes);
}

/// uint8_t配列からUTF8と見なしてdartのStringへ変換するヘルパー関数
/// @param array
String _arrayToString(ffi.Array<ffi.Uint8> array) {
  final stringList = <int>[];
  var i = 0;
  while (array[i] != 0) {
    stringList.add(array[i]);
    i++;
  }
  return String.fromCharCodes(stringList);
}

/// FFI経由で読み取ったバックエンド側の情報からVideoSizeを生成するヘルパー関数
VideoSize createVideoSizeFrom(flutter_video_size sz) {
  if (_debug) _logger.d("num_frame_intervals=${sz.num_frame_intervals}/${sz.frame_intervals.elements.length},num_fps=${sz.num_fps}/${sz.fps.elements.length}");
  var frameIntervals = <int>[];
  for (int i = 0; i < sz.num_frame_intervals; i++) {
    frameIntervals.add(sz.frame_intervals[i]);
  }
  var fps = <double>[];
  for (int i = 0; i < sz.num_fps; i++) {
    fps.add(sz.fps[i]);
  }
  return VideoSize(
    sz.frame_type,
    sz.frame_index,
    sz.width, sz.height,
    sz.frame_interval_type,
    frameIntervals, sz.num_frame_intervals,
    fps, sz.num_fps,
  );
}

ControlInfo _createControlInfoFrom(flutter_control_info_t info) {
  return ControlInfo(
      info.type,
      info.initialized,
      info.has_min_max,
      info.def,
      info.current,
      info.res,
      info.min,
      info.max);
}
