import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Land Analysis',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  List<LatLng> _polygonPoints = [];
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  String _elevationResult = "";
  LatLng _currentCenter = _initialPosition;

  static const LatLng _initialPosition = LatLng(20.5937, 78.9629);
  static const String _apiKey = "AIzaSyCsn6y9yauYUoh_46MiB-pVeJcNLUbi0Fk";

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Opens the bottom sheet to enter latitude and longitude and navigate
  void _openBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter Latitude & Longitude", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _latController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _lngController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _goToEnteredLocation,
                child: const Text("Go to Location"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _calculateAverageElevation,
                child: const Text("Calculate Elevation"),
              ),
              ElevatedButton(
                onPressed: _calculatePolygonArea,
                child: const Text("Calculate Area"),
              ),
              ElevatedButton(
                onPressed: _calculateDepth,
                child: const Text("Calculate Depth"),
              ),
              if (_elevationResult.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(_elevationResult),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Navigate to the location entered in the bottom sheet
  void _goToEnteredLocation() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat != null && lng != null) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 10),
        ),
      );
      setState(() {
        _currentCenter = LatLng(lat, lng);
      });
      Navigator.pop(context); // Close the bottom sheet after navigation
    }
  }

  // Handle the map tap to add polygon points
  void _onMapTapped(LatLng point) {
    setState(() {
      _polygonPoints.add(point);
      _updatePolygonAndMarkers();
      _currentCenter = point;  // Directly updating current center here
    });
  }

  // Update the polygon and markers
  void _updatePolygonAndMarkers() {
    _polygons = {
      Polygon(
        polygonId: const PolygonId('selected_area'),
        points: _polygonPoints,
        strokeColor: Colors.blue,
        strokeWidth: 2,
        fillColor: Colors.blue.withOpacity(0.3),
      ),
    };

    _markers = {
      for (int i = 0; i < _polygonPoints.length; i++)
        Marker(
          markerId: MarkerId('point_$i'),
          position: _polygonPoints[i],
          draggable: true,
          onDragEnd: (newPos) {
            setState(() {
              _polygonPoints[i] = newPos;
              _updatePolygonAndMarkers();
            });
          },
        )
    };
  }

  // Clear polygon
  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _polygons.clear();
      _markers.clear();
      _elevationResult = "";
    });
  }

  // Calculate the average elevation of the polygon
  Future<void> _calculateAverageElevation() async {
    if (_polygonPoints.length < 3) {
      setState(() {
        _elevationResult = "Select at least 3 points to form a polygon.";
      });
      return;
    }

    final locations = _polygonPoints.map((p) => "${p.latitude},${p.longitude}").join("|");
    final url = "https://maps.googleapis.com/maps/api/elevation/json?locations=$locations&key=$_apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final elevations = data['results'].map((r) => r['elevation'] as double).toList();
        final avgElevation = elevations.reduce((a, b) => a + b) / elevations.length;
        setState(() {
          _elevationResult = "Average Elevation: ${avgElevation.toStringAsFixed(2)} meters";
        });
      } else {
        setState(() {
          _elevationResult = "Error: ${data['status']}";
        });
      }
    } catch (e) {
      setState(() {
        _elevationResult = "Failed to fetch elevation data.";
      });
    }
  }

  // Calculate the area of the polygon
  void _calculatePolygonArea() {
    if (_polygonPoints.length < 3) {
      setState(() {
        _elevationResult = "Select at least 3 points to form a polygon.";
      });
      return;
    }

    double area = 0;
    for (int i = 0; i < _polygonPoints.length; i++) {
      final LatLng p1 = _polygonPoints[i];
      final LatLng p2 = _polygonPoints[(i + 1) % _polygonPoints.length];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }

    area = area.abs() / 2 * 111139 * 111139; // Rough conversion for lat/long to meters²
    setState(() {
      _elevationResult = "Polygon Area: ${area.toStringAsFixed(2)} m²";
    });
  }

  Future<void> _calculateDepth() async {
    if (_polygonPoints.length < 3) {
      setState(() {
        _elevationResult = "Select at least 3 points to form a polygon.";
      });
      return;
    }

    final locations = _polygonPoints.map((p) => "${p.latitude},${p.longitude}").join("|");
    final url = Uri.parse("https://maps.googleapis.com/maps/api/elevation/json?locations=$locations&key=$_apiKey");

    print("Elevation API URL: $url"); // Debug log

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        setState(() {
          _elevationResult = "HTTP Error: ${response.statusCode}";
        });
        return;
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        List results = data['results'];
        List<double> elevations = results.map((r) => (r['elevation'] as num).toDouble()).toList();

        double maxElevation = elevations.reduce((a, b) => a > b ? a : b);
        double minElevation = elevations.reduce((a, b) => a < b ? a : b);
        double depth = maxElevation - minElevation;

        setState(() {
          _elevationResult =
          "Depth: ${depth.toStringAsFixed(2)} m\nMax Elevation: ${maxElevation.toStringAsFixed(2)} m\nMin Elevation: ${minElevation.toStringAsFixed(2)} m";
        });
      } else {
        setState(() {
          _elevationResult = "API Error: ${data['status']}";
        });
      }
    } catch (e) {
      setState(() {
        _elevationResult = "Failed to fetch elevation data: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Google Map + Elevation"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 5.5,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              onTap: (point) {
                _onMapTapped(point);  // Handle map tap to add points and update center
              },
              polygons: _polygons,
              markers: _markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _openBottomSheet,
                  icon: const Icon(Icons.settings),
                  label: const Text("Open Tools"),
                ),
                ElevatedButton.icon(
                  onPressed: _clearPolygon,
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear Polygon"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
