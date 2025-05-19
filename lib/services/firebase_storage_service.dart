import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service to fetch the SF2 soundfont from Firebase Storage using HTTP
class FirebaseStorageService {
  FirebaseStorageService._();
  static final instance = FirebaseStorageService._();

  /// Fetch the SF2 as bytes using HTTP GET
  Future<Uint8List?> fetchSoundfont() async {
    const url = 'https://firebasestorage.googleapis.com/v0/b/finalproj-piano-game.appspot.com/o/piano_soundfont.sf2?alt=media';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        developer.log('Fetched SF2 via HTTP (${resp.bodyBytes.lengthInBytes} bytes)');
        return resp.bodyBytes;
      }
      developer.log('HTTP fetch failed: ${resp.statusCode}');
      return null;
    } catch (e) {
      developer.log('Error fetching SF2 via HTTP: $e');
      return null;
    }
  }
} 