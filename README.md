# UVC4FlutterAndroid(uvc_manager)
-----

A Flutter plugin to access UVC device(s) on Android devices.

|                | Android |
|----------------|---------|
| **Support**    | API 21+ |

## Features

* Handle attach / detach event of UVC devices.
* Handle USB permission to access UVC devices.
* Render live video images from UVC device into texture.
* Display live video images from UVC device in a widget.
* Access UVC control functions, ex. brightness, contrast, exposure etc.
  Actual functions that this plugin can control are depends on each UVC device.
* Can select video size and frame type.
* Support multiple frame types including MJPEG, YUY2, H264 etc.
* Support UVC1.0, UVC1.1, UVC1.5 devices.
* Support multiple UVC device on a Android device.
  Note: Number of UVC devices and their video size, frame rates are limited by USB bandwidth and total power consumption and power supply.
* Example widget to control UVC control functions.

## Notice

* Some Android 10 and later devices will have issues on their Android OS itself and can not work with UVC devices.
* Some Android devices does not support isochronous transfer and can not work with UVC devices (because most of UVC devices use isochronous transfer to get video images).
* Some Android devices have issues with the power supply to USB. In this case, using a self-powered/bus-powered USB hub may help you.
* Using a long or low quality USB cable or adapter may not work properly.
* Most UVC devices still work with USB2 and may be better to use USB2 cable even if your Android device supports USB3.x.
* Android 10 and later devices needs `AUDIO_RECORD` permission to grant permanent permission to access UVC devices.

## Setup your project

1. create your new Flutter project.
2. add this repository into your `pubspec.yaml` as a reference of git repository.
   ```yaml
    uvc_manager:
      git:
        url: https://github.com/saki4510t/UVC4Flutter.git
   ```
3. Follows steps for each platform.

### Android

* You will need to add `https://raw.github.com/saki4510t/libcommon/master/repository/` to your dependencies search path on root `build.gradle` something like this..
  ```groovy
    allprojects {
      repositories {
        google()
        mavenCentral()
        maven { url = uri("https://raw.github.com/saki4510t/libcommon/master/repository/") }
      }
    }
  ```
* Strongly recommend set `android:launchMode="singleTask"` for your activity in `AndroidManifest.xml`.
* If you want to detect UVC device(s) and automatically start activity and/or want to keep permanent permission of your UVC device(s), add followings in your `AndroidManifest.xml`.
  ```xml
  ...
  <activity
      android:name="com.serenegiant.flutter.uvcplugin.UsbPermissionActivity"
      android:theme="@android:style/Theme.NoDisplay"
      android:exported="true">
      <intent-filter>
          <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
      </intent-filter>

      <meta-data
          android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
          android:resource="@xml/device_filter_uvc" />
  </activity>
  ...
  ```
* If you want app keeps permanent permission of UVC device(s) on Android 9 or later devices, app needs to request `AUDIO_RECORD` permission in `AndroidManifest.xml`.
  Also app need dynamically request `AUDIO_RECORD` runtime permission before using `UVCManager`/`UVCManagerPlatform`.
  ```xml
  ...
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  ...
  ```

### Handling camera access permission

App needs `CAMERA` permission to access UVC devices on Android9 / API 28 and later devices.
And app needs to request `CAMERA` runtime permission before using this UVC plugin(`UVCManager`/`UVCManagerPlatform`),
otherwise app never detects / uses UVC devices.

Please see basic implementation to request `CAMERA` runtime permission in example app.

### Handling USB access permission

* If user connect UVC device to the Android device, USB access permission automatically handled in backed libraries and after USB access permission granted, app receives `ATTACHED` event.
* If user disconnect UVC device from the Android device, app receives `DETACHED` event.
* App can monitor changes of connected UVC devices using `UVCManagerPlatform#addListener` with `VoidCallback`

## API references

### UVCManager / UVCManagerPlatform

* This class manages UVC devices and detect connect(attach) / disconnect(detach) event.
* App can use this as singleton pattern.

#### public functions

* `void addListener(VoidCallback listener)`
   Add `VoidCallback` to monitor changes of connected UVC device(s).
* `void removeListener(VoidCallback listener)`
  Remove `VoidCallback` to monitor changes of connected UVC device(s).
* `int getAvailableCount()`
  get number of connected UVC device(s).
* `List<UVCControllerInterface> getControllers()`
  get list of UVCControllerInterface related to connected UVC device(s)
* `UVCControllerInterface getControllerAt(int index)`
  get UVCControllerInterface related to connected UVC device
* `UVCControllerInterface getController(int deviceId)`
  get UVCControllerInterface related to connected UVC device
