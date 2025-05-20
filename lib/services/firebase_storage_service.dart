import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Service to fetch the SF2 soundfont from Firebase Storage using HTTP
class FirebaseStorageService {
  FirebaseStorageService._();
  static final instance = FirebaseStorageService._();
  
  // Default timeout duration
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Fetch the SF2 as bytes using HTTP GET
  Future<Uint8List?> fetchSoundfont() async {
    // URL pointing to the soundfont file in Firebase Storage
    const url = 'https://firebasestorage.googleapis.com/v0/b/finalproj-piano-game.appspot.com/o/piano_soundfont.sf2?alt=media';
    
    try {
      developer.log('Fetching soundfont from Firebase Storage');
      final resp = await http.get(Uri.parse(url))
          .timeout(_requestTimeout);
      
      if (resp.statusCode == 200) {
        developer.log('Fetched SF2 via HTTP (${resp.bodyBytes.lengthInBytes} bytes)');
        return resp.bodyBytes;
      }
      
      developer.log('HTTP fetch failed: ${resp.statusCode}');
      
      // If Firebase storage fails, try the server
      return _fetchFromServer();
    } on TimeoutException {
      developer.log('Firebase storage fetch timed out, trying server');
      return _fetchFromServer();
    } catch (e) {
      developer.log('Error fetching SF2 via HTTP: $e');
      
      // Try alternative source if Firebase fails
      return _fetchFromServer();
    }
  }
  
  /// Alternative method to fetch from the Flask server
  Future<Uint8List?> _fetchFromServer() async {
    const serverUrl = 'https://summer-heaven-460309-n7.uc.r.appspot.com/api/soundfonts/piano.sf2';
    
    try {
      developer.log('Attempting to fetch soundfont from server');
      final resp = await http.get(Uri.parse(serverUrl))
          .timeout(_requestTimeout);
      
      if (resp.statusCode == 200) {
        developer.log('Fetched SF2 from server (${resp.bodyBytes.lengthInBytes} bytes)');
        return resp.bodyBytes;
      }
      
      developer.log('Server fetch failed: ${resp.statusCode}');
      return null;
    } on TimeoutException {
      developer.log('Server soundfont fetch timed out');
      return null;
    } catch (e) {
      developer.log('Error fetching SF2 from server: $e');
      return null;
    }
  }
} 