import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum AppPermissionType { notifications, camera, photos, files }

enum AppPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unknown,
}

class AppPermissionStatus {
  const AppPermissionStatus({required this.type, required this.state});

  final AppPermissionType type;
  final AppPermissionState state;

  bool get granted =>
      state == AppPermissionState.granted ||
      state == AppPermissionState.limited;
}

class AppPermissionCoordinator {
  Future<AppPermissionStatus> check(AppPermissionType type) async {
    final permission = _mapPermission(type);
    final status = await permission.status;
    return AppPermissionStatus(type: type, state: _mapState(status));
  }

  Future<AppPermissionStatus> requestOnDemand(AppPermissionType type) async {
    final permission = _mapPermission(type);
    final status = await permission.request();
    return AppPermissionStatus(type: type, state: _mapState(status));
  }

  Future<List<AppPermissionStatus>> readStatuses() async {
    return [
      await check(AppPermissionType.notifications),
      await check(AppPermissionType.camera),
      await check(AppPermissionType.photos),
      await check(AppPermissionType.files),
    ];
  }

  Future<bool> openSettings() => openAppSettings();

  Permission _mapPermission(AppPermissionType type) {
    return switch (type) {
      AppPermissionType.notifications => Permission.notification,
      AppPermissionType.camera => Permission.camera,
      AppPermissionType.photos =>
        Platform.isIOS ? Permission.photos : Permission.photos,
      AppPermissionType.files => _filesPermission(),
    };
  }

  Permission _filesPermission() {
    return Permission.storage;
  }

  AppPermissionState _mapState(PermissionStatus status) {
    if (status.isGranted) {
      return AppPermissionState.granted;
    }
    if (status.isDenied) {
      return AppPermissionState.denied;
    }
    if (status.isPermanentlyDenied) {
      return AppPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return AppPermissionState.restricted;
    }
    if (status.isLimited) {
      return AppPermissionState.limited;
    }
    return AppPermissionState.unknown;
  }
}
