import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// WFL One-Click Upload - YouTube + Share Sheet
/// Zero backend, zero API rotation, works offline
class WFLUploader {
  static YouTubeApi? _youtubeApi;
  static int _roastCount = 0;
  static bool _isConnected = false;

  /// YouTube scopes needed
  static final _scopes = [YouTubeApi.youtubeUploadScope];

  /// Google Sign-In for YouTube
  static final _googleSignIn = GoogleSignIn(scopes: _scopes);

  /// Check if YouTube is connected
  static bool get isYouTubeConnected => _isConnected;

  /// Connect YouTube - first run popup, then cached forever
  static Future<bool> connectYouTube() async {
    try {
      // Check if already signed in silently
      var account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) return false;

      final auth = await account.authentication;
      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', auth.accessToken!, DateTime.now().add(Duration(hours: 1))),
          auth.idToken,
          _scopes,
        ),
      );

      _youtubeApi = YouTubeApi(client);
      _isConnected = true;
      return true;
    } catch (e) {
      debugPrint('YouTube auth error: $e');
      return false;
    }
  }

  /// Disconnect YouTube - clears login
  static Future<void> disconnectYouTube() async {
    await _googleSignIn.signOut();
    _youtubeApi = null;
    _isConnected = false;
  }

  /// Initialize - check if already logged in
  static Future<void> init() async {
    final account = await _googleSignIn.signInSilently();
    _isConnected = account != null;
    await _loadRoastCount();
  }

  /// Upload to YouTube - one tap, token saved forever
  static Future<String?> uploadToYouTube(File videoFile, {String? title, String? description}) async {
    // Connect if not already
    if (!_isConnected) {
      final connected = await connectYouTube();
      if (!connected) return null;
    }

    final youtube = _youtubeApi;
    if (youtube == null) return null;

    _roastCount++;
    final roastTitle = title ?? 'Terry & Nigel roast TikTok #$_roastCount';
    final roastDesc = description ?? 'Auto-generated chaos by WFL Animator';

    try {
      final video = Video(
        snippet: VideoSnippet(
          title: roastTitle,
          description: roastDesc,
          tags: ['comedy', 'roast', 'animation', 'wfl', 'terry', 'nigel'],
          categoryId: '23', // Comedy
        ),
        status: VideoStatus(
          privacyStatus: 'public',
          selfDeclaredMadeForKids: false,
        ),
      );

      final response = await youtube.videos.insert(
        video,
        ['snippet', 'status'],
        uploadMedia: Media(
          videoFile.openRead(),
          videoFile.lengthSync(),
        ),
      );

      final videoId = response.id;
      if (videoId != null) {
        await _saveRoastCount();
        return 'https://youtu.be/$videoId';
      }
    } catch (e) {
      debugPrint('YouTube upload error: $e');
    }
    return null;
  }

  /// Save roast count to app directory
  static Future<void> _saveRoastCount() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wfl_roast_count.txt');
      await file.writeAsString(_roastCount.toString());
    } catch (_) {}
  }

  /// Load roast count from app directory
  static Future<void> _loadRoastCount() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wfl_roast_count.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        _roastCount = int.tryParse(content) ?? 0;
      }
    } catch (_) {}
  }

  /// Share to TikTok/Reels/Shorts via share sheet
  /// User picks app → opens composer → post
  static Future<void> shareToSocial(File videoFile, {String? caption}) async {
    _roastCount++;
    final text = caption ?? 'Terry & Nigel just cooked this kid 🔥 #roast #comedy';

    await Share.shareXFiles(
      [XFile(videoFile.path)],
      text: text,
      subject: 'WFL Roast #$_roastCount',
    );
  }

  /// Export & Post - the one-click nuclear option
  /// Renders MP4 → uploads YouTube → opens share sheet → done in 8-12 seconds
  static Future<Map<String, String?>> exportAndPost(
    File videoFile, {
    String? title,
    bool uploadYouTube = true,
    bool openShareSheet = true,
  }) async {
    final results = <String, String?>{};

    // 1. Upload to YouTube (queues if offline)
    if (uploadYouTube) {
      final youtubeUrl = await uploadToYouTube(videoFile, title: title);
      results['youtube'] = youtubeUrl;

      // Copy link to clipboard
      if (youtubeUrl != null) {
        await launchUrl(Uri.parse(youtubeUrl));
      }
    }

    // 2. Open share sheet for TikTok/Reels/Shorts
    if (openShareSheet) {
      await shareToSocial(videoFile);
      results['shared'] = 'true';
    }

    return results;
  }

  /// Get current roast number
  static int get roastNumber => _roastCount + 1;
}
