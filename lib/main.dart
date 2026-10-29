import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Location Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LocationTrackerScreen(),
    );
  }
}

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  State<LocationTrackerScreen> createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  GoogleMapController? _mapController;
  Timer? _timer;
  Position? _currentPosition;
  final List<LatLng> _polylineCoordinates = [];

  static const LatLng _initialPosition = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStartTracking();
  }

  Future<void> _checkPermissionAndStartTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
      }
      return;
    }

    // Fetch initial location immediately on startup
    await _fetchCurrentLocation();

    // Periodic location updates every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchCurrentLocation();
    });
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final LatLng latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _polylineCoordinates.add(latLng);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = {};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'My Current Location',
            snippet:
                '${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
          ),
        ),
      );
    }

    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('tracking_polyline'),
        points: _polylineCoordinates,
        color: Colors.blue,
        width: 5,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Real-Time Location Tracker',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 2,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          if (_currentPosition != null) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                17,
              ),
            );
          }
        },
        markers: markers,
        polylines: polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
