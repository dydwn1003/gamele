import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/areas.dart';
import '../domain/situation.dart';

enum LocationFailure { serviceDisabled, denied, deniedForever, timeout }

class LocationResult {
  const LocationResult.success(UserLocation this.location) : failure = null;
  const LocationResult.failure(LocationFailure this.failure) : location = null;

  final UserLocation? location;
  final LocationFailure? failure;
}

/// geolocator 기반 위치 권한 요청 + 현재 위경도 획득
class LocationService {
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationFailure.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(LocationFailure.deniedForever);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final point = LatLng(pos.latitude, pos.longitude);
      return LocationResult.success(
        UserLocation(point: point, areaName: Areas.nameFor(point), source: LocationSource.gps),
      );
    } on LocationServiceDisabledException {
      return const LocationResult.failure(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      return const LocationResult.failure(LocationFailure.denied);
    } catch (_) {
      return const LocationResult.failure(LocationFailure.timeout);
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
