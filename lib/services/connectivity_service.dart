import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      // If we can't check, assume online as fallback
      return true;
    }
  }

  Stream<List<ConnectivityResult>> get connectivityStream => 
      _connectivity.onConnectivityChanged;
}
