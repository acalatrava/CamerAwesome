import 'dart:html' as html;

import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/src/web/src/expections_handler.dart';
import 'package:camerawesome/src/web/src/models/camera_options.dart';
import 'package:camerawesome/src/web/src/models/exceptions/camera_error_code.dart';
import 'package:camerawesome/src/web/src/models/exceptions/camera_web_exception.dart';
import 'package:flutter/services.dart';

class CameraWebService {
  html.Window? get window => html.window;
  html.MediaDevices? get mediaDevices => html.window.navigator.mediaDevices;

  Future<html.MediaStream> getVideoStream(
      final CameraOptions cameraOptions) async {
    // Throw a not supported exception if the current browser window
    // does not support any media devices.
    if (mediaDevices == null) {
      throw PlatformException(
        code: CameraErrorCode.notSupported.code,
        message: 'The camera is not supported on this device.',
      );
    }
    try {
      final html.MediaStream cameraStream =
          await mediaDevices!.getUserMedia(cameraOptions.toJson());
      return cameraStream;
    } on html.DomException catch (e) {
      throw handleDomException(e);
    } catch (_) {
      throw CameraWebException(
        0,
        CameraErrorCode.unknown,
        'An unknown error occured when fetching the camera stream.',
      );
    }
  }

  Future<List<String>> availableCameras() async {
    final List<String> camerasIds = <String>[];
    // Throw a not supported exception if the current browser window
    // does not support any media devices.
    if (mediaDevices == null) {
      throw PlatformException(
        code: CameraErrorCode.notSupported.toString(),
        message: 'The camera is not supported on this device.',
      );
    }

    // Request available media devices.
    final List<dynamic> devices = await mediaDevices!.enumerateDevices();

    // Filter video input devices.
    final Iterable<html.MediaDeviceInfo> videoInputDevices = devices
        .whereType<html.MediaDeviceInfo>()
        .where((html.MediaDeviceInfo device) => device.kind == 'videoinput')

        /// The device id property is currently not supported on Internet Explorer:
        /// https://developer.mozilla.org/en-US/docs/Web/API/MediaDeviceInfo/deviceId#browser_compatibility
        .where(
          (html.MediaDeviceInfo device) =>
              device.deviceId != null && device.deviceId!.isNotEmpty,
        );

    // Map video input devices to camera descriptions.
    for (final html.MediaDeviceInfo videoInputDevice in videoInputDevices) {
      // Get the video stream for the current video input device
      // to later use for the available video tracks.

      final CameraOptions cameraOptions = CameraOptions(
        video: VideoConstraints(deviceId: videoInputDevice.deviceId),
      );

      final html.MediaStream videoStream = await getVideoStream(cameraOptions);

      // Get all video tracks in the video stream
      // to later extract the lens direction from the first track.
      final List<html.MediaStreamTrack> videoTracks =
          videoStream.getVideoTracks();

      if (videoTracks.isEmpty) {
        continue;
      }

      camerasIds.add(videoInputDevice.deviceId!);

      // Release the camera stream of the current video input device.
      for (final html.MediaStreamTrack videoTrack in videoTracks) {
        videoTrack.stop();
      }
    }

    return camerasIds;
  }

  ///
  /// PERMISSIONS
  ///
  Future<List<String>> checkPermissions() async {
    html.PermissionStatus? cameraStatus =
        await window?.navigator.permissions?.query({
      'name': "camera",
    });
    html.PermissionStatus? microphoneStatus =
        await window?.navigator.permissions?.query({
      'name': "microphone",
    });
    final permissions = <String>[];
    if (cameraStatus?.state == 'granted') {
      permissions.add(CamerAwesomePermission.camera.name);
    }

    if (microphoneStatus?.state == 'granted') {
      permissions.add(CamerAwesomePermission.record_audio.name);
    }
    return permissions;
  }

  Future<List<String>> requestPermissions() async {
    const cameraOptions = CameraOptions(
      audio: AudioConstraints(enabled: true),
    );
    final html.MediaStream cameraStream = await getVideoStream(cameraOptions);

    // Release the camera stream used to request video and audio permissions.
    cameraStream.getVideoTracks().forEach((videoTrack) => videoTrack.stop());
    return [
      CamerAwesomePermission.camera.name,
      CamerAwesomePermission.record_audio.name
    ];
  }
}