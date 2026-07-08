import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ElevationScreen extends StatefulWidget {
  @override
  _ElevationScreenState createState() => _ElevationScreenState();
}

class _ElevationScreenState extends State<ElevationScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final List<LatLng> _polygonPoints = [];

  String _result = '';
  bool _loading = false;

  Future<void> fetchElevation() async {
    final lat = _latController.text.trim();
    final lng = _lngController.text.trim();

    if (lat.isEmpty || lng.isEmpty) {
      setState(() {
        _result = "Please enter both latitude and longitude.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = '';
    });

    final apiKey = "YOUR_GOOGLE_ELEVATION_API_KEY"; // Replace with your real API key
    final url = "https://maps.googleapis.com/maps/api/elevation/json?locations=$lat,$lng&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final elevation = data['results'][0]['elevation'];
        setState(() {
          _result = "Elevation: ${elevation.toStringAsFixed(2)} meters";
        });
      } else {
        setState(() {
          _result = "Error: ${data['status']}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Failed to get elevation data.";
      });
    }

    setState(() {
      _loading = false;
    });
  }

  void _addPointToPolygon() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      setState(() {
        _result = "Invalid latitude or longitude.";
      });
      return;
    }

    setState(() {
      _polygonPoints.add(LatLng(lat, lng));
      _result = "Point added to polygon. Total points: ${_polygonPoints.length}";
    });
  }

  void _calculatePolygonArea() {
    if (_polygonPoints.length < 3) {
      setState(() {
        _result = "Select at least 3 points to form a polygon.";
      });
      return;
    }

    double area = 0;
    for (int i = 0; i < _polygonPoints.length; i++) {
      final LatLng p1 = _polygonPoints[i];
      final LatLng p2 = _polygonPoints[(i + 1) % _polygonPoints.length];
      area += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }

    area = area.abs() / 2 * 111139 * 111139; // Rough conversion to m²
    setState(() {
      _result = "Polygon Area: ${area.toStringAsFixed(2)} m²";
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _result = "Polygon points cleared.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Elevation & Area Checker")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _latController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Latitude"),
              ),
              TextField(
                controller: _lngController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "Longitude"),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: fetchElevation,
                      child: _loading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("Get Elevation"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addPointToPolygon,
                      child: Text("Add to Polygon"),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _calculatePolygonArea,
                      child: Text("Calculate Area"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearPolygon,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: Text("Clear Polygon"),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(_result, style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}