* `Future<Null> keepScreenOn(bool onoff) async`
  request to change state of keep screen on.

### UVCController / UVCControllerInterface

This class has following functions.

* start / stop video streaming from UVC device
* get supported video settings list
* apply video size setting to UVC device
* get current video size setting from UVC device
* get supported UVC control functions list from UVC device
* apply UVC control function value to UVC device
* get current UVC control function value from UVC device
* create / release texture to receive video images from UVC device

#### public functions

* `int get deviceId`
   get unique id to specify UVC device.
* `Future<void> detached() async`
  internally called when UVC device detached. App does not need to call this.
* `device_state state()`
  get current device state, the value is one of followings.
  | value         | note                          |
  |---------------|-------------------------------|
  | UNINITIALIZED | UVC device not connected      |
  | DISCONNECTED  | disconnected / detached       |
  | CONNECTED     | connected but not streaming   |
  | STREAMING     | connected and streaming       |
* `Future<int> start() async`
  start streaming / start getting video images from UVC device
* `Future<int> stop() async`
  stop streaming / stop getting video images from UVC device
* `Future<List<VideoSize>> getSupportedSize() async`
  get list of supported video settings as `List<VideoSize>`
* `Future<List<ControlInfo>> getSupportedControls() async`
  get list of supported UVC control functions as List<ControlInfo>
* `Future<VideoSize> setSize(int frameType, int width, int height) async`
  set video setting and return the actual selected video size
* `Future<VideoSize> getCurrentSize() async`
  get current video setting
* `Future<ControlInfo> setCtrlValue(int type, int value) async`
  apply UVC control value to UVC device and returns actual applied control value
  @param type specify which UVC control function to apply
  @param value value to apply
  Note: Some UVC control functions can only apply their value under specific conditions.
        Ex. Exposure time can be applied only when auto expose mode is off.
* `Future<ControlInfo> getCtrlValue(int type) async`
  get current value of specific UVC control function
  @param type specify which UVC control function to get value
* `DeviceInfo getDeviceInfo()`
  get information of UVC device as `DeviceInfo`
* `Future<int> createTexture(int width, int height) async`
  create texture to show video images from UVC device
* `Future<Null> releaseTexture() async`
  release texture to show video images from UVC device

### UVCVideoView

This class is a helper widget(`StatefulWidget`) to show video images from UVC device.

### DeviceInfo

This class holds the details about UVC device.
You can select one of multiple connected UVC devices, adjust the UI to suit the connected UVC device, and change the settings of the UVC control function to suit the connected UVC device.

```dart
final class DeviceInfo {
  /// Vendor id value
  final int vendorId;
  /// Product id value
  final  int productId;
  /// Sevice class value
  final int deviceClass;
  /// Sevice sub class value
  final int deviceSubClass;
  /// Sevice protocol value
  final  int deviceProtocol;
  /// USB device name, not a product name
  final String name;
  /// manifacture name, may be empty string on some device.
  final String manufacturerName;
  /// product name, may be empty string on some device.
  final String productName;
  /// Serial value, may be empty string on some device.
  final String serial;
  ...
}
```

### VideoSize

This class holds the details about video size settings.
Frame rate / frame intervals are just a hint that the UVC device can support and the actual frame rate come from the UVC device will vary depending on it condition, UVC control values, quality/spec/length of USB cable/adaptor and the spec of Android device etc.

```dart
class VideoSize {
  /// Frame type value, one of FRAME_TYPE_XXX
  final int frameType;

  /// Index of VideoSize, starting from 1
  final int frameIndex;

  /// Video size width, as number of pixels
  final int width;

  /// Video size height, as number of pixels
  final int height;

  /// Type of frame interval values
  /// 0: frame interval values are are triplet of min, max, and step.
  /// plus value: number of frame intervals
  final int frameIntervalType;

  /// List of frame interval values
  final List<int> frameIntervals;

  /// List of supported frame rate values, calculated from frameIntervalType and frameIntervals
  final List<double> fps;

  /// Number of frame rate values, calculated from frameIntervalType and frameIntervals
  final int numFps;

  /// Show whether this instance holds valid video size settings.
  bool isValid()
  ...
}
```

### ControlInfo

This class holds the UVC device control settings obtained from the UVC device.

```dart
class ControlInfo {
  /// The type that this instance hold(, one of FLG_CTRL_XXX or FLG_PU_XXX)
  final int type;

  /// Show this instance collectly initialized or not.
  final int initialized;

  /// Show this instance has min/max value. If this value is not zero, min / max values are valid.
  final int hasMinMax;

  /// Default value of this UVC control function.
  final int def;

  /// Resolution value
  final int res;

  /// Show min value if hasMinMax is not 0
  final int min;

  /// Show max value if hasMinMax is not 0
  final int max;

  /// Show this instance hold valid value
  bool isValid()

  /// Current value of this UVC control function
  int current;
  ...
 }
```

