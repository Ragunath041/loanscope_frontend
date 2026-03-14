import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:loanscope/services/bank_locations_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BankMap extends StatefulWidget {
  final Position? currentPosition;
  final String bankName;
  final bool isLoading;

  const BankMap({
    Key? key,
    required this.currentPosition,
    this.bankName = '',
    this.isLoading = false,
  }) : super(key: key);

  @override
  _BankMapState createState() => _BankMapState();
}

class _BankMapState extends State<BankMap> with SingleTickerProviderStateMixin {
  flutter_map.MapController mapController = flutter_map.MapController();
  List<BankBranch> nearbyBranches = [];
  final double searchRadiusInKm = 20.0; // Search within 20 km instead of 10km
  double currentZoom = 10.0;

  // Map type options
  final List<String> mapTypes = ['Standard', 'Satellite', 'Terrain'];
  String currentMapType = 'Standard';

  // Selected branch
  BankBranch? selectedBranch;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<BankBranch> _searchResults = [];

  // Animation controller for branch details panel
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for the branch details panel
    _panelController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _panelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _panelController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || widget.currentPosition == null) {
      return Center(child: CircularProgressIndicator());
    }

    // Use exact coordinates from position without any modification
    final exactLatitude = widget.currentPosition!.latitude;
    final exactLongitude = widget.currentPosition!.longitude;

    print("BankMap using EXACT location: $exactLatitude, $exactLongitude");

    // Create markers for the current location and nearby bank branches
    final myExactLocation = LatLng(exactLatitude, exactLongitude);

    // Find nearby branches for the specified bank using our radius
    if (widget.bankName.isNotEmpty) {
      // Try to find branches within the search radius
      nearbyBranches = BankLocationsService.findNearbyBranches(
        widget.bankName,
        myExactLocation,
        searchRadiusInKm
      );

      print("Found ${nearbyBranches.length} branches for ${widget.bankName} within ${searchRadiusInKm}km");

      // If no branches found within radius, try getting all branches
      if (nearbyBranches.isEmpty) {
        List<BankBranch> allBranches = BankLocationsService.getBankBranches(widget.bankName);
        print("No branches within ${searchRadiusInKm}km. Total available branches: ${allBranches.length}");

        // Use all branches if there are any
        if (allBranches.isNotEmpty) {
          nearbyBranches = allBranches;
          print("Showing all ${nearbyBranches.length} branches for ${widget.bankName}");
        } else {
          // If still no branches, use fallback
          print("No branches found for ${widget.bankName}. Using fallback bank locations.");
          nearbyBranches = _generateFallbackBranches(
            exactLatitude,
            exactLongitude,
            widget.bankName,
            8 // Generate more branches
          );
        }
      }
    } else {
      // If no bank name provided, use fallback with more branches
      nearbyBranches = _generateFallbackBranches(
        exactLatitude,
        exactLongitude,
        "Bank",
        8
      );
    }

    // Create markers list
    List<flutter_map.Marker> markers = [
      // User's current location marker
      flutter_map.Marker(
        width: 40.0,
        height: 40.0,
        point: myExactLocation,
        child: Container(
          child: Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 30.0,
          ),
        ),
      ),
    ];

    // Add bank branch markers with tooltip
    for (var branch in nearbyBranches) {
      // Calculate distance from user to this branch
      double distance = BankLocationsService.calculateDistance(
        myExactLocation.latitude,
        myExactLocation.longitude,
        branch.location.latitude,
        branch.location.longitude
      );

      markers.add(
        flutter_map.Marker(
          width: 80.0,
          height: 65.0,
          point: branch.location,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedBranch = branch;
              });
              _panelController.forward();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: BoxConstraints(maxWidth: 75),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        branch.name,
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        "${distance.toStringAsFixed(1)}km",
                        style: GoogleFonts.poppins(
                          fontSize: 7,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selectedBranch == branch ? Color(0xFF6A82FB) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: selectedBranch == branch ? Colors.white : Color(0xFF6A82FB),
                    size: 20.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Add a circle showing the 20km radius
    final radiusLayer = flutter_map.CircleLayer(
      circles: [
        flutter_map.CircleMarker(
          point: myExactLocation,
          radius: 20000, // 20km in meters
          color: Colors.blue.withOpacity(0.15),
          borderColor: Colors.blue.withOpacity(0.5),
          borderStrokeWidth: 2,
        ),
      ],
    );

    // Get the appropriate tile layer based on map type
    flutter_map.TileLayer getTileLayer() {
      switch (currentMapType) {
        case 'Satellite':
          return flutter_map.TileLayer(
            urlTemplate: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
            userAgentPackageName: 'com.example.loanscope',
          );
        case 'Terrain':
          return flutter_map.TileLayer(
            urlTemplate: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
            userAgentPackageName: 'com.example.loanscope',
          );
        case 'Standard':
        default:
          return flutter_map.TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.loanscope',
          );
      }
    }

    return Stack(
      children: [
        // Search bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for banks or locations...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _isSearching = false;
                          _searchResults.clear();
                        });
                      },
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                if (value.length > 2) {
                  _searchBanks(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _isSearching = false;
                    _searchResults.clear();
                  });
                }
              },
            ),
          ),
        ),

        // Search results
        if (_isSearching && _searchResults.isNotEmpty)
          Positioned(
            top: 70,
            left: 16,
            right: 16,
            child: Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final branch = _searchResults[index];
                  return ListTile(
                    title: Text(
                      branch.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      branch.address,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: Icon(Icons.account_balance),
                    onTap: () {
                      // Center map on this branch
                      mapController.move(branch.location, 15.0);
                      setState(() {
                        selectedBranch = branch;
                        _isSearching = false;
                        _searchResults.clear();
                        _searchController.clear();
                      });
                      _panelController.forward();
                    },
                  );
                },
              ),
            ),
          ),
        flutter_map.FlutterMap(
          mapController: mapController,
          options: flutter_map.MapOptions(
            initialCenter: myExactLocation,
            initialZoom: 9.0, // Start with a wider view to see the 20km radius
            minZoom: 3.0,
            maxZoom: 18.0,
            onMapReady: () {
              try {
                // If we have branches, fit bounds to include all branches and user location
                if (nearbyBranches.isNotEmpty) {
                  // Collect all points including user location
                  List<LatLng> points = [myExactLocation];
                  points.addAll(nearbyBranches.map((branch) => branch.location));

                  // Calculate bounds
                  double minLat = points.map((p) => p.latitude).reduce(math.min);
                  double maxLat = points.map((p) => p.latitude).reduce(math.max);
                  double minLng = points.map((p) => p.longitude).reduce(math.min);
                  double maxLng = points.map((p) => p.longitude).reduce(math.max);

                  // Add padding to bounds
                  double latPadding = (maxLat - minLat) * 0.1;
                  double lngPadding = (maxLng - minLng) * 0.1;

                  print("Map bounds: from ($minLat,$minLng) to ($maxLat,$maxLng)");

                  // Calculate the center and appropriate zoom level
                  double centerLat = (minLat + maxLat) / 2;
                  double centerLng = (minLng + maxLng) / 2;

                  // Move to the center
                  LatLng center = LatLng(centerLat, centerLng);

                  // Calculate appropriate zoom level based on the distance
                  double latDistance = (maxLat - minLat).abs();
                  double lngDistance = (maxLng - minLng).abs();
                  double maxDistance = math.max(latDistance, lngDistance);

                  // Approximate zoom level calculation (lower means more zoomed out)
                  double zoomLevel = maxDistance <= 0.01 ? 14.0 :  // Very close
                                    maxDistance <= 0.1 ? 12.0 :  // Close
                                    maxDistance <= 1.0 ? 10.0 :  // Medium
                                    maxDistance <= 5.0 ? 8.0 :   // Far
                                    maxDistance <= 10.0 ? 6.0 :  // Very far
                                    4.0;                         // Extremely far

                  setState(() {
                    currentZoom = zoomLevel;
                  });

                  mapController.move(center, zoomLevel);
                  print("Map centered at $centerLat, $centerLng with zoom $zoomLevel");
                } else {
                  // If no branches, just center on user
                  setState(() {
                    currentZoom = 9.0;
                  });
                  mapController.move(myExactLocation, 9.0);
                  print("Map centered on user location only: ${myExactLocation.latitude}, ${myExactLocation.longitude}");
                }
              } catch (e) {
                print("Error adjusting map: $e");
                // Fallback to just centering on user
                setState(() {
                  currentZoom = 9.0;
                });
                mapController.move(myExactLocation, 9.0);
              }
            },
          ),
          children: [
            getTileLayer(),
            radiusLayer, // Show the 20km radius
            flutter_map.MarkerLayer(markers: markers),
          ],
        ),
        // Add map controls
        Positioned(
          right: 16,
          bottom: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom in button
              _buildControlButton(
                icon: Icons.add,
                onPressed: () {
                  setState(() {
                    currentZoom = math.min(18.0, currentZoom + 1.0);
                  });
                  mapController.move(mapController.camera.center, currentZoom);
                },
              ),
              SizedBox(height: 8),
              // Zoom out button
              _buildControlButton(
                icon: Icons.remove,
                onPressed: () {
                  setState(() {
                    currentZoom = math.max(3.0, currentZoom - 1.0);
                  });
                  mapController.move(mapController.camera.center, currentZoom);
                },
              ),
              SizedBox(height: 8),
              // My location button
              _buildControlButton(
                icon: Icons.my_location,
                onPressed: () {
                  if (widget.currentPosition != null) {
                    final myLocation = LatLng(
                      widget.currentPosition!.latitude,
                      widget.currentPosition!.longitude
                    );
                    mapController.move(myLocation, 14.0);
                  }
                },
              ),
              SizedBox(height: 8),
              // Map type selector
              _buildControlButton(
                icon: Icons.layers,
                onPressed: () {
                  _showMapTypeSelector(context);
                },
              ),
            ],
          ),
        ),
        // Add radius indicator
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.radar,
                  size: 16,
                  color: Color(0xFF6A82FB),
                ),
                SizedBox(width: 4),
                Text(
                  "20km Radius Search",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A82FB),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Branch details panel (slides up when a branch is selected)
        if (selectedBranch != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _panelAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _panelAnimation.value) * 200),
                  child: child,
                );
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            selectedBranch!.name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            _panelController.reverse().then((_) {
                              setState(() {
                                selectedBranch = null;
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            selectedBranch!.address,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        // Call button (mock)
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.phone),
                            label: Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              // Use actual phone number if available
                              _launchUrl('tel:${selectedBranch!.phoneNumber ?? "+91-1800-1234-5678"}');
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        // Directions button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.directions),
                            label: Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6A82FB),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _openDirections(
                                selectedBranch!.location.latitude,
                                selectedBranch!.location.longitude,
                                selectedBranch!.name
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Bank hours
                    Text(
                      'Opening Hours',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      selectedBranch!.openingHours ?? 'Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),

                    if (selectedBranch!.website != null) ...[
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: Icon(Icons.language),
                        label: Text('Visit Website'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          _launchUrl(selectedBranch!.website!);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Helper method to build control buttons
  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  // Show map type selector dialog
  void _showMapTypeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Map Type',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: mapTypes.map((type) =>
            RadioListTile<String>(
              title: Text(type),
              value: type,
              groupValue: currentMapType,
              onChanged: (value) {
                setState(() {
                  currentMapType = value!;
                });
                Navigator.pop(context);
              },
            ),
          ).toList(),
        ),
      ),
    );
  }

  // Launch URL helper
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  // Search for banks by name or address
  void _searchBanks(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    // Get all bank names
    List<String> allBankNames = BankLocationsService.getAllBankNames();
    List<BankBranch> results = [];

    // First, check if query matches any bank names
    for (String bankName in allBankNames) {
      if (bankName.toLowerCase().contains(query.toLowerCase())) {
        // Add all branches of this bank
        results.addAll(BankLocationsService.getBankBranches(bankName));
      }
    }

    // Then search through all branches for name or address matches
    for (String bankName in allBankNames) {
      List<BankBranch> branches = BankLocationsService.getBankBranches(bankName);
      for (BankBranch branch in branches) {
        // Check if branch name or address contains the query
        if (branch.name.toLowerCase().contains(query.toLowerCase()) ||
            branch.address.toLowerCase().contains(query.toLowerCase())) {
          // Only add if not already in results
          if (!results.contains(branch)) {
            results.add(branch);
          }
        }
      }
    }

    // If we have results from nearby branches, prioritize them
    if (widget.currentPosition != null && results.isNotEmpty) {
      final myLocation = LatLng(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude
      );

      // Sort by distance
      results.sort((a, b) {
        double distanceA = BankLocationsService.calculateDistance(
          myLocation.latitude,
          myLocation.longitude,
          a.location.latitude,
          a.location.longitude,
        );

        double distanceB = BankLocationsService.calculateDistance(
          myLocation.latitude,
          myLocation.longitude,
          b.location.latitude,
          b.location.longitude,
        );

        return distanceA.compareTo(distanceB);
      });
    }

    // Limit results to top 10
    if (results.length > 10) {
      results = results.sublist(0, 10);
    }

    setState(() {
      _isSearching = true;
      _searchResults = results;
    });
  }

  // Open directions in maps app
  void _openDirections(double lat, double lng, String name) async {
    final encodedName = Uri.encodeComponent(name);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$encodedName';
    _launchUrl(url);
  }

  // Generate fallback branches only when no real branches are found
  List<BankBranch> _generateFallbackBranches(
    double latitude,
    double longitude,
    String bankName,
    int count
  ) {
    final List<BankBranch> locations = [];
    // Generate branches within the 20km radius
    final double radiusInMeters = 20000; // 20km radius

    // Indian area/locality names
    final List<String> areas = [
      'Sector', 'Block', 'Colony', 'Nagar', 'Puram', 'Extension',
      'Main', 'Central', 'Bazar', 'Market', 'Commercial', 'Industrial'
    ];

    // Indian street names
    final List<String> streets = [
      'MG Road', 'Station Road', 'Gandhi Street', 'Nehru Road',
      'Rajaji St', 'Patel Road', 'Temple Street', 'Church St',
      'Bazaar Rd', 'College Road', 'Hospital Rd', 'Shivaji Marg'
    ];

    print('Generating fallback bank branches near: $latitude, $longitude');

    // Use the Random class with a seed based on latitude+longitude to ensure consistency
    final random = math.Random((latitude * 1000000 + longitude * 1000000).toInt());

    // Generate Indian-style branch names with area numbers
    for (int i = 0; i < count; i++) {
      // Convert meters to degrees (approximately)
      double metersToDegreesLat = radiusInMeters / 111000; // 1 degree = 111km approximately for latitude
      double metersToDegreesLng = radiusInMeters / (111000 * math.cos(latitude * (math.pi / 180))); // Adjust for longitude

      // Generate random offset within the radius
      double randomDistanceFactor = random.nextDouble(); // 0 to 1
      double randomAngle = random.nextDouble() * 2 * math.pi; // 0 to 2π

      // Calculate position using the random distance and angle
      double offsetLat = metersToDegreesLat * randomDistanceFactor * math.sin(randomAngle);
      double offsetLng = metersToDegreesLng * randomDistanceFactor * math.cos(randomAngle);

      // Use random area and street names for realistic branch names in Indian context
      String area = areas[random.nextInt(areas.length)];
      String street = streets[random.nextInt(streets.length)];
      int sectorNumber = random.nextInt(50) + 1;

      String branchName = '$bankName ${area == 'Sector' || area == 'Block' ?
        "$area-$sectorNumber" : area} Branch';

      String address = '${random.nextInt(500) + 100}, ${area == 'Sector' || area == 'Block' ?
        "$area-$sectorNumber" : area}, $street';

      // Generate mock phone number
      String phoneNumber = '+91-${random.nextInt(900) + 100}-${random.nextInt(9000) + 1000}-${random.nextInt(9000) + 1000}';

      // Generate mock opening hours
      String openingHours = 'Monday - Friday: ${random.nextInt(3) + 8}:00 AM - ${random.nextInt(3) + 4}:00 PM\n'
                          + 'Saturday: ${random.nextInt(3) + 9}:00 AM - ${random.nextInt(2) + 1}:00 PM\n'
                          + 'Sunday: Closed';

      // Generate mock website
      String website = 'https://www.${bankName.toLowerCase().replaceAll(' ', '')}.com';

      locations.add(
        BankBranch(
          name: branchName,
          address: address,
          location: LatLng(latitude + offsetLat, longitude + offsetLng),
          bankName: bankName,
          phoneNumber: phoneNumber,
          openingHours: openingHours,
          website: website,
        )
      );
    }

    return locations;
  }
}