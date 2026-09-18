import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'how_to_download_screen.dart';
import 'error_message.dart';
import 'platforms.dart';
import 'services/download_service.dart';
import 'webview_screen.dart';

class PasteLinkScreen extends StatefulWidget {
  final String platformName;

  /// Link the screen opens with, when it was reached by sharing a video into
  /// the app rather than by tapping a platform tile.
  final String? initialLink;

  /// Start downloading [initialLink] as soon as the screen opens.
  final bool autoStart;

  const PasteLinkScreen({
    super.key,
    required this.platformName,
    this.initialLink,
    this.autoStart = false,
  });

  @override
  State<PasteLinkScreen> createState() => _PasteLinkScreenState();
}

class _PasteLinkScreenState extends State<PasteLinkScreen> {
  final TextEditingController _linkController = TextEditingController();

  bool _isDownloading = false;
  bool _isPreparingDownload = false;

  double _downloadProgress = 0.0;
  int _downloadReceived = 0;
  int _downloadTotal = 0;

  String _selectedQuality = '1080p';

  @override
  void initState() {
    super.initState();

    final shared = widget.initialLink?.trim();

    if (shared != null && shared.isNotEmpty) {
      _linkController.text = shared;

      // Reached from a copied or shared link: the user already chose this
      // video, so start without making them tap Download too.
      if (widget.autoStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDownloading) _startDownload();
        });
      }
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  // ============================================================
  // PASTE FROM CLIPBOARD
  // ============================================================

  Future<void> _pasteLink() async {
    final clipboardData = await Clipboard.getData('text/plain');

    if (clipboardData?.text == null || clipboardData!.text!.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No link found in clipboard.',
            style: GoogleFonts.poppins(fontSize: 11),
          ),
        ),
      );

      return;
    }

    setState(() {
      _linkController.text = clipboardData.text!.trim();
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BROWSE THE PLATFORM IN-APP
  // ============================================================

  void _browsePlatform() {
    final platform = platformByName(widget.platformName);

    if (platform == null || !platform.canBrowse) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WebViewScreen(url: platform.browseUrl, platformName: platform.name),
      ),
    );
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  Future<void> _startDownload() async {
    final url = _linkController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xff101A36),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(Icons.link_off_rounded, color: Color(0xff55C8FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please paste a video link first.',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );

      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Please enter a valid video link.',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
          ),
        ),
      );

      return;
    }

    // ============================================================
    // PLATFORM AND VIDEO-LINK VALIDATION
    // ============================================================
    //
    // Catching a bad link here matters: on the server every non-video URL
    // becomes a yt-dlp run that is guaranteed to fail, and the user waits
    // through it only to be told it did not work.

    final platform = platformByName(widget.platformName);

    if (platform != null && !platform.matchesHost(uri)) {
      final pasted = platformForUrl(uri);

      _showError(
        pasted == null
            ? 'That is not a ${widget.platformName} link. Paste a link copied from ${widget.platformName}.'
            : 'That looks like a ${pasted.name} link. Open ${pasted.name} from the home screen to download it.',
      );
      return;
    }

    if (platform != null && !platform.isVideoUrl(uri)) {
      _showError(
        'That link points at a page, not a video. Open the video on '
        '${widget.platformName}, tap Share, then copy the link.',
      );
      return;
    }

    // Links shared from the platform apps carry tracking parameters that the
    // extractor chokes on, so strip them before sending.
    final String requestUrl = cleanVideoUrl(uri);

    debugPrint('🧹 Cleaned link: $requestUrl');

    if (!mounted) return;

    setState(() {
      _isDownloading = true;
      _isPreparingDownload = true;
      _downloadProgress = 0.0;
      _downloadReceived = 0;
      _downloadTotal = 0;
    });

    try {
      // ==========================================================
      // 1. CREATE DOWNLOAD REQUEST ON LARAVEL
      // ==========================================================

      debugPrint('==========================================');
      debugPrint('📤 PASTE LINK DOWNLOAD');
      debugPrint('🌐 Platform: ${widget.platformName}');
      debugPrint('🔗 URL: $requestUrl');
      debugPrint('🎞️ Quality: $_selectedQuality');
      debugPrint('==========================================');

      final download = await DownloadService.instance.createDownload(
        url: requestUrl,
        platform: widget.platformName,
        quality: _selectedQuality,
      );

      // ==========================================================
      // 2. GET DOWNLOAD ID
      // ==========================================================

      final downloadId = download['id'];

      if (downloadId == null) {
        throw Exception('The server did not return a valid download ID.');
      }

      final int id = int.parse(downloadId.toString());

      debugPrint('🆔 Download ID: $id');

      // ==========================================================
      // 3. WAIT FOR SERVER + SAVE TO GALLERY
      // ==========================================================

      final completedDownload = await DownloadService.instance
          .processAndSaveToGallery(
            downloadId: id,
            onProgress: (received, total) {
              if (!mounted) return;

              if (total > 0) {
                // Dio reports every chunk, often hundreds a second. Rebuild
                // only when the whole percent moves.
                if (!_isPreparingDownload &&
                    _downloadTotal > 0 &&
                    received * 100 ~/ total ==
                        _downloadReceived * 100 ~/ _downloadTotal) {
                  return;
                }

                setState(() {
                  _isPreparingDownload = false;
                  _downloadReceived = received;
                  _downloadTotal = total;
                  _downloadProgress = received / total;
                });
              }
            },
          );

      final serverVideoUrl = completedDownload['video_url']?.toString();

      if (serverVideoUrl == null || serverVideoUrl.isEmpty) {
        throw Exception(
          'The server completed the download but did not return a video URL.',
        );
      }

      // ==========================================================
      // 4. SUCCESS
      // ==========================================================

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isPreparingDownload = false;
        _downloadProgress = 1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xff101A36),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xff55C8FF),
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
      debugPrint('❌ Paste link download failed: $e');

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
                  friendlyError(
                    e,
                    'We couldn’t download this video. Please check the link and try again.',
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
      // Don't let the system back button abandon a running download.
      canPop: !_isDownloading,
      child: Scaffold(
        backgroundColor: const Color(0xFF07132D),
        body: SafeArea(
          child: Stack(children: [const _DownloadBackground(), _buildBody()]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 125),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 20),
                    _buildLinkSection(),
                    const SizedBox(height: 18),
                    _buildQualitySection(),
                    const SizedBox(height: 18),
                    // The progress panel is laid over these while a download
                    // runs; hide them so their edges and text do not show
                    // round it. Opacity keeps their space, so nothing jumps.
                    Opacity(
                      opacity: _isDownloading ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDownloadButton(),
                          const SizedBox(height: 16),
                          _buildFooterNote(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_isDownloading)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: _buildDownloadProgressPanel(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: _isDownloading
                ? () {}
                : () {
                    Navigator.pop(context);
                  },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${widget.platformName} Download',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (platformByName(widget.platformName)?.canBrowse ?? false) ...[
            _GlassIconButton(
              icon: Icons.travel_explore_rounded,
              onTap: _isDownloading ? () {} : _browsePlatform,
            ),
            const SizedBox(width: 8),
          ],
          _GlassIconButton(
            icon: Icons.help_outline_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HowToDownloadScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHeroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 21, 18, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              const Color(0xFF1769FF).withValues(alpha: 0.12),
              const Color(0xFF6448F1).withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.035),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF48C9FF),
                    Color(0xFF357CFF),
                    Color(0xFF6949F0),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF43BCFF).withValues(alpha: 0.24),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.link_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Download from ${widget.platformName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Paste the video link below to start your download.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF9EAFCA),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LINK SECTION
  // ============================================================

  Widget _buildLinkSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Link',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF63BCFF).withValues(alpha: 0.19),
                  ),
                ),
                child: TextField(
                  controller: _linkController,
                  enabled: !_isDownloading,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                  maxLines: 3,
                  minLines: 1,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'Paste ${widget.platformName} video link here...',
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFF71839F),
                      fontSize: 11,
                    ),
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: Color(0xFF55C8FF),
                      size: 21,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _isDownloading ? null : _pasteLink,
                      icon: const Icon(
                        Icons.content_paste_rounded,
                        color: Color(0xFF55C8FF),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => _startDownload(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUALITY SECTION
  // ============================================================

  Widget _buildQualitySection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Quality',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isDownloading
                  ? null
                  : () {
                      setState(() {
                        _selectedQuality = '1080p';
                      });
                    },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3097FF).withValues(alpha: 0.16),
                      const Color(0xFF5867F1).withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF58B6FF).withValues(alpha: 0.35),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: const Icon(
                        Icons.high_quality_rounded,
                        color: Color(0xFF55C8FF),
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1080p',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Full HD • Best quality',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF8E9EB8),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF55C8FF),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: CircleAvatar(
                          radius: 5,
                          backgroundColor: Color(0xFF55C8FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DOWNLOAD BUTTON
  // ============================================================

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: GestureDetector(
        onTap: _isDownloading ? null : _startDownload,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF43C9FF), Color(0xFF377FF5), Color(0xFF6748EF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3CB8FF).withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDownloading
                    ? Icons.downloading_rounded
                    : Icons.download_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 9),
              Text(
                _isDownloading ? 'Downloading...' : 'Download Video',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooterNote() {
    return Center(
      child: Text(
        'Your video will be saved to the EziDownload album.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: const Color(0xFF667896), fontSize: 9),
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B38),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: const Color(0xFF63BCFF).withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
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
                  _isPreparingDownload ? 'Please wait...' : 'Saving to Gallery',
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
// GLASS ICON BUTTON
// ============================================================

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Material(
        color: Colors.white.withValues(alpha: 0.075),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
            child: Icon(icon, color: const Color(0xFFE7F4FF), size: 21),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _DownloadBackground extends StatelessWidget {
  const _DownloadBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowCircle(
              size: 320,
              color: const Color(0xFF1769FF).withValues(alpha: 0.15),
            ),
          ),
          Positioned(
            top: 320,
            left: -120,
            child: _GlowCircle(
              size: 280,
              color: const Color(0xFF42C8FF).withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            bottom: -130,
            right: -80,
            child: _GlowCircle(
              size: 310,
              color: const Color(0xFF6947EF).withValues(alpha: 0.10),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.25, 1.0],
        ),
      ),
    );
  }
}
