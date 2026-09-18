import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'error_message.dart';
import 'services/status_service.dart';

/// Saves statuses the user has already viewed in a messaging app.
///
/// The app keeps viewed statuses on the phone for a day. With the user's
/// one-time permission for that folder, they are listed here and copied to
/// the gallery on request. Nothing is uploaded.
class StatusSaverScreen extends StatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  State<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends State<StatusSaverScreen>
    with WidgetsBindingObserver {
  final _service = StatusService.instance;

  StatusSource _source = StatusSource.whatsapp;

  bool _loading = true;
  bool _hasAccess = false;
  List<StatusItem> _items = const [];

  final Set<String> _saving = {};
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from viewing more statuses: show the new ones.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final access = await _service.hasAccess(_source);
      final items = access ? await _service.list(_source) : <StatusItem>[];

      if (!mounted) return;
      setState(() {
        _hasAccess = access;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _items = const [];
      });
      _toast(friendlyError(e, 'Could not read the statuses folder.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchSource(StatusSource source) {
    if (source == _source) return;
    setState(() => _source = source);
    _load();
  }

  Future<void> _allowAccess() async {
    final problem = await _service.requestAccess(_source);

    if (!mounted) return;

    switch (problem) {
      case null:
        await _load();
      case StatusAccessProblem.wrongFolder:
        _toast(
          'That is a different folder. Tap Allow access again and choose '
          'Use this folder on the .Statuses folder that opens.',
        );
      case StatusAccessProblem.noPicker:
        _toast('This phone has no folder picker, so statuses cannot be read.');
      case StatusAccessProblem.cancelled:
        break;
    }
  }

  Future<void> _save(StatusItem item) async {
    if (_saving.contains(item.uri)) return;
    setState(() => _saving.add(item.uri));

    try {
      await _service.saveToGallery(item);
      if (!mounted) return;
      setState(() => _saved.add(item.uri));
      _toast('Saved to your gallery.', success: true);
    } catch (e) {
      if (!mounted) return;
      _toast(friendlyError(e, 'The status could not be saved.'));
    } finally {
      if (mounted) setState(() => _saving.remove(item.uri));
    }
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
            _buildSourceSwitch(),
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
                  'Status Saver',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Statuses you have already viewed',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF8FA4C0),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (_hasAccess)
            _GlassButton(icon: Icons.refresh_rounded, onTap: _load),
        ],
      ),
    );
  }

  Widget _buildSourceSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          for (final source in StatusSource.values) ...[
            Expanded(child: _sourceChip(source)),
            if (source != StatusSource.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _sourceChip(StatusSource source) {
    final selected = source == _source;

    return GestureDetector(
      onTap: () => _switchSource(source),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF1769FF), Color(0xFF55C8FF)],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          source.label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF55C8FF)),
      );
    }

    if (!_hasAccess) return _buildAccessCard();

    if (_items.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF55C8FF),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: _items.length,
        itemBuilder: (context, i) => _StatusTile(
          item: _items[i],
          saving: _saving.contains(_items[i].uri),
          saved: _saved.contains(_items[i].uri),
          onSave: () => _save(_items[i]),
        ),
      ),
    );
  }

  Widget _buildAccessCard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: const Color(0xFF101E38),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF45C7FF), Color(0xFF6355F5)],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Save statuses to your gallery',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _step('1', 'Open ${_source.label} and view the status you want.'),
              _step(
                '2',
                'Come back here and tap Allow access. A folder opens: tap '
                    'Use this folder, then Allow.',
              ),
              _step('3', 'Tap any status to save it to your gallery.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1769FF), Color(0xFF55C8FF)],
                    ),
                  ),
                  child: TextButton(
                    onPressed: _allowAccess,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Allow access',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _note(
          'Only the statuses folder is shared with Video Saver, and nothing '
          'leaves your phone. You only see statuses you have already viewed.',
        ),
        const SizedBox(height: 8),
        _note(
          'Works with WhatsApp and WhatsApp Business. Video Saver is not '
          'affiliated with WhatsApp. Save only what you have the right to '
          'keep, and respect the people who posted it.',
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF55C8FF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 70, 28, 24),
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: Color(0xFF55C8FF),
            size: 44,
          ),
          const SizedBox(height: 14),
          Text(
            'No statuses yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'View a few statuses in ${_source.label}, then come back. '
            'Statuses disappear from the phone after 24 hours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF8FA4C0),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1769FF).withValues(alpha: 0.25),
            ),
            child: Text(
              number,
              style: GoogleFonts.poppins(
                color: const Color(0xFF55C8FF),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: const Color(0xFFC6D3E8),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: const Color(0xFF6F82A3),
        fontSize: 10.5,
        height: 1.5,
      ),
    );
  }
}

class _StatusTile extends StatefulWidget {
  final StatusItem item;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;

  const _StatusTile({
    required this.item,
    required this.saving,
    required this.saved,
    required this.onSave,
  });

  @override
  State<_StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<_StatusTile> {
  // Created once, so rebuilding the tile (while saving, say) does not blank
  // the preview for a frame.
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = StatusService.instance.thumbnail(widget.item);
  }

  @override
  void didUpdateWidget(_StatusTile old) {
    super.didUpdateWidget(old);
    if (old.item.uri != widget.item.uri) {
      _thumbnail = StatusService.instance.thumbnail(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final saving = widget.saving;
    final saved = widget.saved;

    return GestureDetector(
      onTap: widget.onSave,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF101E38)),
            FutureBuilder<Uint8List?>(
              future: _thumbnail,
              builder: (context, snap) {
                final bytes = snap.data;
                if (bytes == null) return const SizedBox.shrink();
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
            if (item.isVideo)
              const Center(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x99000000),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            Positioned(
              right: 7,
              bottom: 7,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: saved
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF1769FF), Color(0xFF55C8FF)],
                        ),
                  color: saved ? const Color(0xFF2BD97C) : null,
                ),
                child: saving
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        saved ? Icons.check_rounded : Icons.download_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
              ),
            ),
          ],
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
    );
  }
}
