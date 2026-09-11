import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  // Sirf 2 onboarding screens:
  // 1 = onboarding1.png
  // 2 = onboarding3.png
  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/onboarding1.png',
      'title': 'Welcome to VideoSaver',
      'description':
          'Your all-in-one place to browse, download and enjoy your favorite media.',
    },
    {
      'image': 'assets/images/onboarding3.png',
      'title': 'Download & Enjoy',
      'description':
          'Download your favorite permitted content and access it anytime, anywhere.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    } else {
      _goToHome();
    }
  }

  void _skipOnboarding() {
    _goToHome();
  }

  Future<void> _goToHome() async {
    // Remember that onboarding is done so it is not shown on every launch.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingSeenKey, true);
    } catch (e) {
      debugPrint('⚠️ Could not save onboarding flag: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07132D),
      body: SafeArea(
        child: Stack(
          children: [
            const _BackgroundGlow(),

            Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index]);
                    },
                  ),
                ),

                _buildBottomControls(),

                const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          const Spacer(),
          GestureDetector(
            onTap: _skipOnboarding,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> page) {
    final bool isFirstPage = _currentPage == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.09),
                          const Color(0xFF1769FF).withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF1769FF,
                          ).withValues(alpha: 0.12),
                          blurRadius: 35,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 18,
                          left: 18,
                          child: _GlassDot(
                            size: 42,
                            color: const Color(
                              0xFF4FC3F7,
                            ).withValues(alpha: 0.16),
                          ),
                        ),
                        Positioned(
                          bottom: 22,
                          right: 20,
                          child: _GlassDot(
                            size: 58,
                            color: const Color(
                              0xFF7A42F4,
                            ).withValues(alpha: 0.14),
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Image.asset(
                              page['image']!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          _buildTitle(page['title']!, isFirstPage: isFirstPage),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              page['description']!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFFB5C3DD),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildTitle(String title, {required bool isFirstPage}) {
    if (isFirstPage) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Welcome to Video',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            TextSpan(
              text: 'Saver',
              style: GoogleFonts.inter(
                color: const Color(0xFF45BFFF),
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ],
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Download & ',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          TextSpan(
            text: 'Enjoy',
            style: GoogleFonts.inter(
              color: const Color(0xFF45BFFF),
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (index) {
            final bool active = _currentPage == index;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF45C7FF), Color(0xFF5E72FF)],
                      )
                    : null,
                color: active ? null : Colors.white.withValues(alpha: 0.20),
              ),
            );
          }),
        ),

        const SizedBox(height: 22),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: _nextPage,
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF40C7FF),
                    Color(0xFF3B82F6),
                    Color(0xFF6A43F5),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF45BFFF).withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassDot extends StatelessWidget {
  final double size;
  final Color color;

  const _GlassDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -90,
            child: _GlowCircle(
              size: 300,
              color: const Color(0xFF1769FF).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 230,
            right: -100,
            child: _GlowCircle(
              size: 260,
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: -120,
            left: 40,
            child: _GlowCircle(
              size: 310,
              color: const Color(0xFF7147F5).withValues(alpha: 0.12),
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
