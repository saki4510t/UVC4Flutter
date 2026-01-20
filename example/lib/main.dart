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

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import './src/camera_permission_handler.dart';
import './src/uvc_manager_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return _MainScreen();
  }
}

class _MainScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> {
  bool hasAllPermission = false;

  @override
  void initState() {
    super.initState();
    // XXX ユーザーがカメラ/音声取得パーミッションを拒絶したときは説明画面を表示and端末のアプリ設定へ移動してカメラ/音声取得パーミッションを設定するように促しそれでも拒絶するならアプリを終了させる必要がある
    CameraPermissionsHandler().request().then((status) => setState(() {
      final denied = status.entries.where((element) => !element.value.isGranted && !element.value.isLimited);
      hasAllPermission = denied.isEmpty;
    }));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: hasAllPermission
                  ? UVCManagerView(
                    videoWidth: 1280, videoHeight: 720,
                    noDeviceMessage: Text(
                      "No UVC device",
                      style: TextStyle(
                        color: Color(0xffffffff),
                        fontSize: 32.0,
                      ),
                    ),
                    waitingMessage: Text(
                      "UVC device connected",
                      style: TextStyle(
                        color: Color(0xffffffff),
                        fontSize: 32.0,
                      ),
                    ),
                  )
                  : Container(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      alignment: Alignment.center,
                      child: Text(
                        "Has no camera permission",
                        style: TextStyle(
                          color: Color(0xffffffff),
                          fontSize: 32.0,
                      ),
                    )
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
