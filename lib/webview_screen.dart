import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'platforms.dart';
import 'services/download_service.dart';

/// Turns a thrown error into something worth showing the user, falling back to
/// [fallback] when the error carries no useful message.
String _friendlyError(Object error, String fallback) {
  final message = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException', '')
      .trim();

  if (message.isEmpty || message.length > 160) return fallback;

  return message;
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final String platformName;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.platformName,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  int _progress = 0;

  String _selectedQuality = '1080p';

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadReceived = 0;
  int _downloadTotal = 0;
  bool _isPreparingDownload = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
              });
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final Uri uri = Uri.parse(request.url);

            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _refresh() async {
    await _controller.reload();
  }

  // ============================================================
  // DOWNLOAD OPTIONS
  // ============================================================

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 11, 18, 26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1933).withValues(alpha: 0.97),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF596C87),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF43C8FF), Color(0xFF397EF5)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF43C8FF,
                                  ).withValues(alpha: 0.20),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Download Video',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${widget.platformName} • MP4',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF8FA4C0),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 21),

                      Text(
                        'Video Quality',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      _qualityOption(
                        quality: '1080p',
                        subtitle: 'Full HD • Best quality',
                        icon: Icons.high_quality_rounded,
                        selected: _selectedQuality == '1080p',
                        onTap: () {
                          setSheetState(() {
                            _selectedQuality = '1080p';
                          });

                          setState(() {
                            _selectedQuality = '1080p';
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _startDownload();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF43C9FF),
                                  Color(0xFF377FF5),
                                  Color(0xFF6848EF),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF43BFFF,
                                  ).withValues(alpha: 0.22),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Download $_selectedQuality',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // QUALITY OPTION
  // ============================================================

  Widget _qualityOption({
    required String quality,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: selected
                ? [
                    const Color(0xFF3097FF).withValues(alpha: 0.18),
                    const Color(0xFF654CF0).withValues(alpha: 0.08),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.055),
                    Colors.white.withValues(alpha: 0.025),
                  ],
          ),
          border: Border.all(
            color: selected
                ? const Color(0xFF5BBEFF).withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.09),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: Colors.white.withValues(alpha: 0.065),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF5BCBFF)
                    : const Color(0xFF8294B0),
                size: 22,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quality,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8699B5),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF4DC7FF)
                  : const Color(0xFF596A84),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // START DOWNLOAD
  // ============================================================

  Future<void> _startDownload() async {
    try {
      // ============================================================
      // 1. CAPTURE CURRENT VIDEO / PAGE URL FROM WEBVIEW
      // ============================================================

      // The page URL is what the extractor works from. The old build fell
      // back to whatever page happened to be open when it could not find a
      // <video> element, which is why every browse-started download failed:
      // homepages and login screens were sent to the server as if they were
      // videos. Now the page must actually be a video before we ask.

      String? currentUrl;

      try {
        final result = await _controller.runJavaScriptReturningResult(
          'window.location.href',
        );

        currentUrl = result.toString().replaceAll('"', '').trim();
      } catch (e) {
        debugPrint('⚠️ Could not read the WebView URL: $e');
      }

      debugPrint('==========================================');
      debugPrint('🎯 Current page: $currentUrl');
      debugPrint('🌐 Platform: ${widget.platformName}');
      debugPrint('🎞️ Quality: $_selectedQuality');
      debugPrint('==========================================');

      if (currentUrl == null || currentUrl.isEmpty) {
        throw Exception('Could not read the current page. Try again.');
      }

      final uri = Uri.tryParse(currentUrl);

      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        throw Exception('Open a video before starting the download.');
      }

      final platform = platformByName(widget.platformName);

      if (platform != null && !platform.isVideoUrl(uri)) {
        throw Exception(
          'This page is not a video. Open the video you want, then tap '
          'download again.',
        );
      }

      final String cleanUrl = cleanVideoUrl(uri);

      debugPrint('🎯 FINAL TARGET URL: $cleanUrl');

      if (!mounted) return;

      // ============================================================
      // 4. SHOW DOWNLOAD STATE
      // ============================================================

      setState(() {
        _isDownloading = true;
        _isPreparingDownload = true;
        _downloadProgress = 0.0;
        _downloadReceived = 0;
        _downloadTotal = 0;
      });

      // ============================================================
      // 5. CREATE DOWNLOAD REQUEST ON LARAVEL
      // ============================================================

      debugPrint('📤 Sending download request to Laravel...');

      final download = await DownloadService.instance.createDownload(
        url: cleanUrl,
        platform: widget.platformName,
        quality: _selectedQuality,
      );

      debugPrint('✅ Download request created successfully.');
      debugPrint('📦 Server response: $download');

      // ============================================================
      // 6. GET DOWNLOAD ID
      // ============================================================

      final downloadId = download['id'];

      if (downloadId == null) {
        throw Exception('The server did not return a valid download ID.');
      }

      final int id = int.parse(downloadId.toString());

      debugPrint('🆔 Download ID: $id');

      // ============================================================
      // 7. WAIT FOR LARAVEL + YT-DLP
      // ============================================================

      debugPrint('⏳ Waiting for server-side video processing...');

      final completedDownload = await DownloadService.instance
          .processAndSaveToGallery(
            downloadId: id,
            onProgress: (received, total) {
              if (!mounted) return;

              if (total > 0) {
                setState(() {
                  _isPreparingDownload = false;
                  _downloadReceived = received;
                  _downloadTotal = total;
                  _downloadProgress = received / total;
                });

                final percent = (received / total * 100).toStringAsFixed(0);

                debugPrint(
                  '📱 Phone download progress: $percent% '
                  '($received / $total bytes)',
                );
              }
            },
          );

      // ============================================================
      // 8. SERVER DOWNLOAD COMPLETED
      // ============================================================

      final serverVideoUrl = completedDownload['video_url']?.toString();

      debugPrint('==========================================');
      debugPrint('✅ Server-side download completed.');
      debugPrint('🆔 Download ID: $id');
      debugPrint('🎬 Server Video URL: $serverVideoUrl');
      debugPrint('==========================================');

      if (serverVideoUrl == null || serverVideoUrl.isEmpty) {
        throw Exception(
          'The server completed the download but did not return a video URL.',
        );
      }

      // ============================================================
      // 9. PHONE-SIDE GALLERY DOWNLOAD
      // ============================================================

      debugPrint('📲 Starting phone-side Gallery save...');
      debugPrint('📡 Waiting for video file transfer...');

      // processAndSaveToGallery() already handles:
      //
      // Laravel video URL
      //       ↓
      // Phone-accessible URL
      //       ↓
      // Dio download
      //       ↓
      // Gal.putVideo()
      //       ↓
      // Gallery

      // ============================================================
      // 10. SUCCESS
      // ============================================================

      debugPrint('==========================================');
      debugPrint('🎉 Phone-side Gallery process completed.');
      debugPrint('🎬 Video successfully saved to Gallery.');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isPreparingDownload = false;
        _downloadProgress = 1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF101A36),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF4FC3F7),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Download complete! Your video is now available in the Gallery.',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // ============================================================
      // ERROR HANDLING
      // ============================================================

      debugPrint('==========================================');
      debugPrint('❌ EziDownload failed');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isPreparingDownload = false;
        _downloadProgress = 0.0;
        _downloadReceived = 0;
        _downloadTotal = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _friendlyError(
                    e,
                    'We couldn’t save the video to your Gallery. Please try again.',
                  ),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Keep the system back button consistent with the in-app back button:
      // navigate the WebView history first, and never leave mid-download.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isDownloading) return;

        await _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07132D),
        body: SafeArea(
          child: Stack(
            children: [
              const _WebViewBackground(),

              Column(
                children: [
                  _buildTopBar(),

                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: WebViewWidget(controller: _controller),
                        ),

                        if (_isLoading)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: _progress == 100 ? null : _progress / 100,
                              minHeight: 3,
                              backgroundColor: const Color(0xFF172746),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF45C7FF),
                              ),
                            ),
                          ),

                        if (_isDownloading)
                          Positioned(
                            left: 15,
                            right: 15,
                            bottom: 78,
                            child: _buildDownloadProgressPanel(),
                          ),

                        if (!widget.platformName.toLowerCase().contains(
                          'google',
                        ))
                          Positioned(
                            right: 17,
                            bottom: 17,
                            child: _buildFloatingDownloadButton(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1933).withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
          ),
          child: Row(
            children: [
              _GlassWebButton(icon: Icons.arrow_back_rounded, onTap: _goBack),
              const SizedBox(width: 7),

              _GlassWebButton(
                icon: Icons.arrow_forward_rounded,
                onTap: () async {
                  if (await _controller.canGoForward()) {
                    await _controller.goForward();
                  }
                },
              ),

              const SizedBox(width: 9),

              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.11),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.public_rounded,
                            color: Color(0xFF5CCBFF),
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.platformName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFDCEAFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.7,
                                color: Color(0xFF55C8FF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 9),

              _GlassWebButton(icon: Icons.refresh_rounded, onTap: _refresh),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FLOATING DOWNLOAD BUTTON
  // ============================================================

  Widget _buildFloatingDownloadButton() {
    return GestureDetector(
      onTap: _isDownloading ? null : _showDownloadOptions,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF43C9FF),
                  Color(0xFF377FF5),
                  Color(0xFF6848EF),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43BFFF).withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDownloading
                      ? Icons.downloading_rounded
                      : Icons.download_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 7),
                Text(
                  _isDownloading ? 'Downloading' : 'Download',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DOWNLOAD PROGRESS PANEL
  // ============================================================

  Widget _buildDownloadProgressPanel() {
    final double progress = _downloadProgress.clamp(0.0, 1.0);

    final int percentage = (progress * 100).round();

    final String receivedText = _formatBytes(_downloadReceived);

    final String totalText = _formatBytes(_downloadTotal);

    return ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1B38).withValues(alpha: 0.91),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: const Color(0xFF63BCFF).withValues(alpha: 0.20),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1769FF).withValues(alpha: 0.13),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF42C8FF), Color(0xFF397EF4)],
                      ),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPreparingDownload
                              ? 'Preparing your video...'
                              : 'Downloading video',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isPreparingDownload
                              ? 'Processing your MP4 file'
                              : '$receivedText of $totalText',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8F9DB7),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!_isPreparingDownload)
                    Text(
                      '$percentage%',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF58C9FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 13),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _isPreparingDownload ? null : progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF1B2A4A),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4DC7FF),
                  ),
                ),
              ),

              const SizedBox(height: 9),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isPreparingDownload
                        ? 'Please wait...'
                        : 'Saving to Gallery',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8393AD),
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    'MP4 • $_selectedQuality',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8393AD),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT BYTES
  // ============================================================

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 MB';
    }

    final double mb = bytes / (1024 * 1024);

    if (mb < 1) {
      final double kb = bytes / 1024;

      return '${kb.toStringAsFixed(0)} KB';
    }

    return '${mb.toStringAsFixed(1)} MB';
  }
}

// ============================================================
// GLASS WEB BUTTON
// ============================================================

class _GlassWebButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassWebButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.07),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
              ),
              child: Icon(icon, color: const Color(0xFFDDEEFF), size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _WebViewBackground extends StatelessWidget {
  const _WebViewBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: _GlowCircle(
              size: 320,
              color: const Color(0xFF1769FF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _GlowCircle(
              size: 300,
              color: const Color(0xFF6848EF).withValues(alpha: 0.09),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
