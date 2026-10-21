import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.darkModeEnabled = false,
    this.onDarkModeChanged,
  });

  final bool darkModeEnabled;
  final ValueChanged<bool>? onDarkModeChanged;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Xeta UPI Circle App',
      body:
          "The easiest way to pay your family's transactions using your credit card. Let your family scan or send a request to you on WhatsApp and complete the payment from your side.",
      accent: Color(0xFF16423D),
      icon: Icons.groups_rounded,
    ),
    _OnboardingPageData(
      title: 'No backend. No login.',
      body:
          'We do not run a backend for this app. Your trusted contacts, transactions, and saved proof stay on your mobile device only.',
      accent: Color(0xFF1D6072),
      icon: Icons.shield_outlined,
    ),
    _OnboardingPageData(
      title: 'Choose how to share',
      body:
          'Send payment requests through WhatsApp or other sharing apps. Xeta UPI Circle App simply helps trusted families coordinate the request and save proof later.',
      accent: Color(0xFFE29A45),
      icon: Icons.share_rounded,
    ),
    _OnboardingPageData(
      title: 'Protect elders and children',
      body:
          'Keep minors and older adults away from risky payment flows by letting a trusted family member complete the transaction and store the proof safely.',
      accent: Color(0xFF8C5E52),
      icon: Icons.security_rounded,
    ),
    _OnboardingPageData(
      title: 'Get Cashback and save as a Family',
      body:
          'Not everyone has a credit card or the same offers. Xeta UPI Circle App helps families route payments through the most rewarding option and keep a local record for future proof.',
      accent: Color(0xFF5D7042),
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          darkModeEnabled: widget.darkModeEnabled,
          onDarkModeChanged: widget.onDarkModeChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isShortScreen = screenHeight < 760;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, isShortScreen ? 8 : 14, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('assets/app_icon.png'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xeta UPI Circle App',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'Get Cashback and save as a Family',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: widget.darkModeEnabled
                        ? 'Light mode'
                        : 'Dark mode',
                    onPressed: widget.onDarkModeChanged == null
                        ? null
                        : () => widget.onDarkModeChanged!(
                            !widget.darkModeEnabled,
                          ),
                    icon: Icon(
                      widget.darkModeEnabled
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                ],
              ),
            ),
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
                  final page = _pages[index];
                  final accent = Theme.of(context).brightness == Brightness.dark
                      ? scheme.primary
                      : page.accent;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      isShortScreen ? 12 : 18,
                      24,
                      0,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Scrollbar(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36),
                                  gradient: LinearGradient(
                                    colors: [
                                      accent.withValues(alpha: 0.16),
                                      scheme.surfaceContainerLow,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    isShortScreen ? 20 : 24,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _OnboardingArtwork(
                                        accent: accent,
                                        icon: page.icon,
                                        pageIndex: index,
                                      ),
                                      SizedBox(height: isShortScreen ? 18 : 24),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'Get Cashback and save as a Family',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: accent,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      SizedBox(height: isShortScreen ? 16 : 20),
                                      Text(
                                        page.title,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: scheme.onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      SizedBox(height: isShortScreen ? 10 : 14),
                                      Text(
                                        page.body,
                                        textAlign: TextAlign.center,
                                        style:
                                            (isShortScreen
                                                    ? Theme.of(
                                                        context,
                                                      ).textTheme.bodyMedium
                                                    : Theme.of(
                                                        context,
                                                      ).textTheme.bodyLarge)
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  height: 1.6,
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, isShortScreen ? 8 : 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 28 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 10 : 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _currentPage == _pages.length - 1
                        ? SizedBox(
                            key: const ValueKey('finish_button'),
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _completeOnboarding,
                              child: const Text('Finish'),
                            ),
                          )
                        : Text(
                            key: const ValueKey('swipe_hint'),
                            'Swipe to continue',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
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
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String body;
  final Color accent;
  final IconData icon;
}

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({
    required this.accent,
    required this.icon,
    required this.pageIndex,
  });

  final Color accent;
  final IconData icon;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final compactWidth = screenSize.width < 360;
    final artworkSize = screenSize.height < 650
        ? (compactWidth ? 164.0 : 176.0)
        : screenSize.height < 760
        ? (compactWidth ? 184.0 : 198.0)
        : (compactWidth ? 216.0 : 232.0);

    return Container(
      width: artworkSize,
      height: artworkSize,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ArtBubble(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  icon: icon,
                ),
                _InfoPill(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  label: 'Step ${pageIndex + 1}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _ArtworkScene(accent: accent, pageIndex: pageIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkScene extends StatelessWidget {
  const _ArtworkScene({required this.accent, required this.pageIndex});

  final Color accent;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    switch (pageIndex) {
      case 0:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ArtPanel(
                      accent: accent,
                      icon: Icons.credit_card_rounded,
                      label: 'Card rewards',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ArtPanel(
                      accent: accent,
                      icon: Icons.qr_code_2_rounded,
                      label: 'QR request',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ArtWidePanel(
              accent: accent,
              icon: Icons.family_restroom_rounded,
              title: 'Family payment flow',
              subtitle: 'Scan, share, pay, save',
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _ArtWidePanel(
              accent: accent,
              icon: Icons.phonelink_lock_rounded,
              title: 'Stored locally',
              subtitle: 'No login or cloud storage',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ArtPanel(
                accent: accent,
                icon: Icons.shield_moon_rounded,
                label: 'Private by default',
              ),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            Expanded(
              child: _ArtPanel(
                accent: accent,
                icon: Icons.forum_rounded,
                label: 'Share on WhatsApp',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ArtPanel(
                      accent: accent,
                      icon: Icons.share_rounded,
                      label: 'Other apps',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ArtPanel(
                      accent: accent,
                      icon: Icons.image_outlined,
                      label: 'QR attached',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ArtPanel(
                      accent: accent,
                      icon: Icons.elderly_rounded,
                      label: 'Adults',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ArtPanel(
                      accent: accent,
                      icon: Icons.child_care_rounded,
                      label: 'Minors',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ArtWidePanel(
              accent: accent,
              icon: Icons.verified_user_rounded,
              title: 'Trusted support',
              subtitle: 'Safer supervised payments',
            ),
          ],
        );
      default:
        return Column(
          children: [
            _ArtWidePanel(
              accent: accent,
              icon: Icons.workspace_premium_rounded,
              title: 'Cashback route',
              subtitle: 'Choose the best paying option',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ArtPanel(
                accent: accent,
                icon: Icons.receipt_long_rounded,
                label: 'Proof saved locally',
              ),
            ),
          ],
        );
    }
  }
}

class _ArtPanel extends StatelessWidget {
  const _ArtPanel({
    required this.accent,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _ArtBubble(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: accent,
                icon: icon,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtWidePanel extends StatelessWidget {
  const _ArtWidePanel({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _ArtBubble(
              backgroundColor: accent.withValues(alpha: 0.12),
              foregroundColor: accent,
              icon: icon,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtBubble extends StatelessWidget {
  const _ArtBubble({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: Icon(icon, size: 19),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
