import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _timer;

  // Initialize and start location updates
  Future<void> init() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) print('[LocationService] Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print('[LocationService] Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) print('[LocationService] Location permissions are permanently denied.');
      return;
    } 

    if (kDebugMode) print('[LocationService] Location permission granted. Starting updates.');
    
    // Initial fetch
    _updateLocation();

    // Periodic update every 5 minutes
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      
      if (kDebugMode) {
        print('[LocationService] Updated location: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      if (kDebugMode) print('[LocationService] Error updating location: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
