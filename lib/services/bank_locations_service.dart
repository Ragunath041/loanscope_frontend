import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class BankBranch {
  final String name;
  final String address;
  final LatLng location;
  final String bankName;
  final String? phoneNumber;
  final String? openingHours;
  final String? website;
  final String? logoUrl;

  BankBranch({
    required this.name,
    required this.address,
    required this.location,
    required this.bankName,
    this.phoneNumber,
    this.openingHours,
    this.website,
    this.logoUrl,
  });
}

class BankLocationsService {
  // Map of bank names to their branch locations
  static final Map<String, List<BankBranch>> _bankBranches = {
    'SBI': [
      BankBranch(
        name: 'SBI Main Branch',
        address: '11, Sansad Marg, New Delhi',
        location: LatLng(28.6234, 77.1945),
        bankName: 'SBI',
        phoneNumber: '+91-11-2334-5678',
        openingHours: 'Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
        website: 'https://www.sbi.co.in',
        logoUrl: 'assets/images/bank_logos/sbi.png',
      ),
      BankBranch(
        name: 'SBI Connaught Place Branch',
        address: 'Block N, Connaught Place, New Delhi',
        location: LatLng(28.6316, 77.2207),
        bankName: 'SBI',
        phoneNumber: '+91-11-2336-7890',
        openingHours: 'Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
        website: 'https://www.sbi.co.in',
        logoUrl: 'assets/images/bank_logos/sbi.png',
      ),
      BankBranch(
        name: 'SBI Karol Bagh Branch',
        address: '15A/56, Pusa Road, Karol Bagh, New Delhi',
        location: LatLng(28.6514, 77.1895),
        bankName: 'SBI',
        phoneNumber: '+91-11-2337-8901',
        openingHours: 'Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
        website: 'https://www.sbi.co.in',
        logoUrl: 'assets/images/bank_logos/sbi.png',
      ),
    ],
    'HDFC': [
      BankBranch(
        name: 'HDFC Bank',
        address: 'Iduvampalayam',
        location: LatLng(11.0897108, 77.3095086),
        bankName: 'HDFC',
        phoneNumber: '+91-422-2345-6789',
        openingHours: 'Monday - Friday: 9:30 AM - 4:30 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
        website: 'https://www.hdfcbank.com',
        logoUrl: 'assets/images/bank_logos/hdfc.png',
      ),
      BankBranch(
        name: 'HDFC Bank Andheri Branch',
        address: 'Andheri East, Mumbai',
        location: LatLng(19.1136, 72.8697),
        bankName: 'HDFC',
        phoneNumber: '+91-22-2345-6789',
        openingHours: 'Monday - Friday: 9:30 AM - 4:30 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
        website: 'https://www.hdfcbank.com',
        logoUrl: 'assets/images/bank_logos/hdfc.png',
      ),
      BankBranch(
        name: 'HDFC Bank Bandra Branch',
        address: 'Bandra West, Mumbai',
        location: LatLng(19.0596, 72.8295),
        bankName: 'HDFC',
        phoneNumber: '+91-22-2346-7890',
        openingHours: 'Monday - Friday: 9:30 AM - 4:30 PM\nSaturday: 10:00 AM - 2:00 PM\nSunday: Closed',
        website: 'https://www.hdfcbank.com',
        logoUrl: 'assets/images/bank_logos/hdfc.png',
      ),
    ],
    'Canara Bank': [
      BankBranch(
        name: 'Canara Bank Block-36 Branch',
        address: 'Mangalam Road, Tiruppur',
        location: LatLng(11.0996035, 77.3134403),
        bankName: 'Canara Bank',
      ),
      BankBranch(
        name: 'Canara Bank Sector-50 Branch',
        address: 'Sengunthapuram, Tiruppur',
        location: LatLng(11.1024, 77.3203),
        bankName: 'Canara Bank',
      ),
      BankBranch(
        name: 'Canara Bank Extension Branch',
        address: 'Palladam Road, Tiruppur',
        location: LatLng(11.0956, 77.3267),
        bankName: 'Canara Bank',
      ),
      BankBranch(
        name: 'Canara Bank Colony Branch',
        address: 'Avinashi Road, Tiruppur',
        location: LatLng(11.0892, 77.3421),
        bankName: 'Canara Bank',
      ),
    ],
    'ICICI': [
      BankBranch(
        name: 'ICICI Bank',
        address: 'Mangalam Road',
        location: LatLng(11.0986736,77.3165196),
        bankName: 'ICICI',
      ),
      BankBranch(
        name: 'ICICI Bank Mayur Vihar Branch',
        address: 'Mayur Vihar Phase 1, New Delhi',
        location: LatLng(28.6047, 77.2905),
        bankName: 'ICICI',
      ),
      BankBranch(
        name: 'ICICI Bank South Extension Branch',
        address: 'South Extension Part 2, New Delhi',
        location: LatLng(28.5708, 77.2232),
        bankName: 'ICICI',
      ),
    ],
    'Axis Bank': [
      BankBranch(
        name: 'Axis Bank Janakpuri Branch',
        address: 'Janakpuri District Center, New Delhi',
        location: LatLng(28.6292, 77.0806),
        bankName: 'Axis Bank',
      ),
      BankBranch(
        name: 'Axis Bank Preet Vihar Branch',
        address: 'Preet Vihar, New Delhi',
        location: LatLng(28.6386, 77.2918),
        bankName: 'Axis Bank',
      ),
      BankBranch(
        name: 'Axis Bank Greater Kailash Branch',
        address: 'Greater Kailash 1, New Delhi',
        location: LatLng(28.5414, 77.2324),
        bankName: 'Axis Bank',
      ),
    ],
    'Kotak': [
      BankBranch(
        name: 'Kotak Mahindra Bank Pitampura Branch',
        address: 'Pitampura, New Delhi',
        location: LatLng(28.6996, 77.1365),
        bankName: 'Kotak',
      ),
      BankBranch(
        name: 'Kotak Mahindra Bank Defence Colony Branch',
        address: 'Defence Colony, New Delhi',
        location: LatLng(28.5742, 77.2362),
        bankName: 'Kotak',
      ),
      BankBranch(
        name: 'Kotak Mahindra Bank Rohini Branch',
        address: 'Rohini Sector 3, New Delhi',
        location: LatLng(28.7158, 77.1149),
        bankName: 'Kotak',
      ),
    ],
    'IndusInd': [
      BankBranch(
        name: 'IndusInd Bank Rajouri Garden Branch',
        address: 'Rajouri Garden, New Delhi',
        location: LatLng(28.6472, 77.1186),
        bankName: 'IndusInd',
      ),
      BankBranch(
        name: 'IndusInd Bank Malviya Nagar Branch',
        address: 'Malviya Nagar, New Delhi',
        location: LatLng(28.5404, 77.2019),
        bankName: 'IndusInd',
      ),
      BankBranch(
        name: 'IndusInd Bank Shahdara Branch',
        address: 'Shahdara, New Delhi',
        location: LatLng(28.6772, 77.2916),
        bankName: 'IndusInd',
      ),
    ],
    'Bank of Baroda': [
      BankBranch(
        name: 'Bank of Baroda Patel Nagar Branch',
        address: 'Patel Nagar, New Delhi',
        location: LatLng(28.6426, 77.1683),
        bankName: 'Bank of Baroda',
      ),
      BankBranch(
        name: 'Bank of Baroda Saket Branch',
        address: 'Saket, New Delhi',
        location: LatLng(28.5237, 77.2108),
        bankName: 'Bank of Baroda',
      ),
      BankBranch(
        name: 'Bank of Baroda Ashok Vihar Branch',
        address: 'Ashok Vihar, New Delhi',
        location: LatLng(28.6931, 77.1745),
        bankName: 'Bank of Baroda',
      ),
    ],
  };

