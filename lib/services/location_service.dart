import 'package:geolocator/geolocator.dart';

class LocationService {

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('LOCATION: Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('LOCATION: Permission denied by user.');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('LOCATION: Permission denied forever.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('LOCATION: GPS timed out.');
          throw Exception('timeout');
        },
      );
      return position;
    } catch (e) {
      print('LOCATION: Exception - $e');
      return null;
    }
  }

  static double distanceInMiles(
      double lat1, double lon1, double lat2, double lon2) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1609.34;
  }
}