import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';

class FakeAppPermissionCoordinator extends AppPermissionCoordinator {
  FakeAppPermissionCoordinator({
    Map<AppPermissionType, AppPermissionState> states = const {},
  }) : _states = Map<AppPermissionType, AppPermissionState>.from(states);

  final Map<AppPermissionType, AppPermissionState> _states;
  int openSettingsCalls = 0;

  @override
  Future<AppPermissionStatus> requestOnDemand(AppPermissionType type) async {
    return AppPermissionStatus(type: type, state: _stateFor(type));
  }

  @override
  Future<AppPermissionStatus> check(AppPermissionType type) async {
    return AppPermissionStatus(type: type, state: _stateFor(type));
  }

  @override
  Future<List<AppPermissionStatus>> readStatuses({
    List<AppPermissionType> types = const [
      AppPermissionType.notifications,
      AppPermissionType.camera,
      AppPermissionType.microphone,
      AppPermissionType.photos,
      AppPermissionType.videos,
    ],
  }) async {
    return [
      for (final type in types)
        AppPermissionStatus(type: type, state: _stateFor(type)),
    ];
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }

  AppPermissionState _stateFor(AppPermissionType type) {
    return _states[type] ?? AppPermissionState.granted;
  }
}
