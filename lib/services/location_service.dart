import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('LOCATION: Services disabled, using fallback location.');
        return _fallbackPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('LOCATION: Permission denied, using fallback location.');
          return _fallbackPosition();
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('LOCATION: Permission denied forever, using fallback location.');
        return _fallbackPosition();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('LOCATION: GPS timed out, using fallback location.');
          throw Exception('timeout');
        },
      );
      return position;
    } catch (e) {
      print('LOCATION: Exception ($e), using fallback location.');
      return _fallbackPosition();
    }
  }

  // Fallback location (Dhaka, Bangladesh) — used only when real GPS
  // is unavailable, e.g. on emulators without a location fix set.
  static Position _fallbackPosition() {
    return Position(
      latitude: 23.8103,
      longitude: 90.4125,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  static double distanceInMiles(
      double lat1, double lon1, double lat2, double lon2) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1609.34;
  }
}