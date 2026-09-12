import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'platform_glyphs.dart';
import 'platforms.dart';
import 'services/download_service.dart';

/// Everything this device has downloaded, newest first.
///
/// The list comes from the on-device cache, not from the server: `GET
/// /downloads` answers with every user's downloads, which is not something to
/// put on a screen called "My Downloads".
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _downloads = [];
  bool _loading = true;

  /// Ids currently being saved to the gallery again.
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> downloads = [];

    try {
      downloads = await DownloadService.instance.localDownloads();
    } catch (e) {
      // Storage being unreadable means an empty history, never a screen that
      // spins forever.
      debugPrint('⚠️ Could not read the download history: $e');
    }

    if (!mounted) return;

    setState(() {
      _downloads = downloads;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    try {
      final downloads = await DownloadService.instance.refreshLocalDownloads();

      if (!mounted) return;

      setState(() => _downloads = downloads);
    } catch (e) {
      debugPrint('⚠️ Could not refresh the download history: $e');
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _saveAgain(Map<String, dynamic> download) async {
    final id = int.tryParse(download['id']?.toString() ?? '');
    final videoUrl = download['video_url']?.toString();

    if (id == null || videoUrl == null || videoUrl.isEmpty) {
      _toast('This download is no longer available on the server.');
      return;
    }

    setState(() => _saving.add(id.toString()));

    try {
      await DownloadService.instance.processAndSaveToGallery(downloadId: id);

      if (!mounted) return;
      _toast('Saved to your gallery again.', success: true);
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving.remove(id.toString()));
    }
  }

  Future<void> _forget(Map<String, dynamic> download) async {
    await DownloadService.instance.forget(download['id']);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101C3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear history?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'This only clears the list. Videos already saved to your gallery '
          'stay where they are.',
          style: GoogleFonts.poppins(
            color: const Color(0xFFA9B9D3),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF8FA4C0)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                color: const Color(0xFF55C8FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DownloadService.instance.clearCache();
    await _load();
  }

  void _toast(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success
            ? const Color(0xFF101A36)
            : Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07132D),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Downloads',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_downloads.isNotEmpty)
                  Text(
                    '${_downloads.length} on this device',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8FA4C0),
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          if (_downloads.isNotEmpty)
            _GlassButton(icon: Icons.delete_sweep_rounded, onTap: _clearAll),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF45C7FF)),
      );
    }

    if (_downloads.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _refresh,
      backgroundColor: const Color(0xFF101C3A),
      color: const Color(0xFF45C7FF),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        itemCount: _downloads.length,
        separatorBuilder: (_, _) => const SizedBox(height: 11),
        itemBuilder: (context, index) => _buildTile(_downloads[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF43C8FF), Color(0xFF397EF5)],
                ),
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Nothing downloaded yet',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a platform on the home screen, or share a video straight '
              'into Video Saver from any app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFFA9B9D3),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> download) {
    final status = download['status']?.toString() ?? 'pending';
    final platform = platformByName(download['platform']?.toString() ?? '');
    final title = download['title']?.toString();
    final url = download['url']?.toString() ?? '';
    final thumbnail = download['thumbnail_url']?.toString();
    final isSaving = _saving.contains(download['id'].toString());

    return Dismissible(
      key: ValueKey(download['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _forget(download),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  const Color(0xFF113064).withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(thumbnail, platform),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title == null || title.isEmpty ? url : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _StatusChip(status: status),
                          const SizedBox(width: 7),
                          if (platform != null)
                            Text(
                              platform.name,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF8FA4C0),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      if (status == 'failed' &&
                          (download['error_message']?.toString().isNotEmpty ??
                              false)) ...[
                        const SizedBox(height: 6),
                        Text(
                          download['error_message'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE08A8A),
                            fontSize: 9.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status == 'completed')
                  IconButton(
                    onPressed: isSaving ? null : () => _saveAgain(download),
                    tooltip: 'Save to gallery again',
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF45C7FF),
                            ),
                          )
                        : const Icon(
                            Icons.save_alt_rounded,
                            color: Color(0xFF55C8FF),
                            size: 21,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? thumbnail, VideoPlatform? platform) {
    final gradient =
        platform?.gradient ?? const [Color(0xFF43C7FF), Color(0xFF246AF2)];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: thumbnail == null || thumbnail.isEmpty
            ? Center(
                child: PlatformGlyphIcon(
                  glyph: platform?.glyph ?? PlatformGlyph.film,
                  size: 25,
                ),
              )
            : Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: PlatformGlyphIcon(
                    glyph: platform?.glyph ?? PlatformGlyph.film,
                    size: 25,
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    switch (status) {
      case 'completed':
        color = const Color(0xFF3DD68C);
        label = 'Saved';
      case 'failed':
        color = const Color(0xFFE05B5B);
        label = 'Failed';
      case 'processing':
        color = const Color(0xFF55C8FF);
        label = 'Processing';
      default:
        color = const Color(0xFF8FA4C0);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.07),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}
