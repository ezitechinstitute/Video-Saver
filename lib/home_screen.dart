import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'downloads_screen.dart';
import 'how_to_download_screen.dart';
import 'platform_glyphs.dart';
import 'platforms.dart';
import 'paste_link_screen.dart';
import 'status_saver_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07132D),
      body: SafeArea(
        child: Stack(children: [const _HomeBackground(), _buildHome()]),
      ),
    );
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: 24),
          _buildHeroSection(),
          const SizedBox(height: 18),
          _buildInfoCard(),
          const SizedBox(height: 26),
          _buildPlatformsHeader(),
          const SizedBox(height: 13),
          _buildPlatformGrid(),
          const SizedBox(height: 20),
          _buildStatusSaverCard(),
          const SizedBox(height: 12),
          _buildHowToDownloadCard(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.download_done_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadsScreen()),
            );
          },
        ),
        const Spacer(),
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
    );
  }

  Widget _buildHeroSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 14, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.09),
              const Color(0xFF1769FF).withValues(alpha: 0.13),
              const Color(0xFF07132D).withValues(alpha: 0.38),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.13),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back 👋',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFB7C8E5),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Video',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        TextSpan(
                          text: 'Saver',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF49BCFF),
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Browse. Save. Enjoy.',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFB0BDD4),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Image.asset(
                'assets/images/home_hero.png',
                height: 145,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const _HeroFallback();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1769FF).withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.055),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF69C4FF).withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF43C7FF), Color(0xFF246AF2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42B8FF).withValues(alpha: 0.18),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save your favorite videos',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEAF5FF),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose a platform below to get started.',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9DB3D3),
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformsHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Popular Platforms',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kPlatforms.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 9,
        mainAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        return _buildPlatformCard(kPlatforms[index]);
      },
    );
  }

  Widget _buildPlatformCard(VideoPlatform platform) {
    final color = platform.accent;

    return GestureDetector(
      onTap: () => _openPlatform(platform),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                const Color(0xFF113064).withValues(alpha: 0.17),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: platform.gradient,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.17),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Center(
                  child: PlatformGlyphIcon(glyph: platform.glyph, size: 27),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  platform.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFDCE7F8),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSaverCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StatusSaverScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1769FF).withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF55C8FF).withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1769FF), Color(0xFF55C8FF)],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_motion_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Saver',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Save statuses you have viewed to your gallery.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFA9B9D3),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8FA4C0),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToDownloadCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              const Color(0xFF5D5CF0).withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.045),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF7ABEFF).withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.10),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF45C7FF), Color(0xFF6355F5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF45BFFF).withValues(alpha: 0.20),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.video_library_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to download?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Learn simple steps to download your favorite videos.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFA9B9D3),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HowToDownloadScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5F77FF), Color(0xFF6D43F3)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D54F6).withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Text(
                  'Learn',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlatform(VideoPlatform platform) async {
    if (!platform.canBrowse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'More platforms will be available soon.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF3097FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    // Every platform opens the paste screen first. Downloads started from a
    // pasted link succeed far more often than ones started from whatever page
    // the in-app browser happened to be showing; the paste screen still offers
    // a Browse button for people who want to find the video in the app.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PasteLinkScreen(platformName: platform.name),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
            child: Icon(icon, color: const Color(0xFFE8F4FF), size: 23),
          ),
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 135,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF3A9BFF), Color(0xFF5D5CF5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3BA9FF).withValues(alpha: 0.25),
            blurRadius: 35,
          ),
        ],
      ),
      child: const Icon(Icons.download_rounded, color: Colors.white, size: 58),
    );
  }
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: _GlowCircle(
              size: 320,
              color: const Color(0xFF1769FF).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 230,
            right: -120,
            child: _GlowCircle(
              size: 290,
              color: const Color(0xFF42C7FF).withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -130,
            left: 50,
            child: _GlowCircle(
              size: 320,
              color: const Color(0xFF6848F5).withValues(alpha: 0.10),
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
