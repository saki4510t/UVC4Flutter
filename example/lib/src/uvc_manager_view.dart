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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'package:uvc_manager/uvc_manager.dart';
import './uvc_control_value.dart';
import './uvc_control_settings.dart';
import './uvc_preview.dart';

//--------------------------------------------------------------------------------
// 定数定義
const bool _debug = false;

//--------------------------------------------------------------------------------
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

//--------------------------------------------------------------------------------
/// UVC機器の接続・切断を監視してUVC機器が接続されたときにUSB機器アクセスパーミションを取得、
/// UVC機器からの映像を表示するウィジェット
/// 最初に接続された1台だけに対応する
class UVCManagerView extends StatefulWidget {
  /// デフォルトのフレームタイプ
  final int frameType;
  /// デフォルトの解像度(幅)
  final int videoWidth;
  /// デフォルトの解像度(高さ)
  final int videoHeight;
  /// 接続されているUVC機器が無いときのメッセージウィジェット
  final Widget? noDeviceMessage;
  /// 映像取得待機中のメッセージウィジェット
  final Widget? waitingMessage;

  /// コンストラクタ
  const UVCManagerView({
    super.key,
    this.frameType = 7,
    this.videoWidth = 640,
    this.videoHeight = 480,
    this.noDeviceMessage,
    this.waitingMessage,
  });

  @override
  State<StatefulWidget> createState() => _UVCManagerViewState();
}

/// State for UVCViewFrame
class _UVCManagerViewState extends State<UVCManagerView> {
  /// UVC機器の接続状態が変化したときのコールバック、UVCManagerから呼ばれる
  late VoidCallback _listener;
  int _deviceCount = 0;
  int _deviceId = 0;

  _UVCManagerViewState() {
    _deviceCount = 0;
    _listener = () {
      final int newDeviceCount = UVCManagerPlatform.instance.getAvailableCount();
      final connected = (newDeviceCount > 0);
      keepScreenOn(connected);
      if (_debug) _logger.d("_UVCViewFrameState#VoidCallback:$_deviceCount=>$newDeviceCount");
      if (_deviceCount != newDeviceCount) {
        setState(() {
          _deviceCount = newDeviceCount;
          if (connected) {
            _deviceId = UVCManagerPlatform.instance.getControllerAt(0).deviceId;
          } else {
            _deviceId = 0;
          }
        });
      }
    };
  }

  @override
  void initState() {
    super.initState();
    if (_debug) _logger.d("_UVCViewFrameState#initState:");
    UVCManagerPlatform.instance.addListener(_listener);
  }

  @override
  void dispose() {
    if (_debug) _logger.d("_UVCViewFrameState#dispose:");
    UVCManagerPlatform.instance.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoViewKey = GlobalObjectKey<UVCVideoViewState>(context);
    return (_deviceId == 0)
      ? Container(
          color: const Color.fromARGB(255, 0, 0, 0),
          padding: const EdgeInsets.all(10.0),
          alignment: Alignment.center,
          child: widget.noDeviceMessage,
        )
      : UVCVideoView(
          key: videoViewKey,
          deviceId: _deviceId,
          frameType: widget.frameType,
          videoWidth: widget.videoWidth,
          videoHeight: widget.videoHeight,
          waitingMessage: widget.waitingMessage,
          controlView: UVCCtrlView(
            deviceId: _deviceId,
            onSelected: (size) => (size != null) ? videoViewKey.currentState?.setSize(size) : {}
        )
    );
  }
}

typedef _ValueChange<T> = Future<T> Function(T value);

class _UVCCtrlItem extends StatefulWidget {
  final ControlValue controlValue;
  final _ValueChange<ControlInfo> onValueChange;

  const _UVCCtrlItem({
    required this.controlValue,
    required this.onValueChange,
  });

  @override
  State<StatefulWidget> createState() => _UVCCtrlItemState();
}

class _UVCCtrlItemState extends State<_UVCCtrlItem> {
  late ControlValue _controlValue;
  double _currentProgress = 0.0;
  String _currentLabel = "";
  int _lastChangedTimeMs = 0;