  // Method to get all branches for a specific bank
  static List<BankBranch> getBankBranches(String bankName) {
    return _bankBranches[bankName] ?? [];
  }

  // Method to find nearby branches based on current location
  static List<BankBranch> findNearbyBranches(
    String bankName,
    LatLng currentLocation,
    double radiusInKm,
  ) {
    // Get all branches for the specified bank
    List<BankBranch> allBranches = getBankBranches(bankName);

    // Filter branches by distance
    List<BankBranch> nearbyBranches = [];

    for (var branch in allBranches) {
      double distance = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        branch.location.latitude,
        branch.location.longitude,
      );

      if (distance <= radiusInKm) {
        nearbyBranches.add(branch);
      }
    }

    // Sort branches by distance from user
    nearbyBranches.sort((a, b) {
      double distanceA = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        a.location.latitude,
        a.location.longitude,
      );

      double distanceB = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        b.location.latitude,
        b.location.longitude,
      );

      return distanceA.compareTo(distanceB);
    });

    return nearbyBranches;
  }

  // Calculate distance between two coordinates using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Radius of the earth in km

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Get all available bank names
  static List<String> getAllBankNames() {
    return _bankBranches.keys.toList();
  }

  // Get total number of branches for all banks
  static int getTotalBranchCount() {
    int count = 0;
    _bankBranches.forEach((_, branches) {
      count += branches.length;
    });
    return count;
  }
}