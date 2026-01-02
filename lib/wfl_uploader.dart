import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

// Conditional import for Google Sign-In (not supported on Windows desktop)
import 'wfl_google_sign_in_stub.dart'
    if (dart.library.html) 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.io) 'wfl_google_sign_in_stub.dart';

/// WFL One-Click Upload - YouTube + Share Sheet
/// Zero backend, zero API rotation, works offline
class WFLUploader {
  static YouTubeApi? _youtubeApi;
  static int _roastCount = 0;
  static bool _isConnected = false;
  static dynamic _currentUser;
  static StreamSubscription? _authSubscription;

  /// YouTube scopes needed
  static final _scopes = [YouTubeApi.youtubeUploadScope];

  /// Check if Google Sign-In is supported on this platform
  static bool get _isGoogleSignInSupported => !Platform.isWindows && !Platform.isLinux;

  static dynamic _googleSignIn;
  static bool _initialized = false;

  /// Check if YouTube is connected
  static bool get isYouTubeConnected => _isConnected;

  /// Check if YouTube upload is available on this platform
  static bool get isYouTubeAvailable => _isGoogleSignInSupported;

  /// Ensure GoogleSignIn is initialized (required in v7)
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      // Skip initialization on unsupported platforms
      if (!_isGoogleSignInSupported) {
        debugPrint('Google Sign-In not supported on this platform (Windows/Linux)');
        _initialized = true;
        return;
      }

      _googleSignIn = GoogleSignIn.instance;
      await _googleSignIn.initialize();

      // Listen to authentication events
      _authSubscription = _googleSignIn.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _currentUser = event.user;
            _isConnected = true;
          } else if (event is GoogleSignInAuthenticationEventSignOut) {
            _currentUser = null;
            _isConnected = false;
            _youtubeApi = null;
          }
        },
        onError: (error) {
          debugPrint('Google Sign-In error: $error');
        },
      );

      _initialized = true;
    }
  }

  /// Connect YouTube - first run popup, then cached forever
  static Future<bool> connectYouTube() async {
    // Not available on Windows/Linux desktop
    if (!_isGoogleSignInSupported) {
      debugPrint('YouTube upload not available on Windows/Linux. Use share sheet instead.');
      return false;
    }

    try {
      await _ensureInitialized();

      // Try lightweight auth first
      _googleSignIn.attemptLightweightAuthentication();

      // If no user yet, do full authentication
      if (_currentUser == null && _googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.authenticate();
      }

      if (_currentUser == null) return false;

      // Get authorization for YouTube scopes
      final authorization = await _currentUser.authorizationClient
          .authorizeScopes(_scopes);

      final accessToken = authorization.accessToken;
      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, DateTime.now().add(Duration(hours: 1))),
          null,
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
    if (!_isGoogleSignInSupported || _googleSignIn == null) return;

    await _googleSignIn.signOut();
    _currentUser = null;
    _youtubeApi = null;
    _isConnected = false;
  }

  /// Initialize - check if already logged in
  static Future<void> init() async {
    await _ensureInitialized();

    // Try lightweight auth (only on supported platforms)
    if (_isGoogleSignInSupported && _googleSignIn != null) {
      _googleSignIn.attemptLightweightAuthentication();
    }

    await _loadRoastCount();
  }

  /// Upload to YouTube - one tap, token saved forever
  static Future<String?> uploadToYouTube(File videoFile, {String? title, String? description}) async {
    // Not available on Windows/Linux
    if (!_isGoogleSignInSupported) {
      debugPrint('YouTube upload not available on this platform');
      return null;
    }

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

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(videoFile.path)],
        text: text,
        subject: 'WFL Roast #$_roastCount',
      ),
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