  @override
  void initState() {
    super.initState();
    if (_debug) _logger.d("_UVCCtrlItemState#initState:");
    setState(() {
      _controlValue = widget.controlValue;
      _currentProgress = _controlValue.progress;
      _currentLabel = _controlValue.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    // title, icon, min, maxは変更されることはない
    final title = _controlValue.title;
    final icon = _controlValue.icon;
    final min = _controlValue.minProgress;
    final max = _controlValue.maxProgress;
    if (_debug) _logger.d("_UVCCtrlItemState#build:title=$title,min=$min,max=$max,v=$_controlValue");
    return Row(
      children: [
        IconButton(
          onPressed: () => {
            /// 設定値をリセット(デフォルト値を適用)
            _applyValue(_controlValue.def)
          },
          icon: Icon(
            icon,
            size: 42.0,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Color(0xffffffff),
                  fontSize: 18.0,
                ),
              ),
              Text(
                _currentLabel,
                style: TextStyle(
                  color: Color(0xffffffff),
                  fontSize: 18.0,
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Slider(
                    min: min,
                    max: max,
                    divisions: (max != min) ? (max - min).toInt() : 1,
                    value: _currentProgress,
                    onChanged: !_controlValue.isAuto ? (value) => _onValueChanged(value) : null
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 32,
            // 自動設定のON/FF用のチェックボックス
            child: (_controlValue.hasAuto)
              ? Checkbox(
                  value: _controlValue.isAuto,
                  onChanged: (checked) => _onCheckedChanged(checked)
                )
             : Text("")
          ),
        ),
      ],
    );
  }

  /// スライダで値を変更したときの処理
  void _onValueChanged(double progress) {
    // 設定値は整数しかないので小数点以下を整数に丸める
    final roundProgress = progress.roundToDouble();
    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
    if ((roundProgress != _currentProgress) && (currentTimeMs - _lastChangedTimeMs > 100)) {
      // 高速で適用しようとしてもUVC機器側が追随できないので追随遅延実行する
      _lastChangedTimeMs = currentTimeMs;
      // progressから実際の設定値を計算する
      _controlValue.progress = roundProgress;
      var newValue = _controlValue.current;
      if (_debug) _logger.d("_UVCCtrlItemState#_onValueChanged:progress=$progress,current=$newValue");
      _applyValue(newValue);
    }
  }

  void _applyValue(int newValue) {
    if (_debug) _logger.d("_UVCCtrlItemState#_applyValue:$newValue");
    final value = _controlValue.copyWith(newValue);
    try {
      // UVC機器へ適用する
      widget.onValueChange(value.info).then((result) => setState(() {
        final res = _controlValue.copyWith(result.current);
        if (_debug) _logger.d("_UVCCtrlItemState#_applyValue:result=$result/$res");
        _currentProgress = res.progress;
        _currentLabel = res.label;
        _controlValue = res;
      }));
    } catch (e) {
      _logger.w(e);
    }
  }

  /// 自動設定のチェックボックの状態が変化したときの処理
  void _onCheckedChanged(bool? checked) {
    _controlValue.isAuto = (checked == true);
    final info = ControlInfo(_controlValue.autoType, 1, 0, 0, _controlValue.isAuto ? 1 : 0, 0, 0, 0);
    if (_debug) _logger.d("_UVCCtrlItemState#_onCheckedChanged:$checked,info=$info");
    try {
      // UVC機器へ適用する
      widget.onValueChange(info).then((result) => setState(() {
        if (result.type == _controlValue.autoType) {
          final res = _controlValue.copyWith(_controlValue.current);
          if (_debug) _logger.d("_UVCCtrlItemState#_onCheckedChanged:result=$result/$res");
          res.isAuto = result.current != 0;
          _controlValue = res;
        }
      }));
    } catch (e) {
      _logger.w(e);
    }
  }
}

/// 解像度選択用ウィジェットと対応UVC機器コントロール一覧を
/// UVC機器からの映像の重ねて表示するためのウィジェット
class UVCCtrlView extends StatefulWidget {
  final int deviceId;
  final ValueChanged<VideoSize?>? onSelected;

  /// コンストラクタ
  const UVCCtrlView({
    super.key,
    required this.deviceId,
    required this.onSelected,
  });

  @override
  State<StatefulWidget> createState() => _UVCCtrlViewState();
}

/// State for UVCCtrlView
class _UVCCtrlViewState extends State<UVCCtrlView> {
  /// UVC機器アクセス用
  late UVCControllerInterface _controller;
  /// 対応解像度一覧
  List<VideoSize> _supportedSize = <VideoSize>[];
  /// 対応しているUVC機器コントロール設定一覧
  List<ControlInfo> _supportedCtrls = <ControlInfo>[];

  @override
  void initState() {
    super.initState();
    _controller = UVCManagerPlatform.instance.getController(widget.deviceId);
    if (_debug) _logger.d("_UVCCtrlViewState#initState:controller=$_controller");
    _controller.getSupportedSize().then((supported) => setState(() {
      _supportedSize = supported;
    }));
    _controller.getSupportedControls().then((controls) => setState(() {
      _supportedCtrls = controls;
    }));
  }

  /// ControlInfoリストからControlValueリストを生成する
  static List<ControlValue> _createControlValues(int deviceId, List<ControlInfo> controls) {
    final result = <ControlValue>[];

    for (ControlInfo ctrl in controls) {
      final settings = ControlSettings.get(ctrl.type);
      if (settings != null) {

        ControlValue value;
        if (ctrl.type == FLG_CTRL_AE) {
          // type==FLG_CTRL_AEの時はresが設定可能値のビットマップなのでそれに合わせてselectorsを変更しないとだめ
          // GET_RESで対応している露出モードのビットマスクが取得できる
          final res = ctrl.res;
          final selectors = Map<int, String>.from(settings.selectors)..removeWhere((key, value) => (key & res) == 0);
          final newSettings = settings.copyWith(selectors);
          value = ControlValue(deviceId, ctrl, newSettings);
        } else if (ctrl.type == FLG_PU_POWER_LF) {
          // type==FLG_PU_POWER_LFの時は3:自動設定に対応している場合としていないときでselectorsを変更する
          final max = math.max(math.max(ctrl.hasMinMax != 0 ? ctrl.max : 2, ctrl.min), ctrl.current);
          final selectors = Map<int, String>.from(settings.selectors)..removeWhere((key, value) => key > max);
          final newSettings = settings.copyWith(selectors);
          value = ControlValue(deviceId, ctrl, newSettings);
        } else {
          value = ControlValue(deviceId, ctrl, settings);
        }
        value.hasAuto = value.hasAuto && (controls.lastIndexWhere((ctrl) => ctrl.type == value.autoType) != -1);
        if (value.hasAuto) {
          final autoCtrl = controls.firstWhere((ctrl) => ctrl .type == value.autoType);
          value.isAuto = autoCtrl.current != 0;
        }

        result.add(value);
      } else {
        if (_debug) _logger.d("_createControlValues:not supported $ctrl");
      }
    }

    return result;
  }

  Future<ControlInfo> _applyValue(ControlInfo value) {
    if (_debug) _logger.d("_UVCCtrlViewState#_applyValue:$value");
    return _controller.setCtrlValue(value.type, value.current);
  }

  @override
  Widget build(BuildContext context) {
    if (_debug) _logger.d("_UVCCtrlViewState#build:");
    final controlValues = _createControlValues(widget.deviceId, _supportedCtrls);
    return Column(
      children: [
        Padding(
            padding: EdgeInsets.all(10.0),
            child: DropdownMenu<VideoSize>(
              label: const Text(
                'Supported video size',
                style: TextStyle(
                  color: Color(0xffffffff),
                  fontSize: 24.0,
                ),
              ),
              width: double.infinity,
              menuHeight: 300.0,
              menuStyle: MenuStyle(
                backgroundColor: WidgetStatePropertyAll<Color>(Color(0x00000000)),
              ),
              textStyle: TextStyle(
                color: Color(0xffffffff),
                fontSize: 24.0,
              ),
              onSelected: (VideoSize? size) {
                if (size != null) {
                  if (_debug) _logger.d("onSelected:$size");
                  widget.onSelected?.call(size);
                }
              },
              dropdownMenuEntries: _supportedSize
                  .map<DropdownMenuEntry<VideoSize>>((VideoSize size) {
                return DropdownMenuEntry<VideoSize>(
                  value: size,
                  label: size.toShortString(),
                  labelWidget: SizedBox(
                    width: 200,
                    child: Text(
                      size.toShortString(),
                      style: TextStyle(
                        // backgroundColor: Color(0x7fff0000),
                        color: Color(0xffffffff),
                        fontSize: 24.0,
                      ),
                    ),
                  ),
                  // Customize the style as needed
                  style: MenuItemButton.styleFrom(
                    textStyle: TextStyle(
                      color: Color(0xffffffff),
                      fontSize: 24.0,
                    ),
                    alignment: Alignment.center,
                  ),
                );
              }).toList(),
            )
        ),
        Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Color(0x3f000000),
                height: 300,
                child: controlValues.isNotEmpty
                  ? ListView.builder(
                      itemCount: controlValues.length,
                      itemBuilder: (context, index) {
                        return _UVCCtrlItem(
                          controlValue: controlValues[index],
                          onValueChange: ((value) => _applyValue(value)),
                        );
                      }
                    )
                : Text("")
              ),
            )
        ),
      ],
    );
  }
}
