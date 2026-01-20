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

import 'package:flutter_test/flutter_test.dart';
import 'package:uvc_manager/uvc_manager.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUvcManagerPlatform
    with MockPlatformInterfaceMixin
    implements UVCManagerPlatform {
  @override
  void addListener(VoidCallback listener) {
    // TODO: implement addListener
  }

  @override
  int getAvailableCount() {
    // TODO: implement getAvailableCount
    throw UnimplementedError();
  }

  @override
  UVCControllerInterface getController(int deviceId) {
    // TODO: implement getController
    throw UnimplementedError();
  }

  @override
  UVCControllerInterface getControllerAt(int index) {
    // TODO: implement getControllerAt
    throw UnimplementedError();
  }

  @override
  List<UVCControllerInterface> getControllers() {
    // TODO: implement getControllers
    throw UnimplementedError();
  }

  @override
  Future<Null> keepScreenOn(bool onoff) {
    // TODO: implement keepScreenOn
    throw UnimplementedError();
  }

  @override
  void removeListener(VoidCallback listener) {
    // TODO: implement removeListener
  }
}

void main() {
  final UVCManagerPlatform initialPlatform = UVCManagerPlatform.instance;

  test('$UVCManager is the default instance', () {
    expect(initialPlatform, isInstanceOf<UVCManager>());
  });

}
