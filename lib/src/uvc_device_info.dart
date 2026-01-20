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

// / USB機器情報を保持する
final class DeviceInfo {
  /// ベンダーID
  final int vendorId;
  /// プロダクトID
  final  int productId;
  /// デバイスクラス
  final int deviceClass;
  /// デバイスサブクラス
  final int deviceSubClass;
  /// デバイスプロトコル
  final  int deviceProtocol;
  /// パディング用のダミー
  final int reserved1;
  /// USB機器名(商品名ではない)
  final String name;
  /// 会社名(読み取れない機器は空文字列)
  final String manufacturerName;
  /// 製品名(読み取れない機器は空文字列)
  final String productName;
  /// シリアル番号(読み取れない機器は空文字列)
  final String serial;

  /// コンストラクタ
  DeviceInfo(this.vendorId, this.productId, this.deviceClass,
      this.deviceSubClass, this.deviceProtocol, this.reserved1, this.name,
      this.manufacturerName, this.productName, this.serial);

  @override
  String toString() {
    return 'DeviceInfo{vendorId:$vendorId, productId:$productId, deviceClass:$deviceClass, deviceSubClass:$deviceSubClass, deviceProtocol:$deviceProtocol, reserved1:$reserved1, name:$name, manufacturerName:$manufacturerName, productName:$productName, serial:$serial}';
  }
}