### Others

Example app includes some classes / widgets to help to manage UVC device, start / stop streaming, show / change UVC control functions.

## Supported video frame types

* Most UVC devices only support few frame types, MJPEG, YUYV(YUY2).
* Some frame types can't render/preview using this plugin.

| frame type                      | description                           |
|---------------------------------|---------------------------------------|
| FRAME_TYPE_UNKNOWN              | Unknown frame type (can't render)     |
| FRAME_TYPE_UNCOMPRESSED_YUYV    | YUYV/YUY2                             |
| FRAME_TYPE_UNCOMPRESSED_NV21    | NV21                                  |
| FRAME_TYPE_UNCOMPRESSED_NV12    | NV12                                  |
| FRAME_TYPE_UNCOMPRESSED_RGB565  | RGB565                                |
| FRAME_TYPE_UNCOMPRESSED_RGBX    | RGBX                                  |
| FRAME_TYPE_MJPEG                | MJPEG                                 |
| FRAME_TYPE_H264                 | H264                                  |

## Video size selection

* You can get which video size and frame types are supported on connected UVC device
  by calling `UVCController#getSupportedSize`.
* You can set video size and frame types by calling `UVCController#setSize`.
* You can get current selected video size and frame type by calling `UVCController#getCurrentSize`.

## UVC control functions

* You can get list which UVC control functions are supported on connected UVC device
  by calling `UVCController#getSupportedControls`.
* Example app does not support relative controls to keep example simple.
* You can see details about each control in UVC specification.

| Functions             | Description                     | Note         |
|-----------------------|---------------------------------|--------------|
| FLG_CTRL_SCANNING     | Scanning Mode                   |              |
| FLG_CTRL_AE           | Auto-Exposure Mode              | Note1        |
| FLG_CTRL_AE_PRIORITY  | Auto-Exposure Priority          | Note1        |
| FLG_CTRL_AE_ABS       | Exposure Time (Absolute)        | Note1        |
| FLG_CTRL_FOCUS_ABS    | Focus (Absolute)                |              |
| FLG_CTRL_IRIS_ABS	    | Iris (Absolute)                 | Note1        |
| FLG_CTRL_ZOOM_ABS	    | Zoom (Absolute)                 |              |
| FLG_CTRL_PAN_ABS      | PanTilt (Absolute)              |              |
| FLG_CTRL_TILT_ABS	    | PanTilt (Absolute)              |              |
| FLG_CTRL_ROLL_ABS	    | Roll (Absolute)                 |              |
| FLG_CTRL_FOCUS_AUTO   | Focus, Auto                     | Note2        |
| FLG_CTRL_PRIVACY      | Privacy                         |              |
| FLG_PU_BRIGHTNESS     | Brightness                      |              |
| FLG_PU_CONTRAST       | Contrast                        |              |
| FLG_PU_HUE            | Hue                             |              |
| FLG_PU_SATURATION     | Saturation                      |              |
| FLG_PU_SHARPNESS      | Sharpness                       | Note1        |
| FLG_PU_GAMMA          | Gamma                           | Note1        |
| FLG_PU_WB_TEMP        | White Balance Temperature       |              |
| FLG_PU_WB_COMPO       | White Balance Component         |              |
| FLG_PU_BACKLIGHT      | Backlight Compensation          |              |
| FLG_PU_GAIN           | Gain                            | Note1        |
| FLG_PU_POWER_LF       | Power Line Frequency            |              |
| FLG_PU_HUE_AUTO       | Hue, Auto                       | Note2        |
| FLG_PU_WB_TEMP_AUTO   | White Balance Temperature, Auto | Note2        |
| FLG_PU_WB_COMPO_AUTO  | White Balance Component, Auto   | Note2        |
| FLG_PU_CONTRAST_AUTO  | Contrast, Auto                  | Note2        |

* Note1: Auto-Exposure Mode, Auto-Exposure Priority, Exposure Time, Iris, Brightness,
  Gamma, Gain will depend on / be related to each other and may not be able to control under some conditions.
* Note2: Auto control(s) are combined into absolute controls on UI of example app.

## Version history

| version | short description                                            |
|---------|--------------------------------------------------------------|
| 1.0.0   | First release                                                |
| 1.1.0   | Use static libraries of aandusb to use NDK with flutter SDK. |
| 1.2.0   | Update backed libraries and Flutter SDK and AGP.             |
