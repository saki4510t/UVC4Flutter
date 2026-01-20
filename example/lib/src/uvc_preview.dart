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
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'package:uvc_manager/uvc_manager.dart';

//--------------------------------------------------------------------------------
// 定数定義
const bool _debug = false;

//--------------------------------------------------------------------------------
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
/// UVC機器からの映像を表示するウィジェット
class UVCVideoView extends StatefulWidget {
  final int deviceId;
  /// デフォルトのフレームタイプ
  final int frameType;
  /// デフォルトの解像度(幅)
  final int videoWidth;
  /// デフォルトの解像度(高さ)
  final int videoHeight;
  /// 映像取得待機中のメッセージウィジェット
  final Widget? waitingMessage;
  /// 解像度選択やUVC機器コントロール用のウィジェット
  final Widget? controlView;

  const UVCVideoView({super.key,
    required this.deviceId,
    this.frameType  = 7,
    this.videoWidth = 640,
    this.videoHeight = 480,
    this.waitingMessage,
    this.controlView,
  });

  @override
  State<StatefulWidget> createState() => UVCVideoViewState();
}

/// State for UVCVideoView
/// 親WidgetからsetSizeを呼べるようにpublicにする
class UVCVideoViewState extends State<UVCVideoView> with WidgetsBindingObserver {
  /// UVC機器アクセス用
  late UVCControllerInterface _controller;
  UACInfo _uacInfo = UACInfo(0, 1, 16, 32000, 512);
  ReceivePort _uacReceivePort = ReceivePort();
  late Stream<Uint8List> _uacStream;
  /// 現在の解像度設定
  VideoSize _currentSize = VideoSize(
      7, 0, 640, 480, 0, List.empty(), 0, List.empty(), 0);
  /// UVC機器からの映像を表示するときに使うテクスチャID
  int _textureId = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSize = VideoSize(
      widget.frameType, 0,
      widget.videoWidth, widget.videoHeight,
      0, List.empty(), 0, List.empty(), 0);
    _controller = UVCManagerPlatform.instance.getController(widget.deviceId);
    if (_debug) _logger.d("_UVCVideoViewState#initState:controller=$_controller");
    _initTexture();
  }

  @override
  Future<void> dispose() async {
    if (_debug) _logger.d("_UVCVideoViewState#dispose:");
    WidgetsBinding.instance.removeObserver(this);
    await _controller.stop();
    await _controller.releaseTexture();
    _uacReceivePort.close();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_debug) _logger.d("_UVCVideoViewState#didChangeAppLifecycleState:state=$state");
    // アプリがバックグラウンドになるときは
    //     inactive -> hidden -> paused -> detached
    // resumeが来る時は
    //     inactive -> resume
    switch (state) {
      case AppLifecycleState.resumed:
        final sz = await _controller.getCurrentSize();
        _startUVC(sz);
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        await _stopUVC();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_debug) _logger.d("_UVCVideoViewState#build:");
    return Container(
      color: const Color.fromARGB(255, 0, 0, 0),
      alignment: Alignment.center,
      child: (_textureId < 0)
        ? widget.waitingMessage
        : (widget.controlView != null)
          ? Stack(  // 解像度選択・UVC機器コントロール機能用ウィジェットを表示するとき
              fit: StackFit.expand,
              children: [
                _CropCenterWidget(
                  size: _currentSize,
                  child: Texture(textureId: _textureId),
                ),
                widget.controlView!,
              ],
            )
          : _CropCenterWidget(
              size: _currentSize,
              child: Texture(textureId: _textureId),
          )
    );
  }

  /// 解像度変更処理
  void setSize(VideoSize size) {
    if (_debug) _logger.d("_UVCVideoViewState#_setSize:$size");
    _controller.setSize(size.frameType, size.width, size.height).then((sz) => setState(() {
      _currentSize = sz;
    }));
  }

  /// UVC機器映像取得用のテクスチャ/surfaceを初期化して映像取得を開始する
  Future<Null> _initTexture() async {
    if (_debug) _logger.d("_UVCVideoViewState#initTexture:");
    final sz = await _controller.setSize(_currentSize.frameType, _currentSize.width, _currentSize.height);
    if (!sz.isValid()) {
      _logger.w("failed to set video size,sz=$sz/$_currentSize");
      return;
    }
    _startUVC(sz);
  }

  /// UVC機器からの映像と音声取得開始処理
  void _startUVC(VideoSize sz) async {
    final textureId = await _controller.createTexture(sz.width, sz.height);
    if (_debug) _logger.d("_UVCVideoViewState#_startUVC,textureId=$textureId,sz=$sz");
    await _controller.start();
    // FIXME 今のままでもエラーにはならないけど、UACに対応している場合のみstartUACを呼ぶほうがいいかもしれない
    // UVC機器毎にUAC音声データをStream<Uint8List>として受け取りたいので個別にReceivePortを生成してsendPortを渡す
    _uacReceivePort.close();
    _uacReceivePort = ReceivePort();
    _uacStream = _uacReceivePort.cast<Uint8List>();
    _uacStream.listen((Uint8List data) {
      // if (_debug) _logger.d("onData:$data");
      // FIXME 受け取ったUACからの音声データを再生させる
      //       ・flutter_soundもflutter_pcm_soundも正常に再生できない,
      //       ・NDKのoboeやUnity(のSoundClip)へ同じデータを渡すと正常に再生できるのでバックエンド自体は正常
      //       ・ReceivePortを経由してStream<Uint8List>で受け取っているのがまずいのか
      //       ・flutter_soundもflutter_pcm_soundのAudioTrackの初期化/処理がまずいのが不明
      //       ・音的にはAudioTrackへサンプリング周波数が渡されてなさそう？
    });
    await _controller.startUAC(_uacReceivePort.sendPort.nativePort);
    final uacInfo = _controller.getUACInfo();
    setState(() {
      _textureId = textureId;
      _currentSize = sz;
      _uacInfo = uacInfo;
      if (_debug) _logger.d("uacInfo=$_uacInfo");
    });
  }

  /// UVC機器からの映像と音声取得を終了
  Future<void> _stopUVC() async {
    if (_debug) _logger.d("_UVCVideoViewState#_stopUVC");
    await _controller.stop();
    await _controller.releaseTexture();
    _uacReceivePort.close();
    setState(() {
      _textureId = -1;
    });
  }

}

/// childを親Widgetの中央にクロップセンター表示するWidget
class _CropCenterWidget extends StatefulWidget {
  final VideoSize size;
  final Widget? child;

  const _CropCenterWidget({
    required this.size,
    this.child,
  });

  @override
  State<StatefulWidget> createState() => _CropCenterWidgetState();
}

class _CropCenterWidgetState extends State<_CropCenterWidget> {
  @override
  Widget build(BuildContext context) {
    var width = widget.size.width.toDouble();
    if (width == 0) {
      width = 640.0;
    }
    var height = widget.size.height.toDouble();
    if (height == 0) {
      height = 480.0;
    }
    if (_debug) _logger.d("_CropCenterWidget:(${width}x$height)");
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            height: height,
            child: widget.child
          )
        )
      ),
    );
  }
}