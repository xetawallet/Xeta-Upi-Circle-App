import 'dart:async';
import 'dart:io';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';

import '../controllers/xeta_upi_circle_app_controller.dart';
import '../models/payment_request_record.dart';
import '../models/request_draft.dart';
import '../models/return_transaction.dart';
import '../models/trusted_person.dart';
import '../services/local_circle_storage.dart';
import '../services/request_dispatch_service.dart';
import '../utils/date_labels.dart';
import '../utils/transient_notice.dart';
import '../widgets/request_history_tile.dart';
import '../widgets/trusted_person_tile.dart';
import '../widgets/crypto_donation_content.dart';
import 'scan_screen.dart';

enum _DrawerView { dashboard, faq, donate, settings }

enum _ShareTarget { whatsapp, otherSources }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.controller,
    this.dispatchService,
    this.darkModeEnabled = false,
    this.onDarkModeChanged,
  });

  final XetaUpiCircleAppController? controller;
  final RequestDispatchService? dispatchService;
  final bool darkModeEnabled;
  final ValueChanged<bool>? onDarkModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _faqItems = <_FaqItem>[
    _FaqItem(
      question: 'Why use Xeta UPI Circle App?',
      answer:
          'UPI payments made via credit cards often provide cashback or rewards on most transactions. However, not every family member owns a credit card, and different users may have access to varying offers across UPI apps.\n\nXeta UPI Circle App enables families and trusted groups to collaborate on payments, ensuring that transactions are routed through the most rewarding option available. This helps maximize collective savings through cashback, rewards, and promotional offers.',
    ),
    _FaqItem(
      question: 'How safe is Xeta UPI Circle App?',
      answer:
          'Xeta UPI Circle App is designed to be secure and simple. It is not a standalone payment app; instead, it facilitates coordinated payments among trusted individuals.\n\nFamily members or friends can share QR codes, allowing one person to complete the payment and earn rewards even if they are in a different city. Since transactions are still processed through existing UPI apps and trusted payment networks, users benefit from established security frameworks while optimizing rewards.',
    ),
    _FaqItem(
      question: 'Is Xeta UPI Circle App another UPI app?',
      answer:
          'No. Xeta UPI Circle App is not a separate UPI application. It does not operate its own backend or store sensitive financial data.\n\nThere is no provision to link bank accounts or credit cards within Xeta UPI Circle App. It simply acts as a lightweight layer that helps users collaborate and choose the best available payment method within their trusted network.',
    ),
    _FaqItem(
      question: 'How safe is my data with Xeta UPI Circle App?',
      answer:
          'Your data remains private and secure. All information is stored locally on your device, and Xeta UPI Circle App does not access or transmit this data externally.\n\nYou can locate your saved proof image copies inside the local Xeta UPI Circle App folder created on your device. If you remove those files or clear the app data, the saved transaction proof will be deleted permanently.',
    ),
    _FaqItem(
      question: 'Why are older adults encouraged to use Xeta UPI Circle App?',
      answer:
          'Cybercriminals often target people who may be less familiar with rapidly changing digital scams. Older adults are frequently exposed to phishing, fake support calls, and payment fraud.\n\nXeta UPI Circle App helps by letting a trusted family member handle the payment flow, save proof locally, and keep the process simple without requiring the older adult to navigate risky payment prompts alone.',
    ),
    _FaqItem(
      question:
          'Why are minors under 18 encouraged to use Xeta UPI Circle App?',
      answer:
          'Minors and young users can be more vulnerable to social engineering, impulsive purchases, and scam links shared through chats or social platforms.\n\nXeta UPI Circle App supports a supervised model where parents or guardians can review the request, complete the payment safely, and keep transaction proof on the device for later reference.',
    ),
    _FaqItem(
      question: 'How do transaction records and proof work?',
      answer:
          'A transaction is added after you prepare a payment share. Save a screenshot, message, or cashback amount when it is available. Records and proof stay on this device unless you choose to share them.',
    ),
    _FaqItem(
      question: 'How are contact balances calculated?',
      answer:
          'A shared transaction adds to the amount you owe that contact. Repayments you record subtract from that balance. A negative balance means the contact owes you. These are personal tracking figures; the app does not verify payments.',
    ),
    _FaqItem(
      question: 'Can I remove a transaction?',
      answer:
          'Yes. In Transactions, tap Select to choose several records, or long-press a record to begin selecting. Deleting removes the selected records from local history.',
    ),
    _FaqItem(
      question: 'Are analytics shared or synced?',
      answer:
          'No. Analytics are calculated from transaction and repayment records stored on this device. The app does not sync them to an account or server.',
    ),
  ];

  late final XetaUpiCircleAppController _controller;
  late final RequestDispatchService _dispatchService;
  late final bool _ownsController;

  int _selectedTabIndex = 0;
  int _activePayStep = 1;
  int? _collapsedPayStep;
  _DrawerView _drawerView = _DrawerView.dashboard;
  _ShareTarget _selectedShareTarget = _ShareTarget.whatsapp;
  String? _analyticsSelectedPersonId;
  bool _transactionSelectionMode = false;
  bool _requestingCameraPermission = false;
  bool _requestingContactsPermission = false;
  final Set<String> _selectedTransactionIds = <String>{};
  late Future<_PermissionSnapshot> _permissionSnapshot;

  bool get _isTransactionsPage =>
      _drawerView == _DrawerView.dashboard && _selectedTabIndex == 2;

  bool get _scanSupported {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionSnapshot = _loadPermissionSnapshot();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        XetaUpiCircleAppController(storage: LocalCircleStorage());
    _dispatchService = widget.dispatchService ?? const RequestDispatchService();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _drawerView == _DrawerView.settings) {
      _refreshPermissionSnapshot();
    }
  }

  int _resolvedPayStep() {
    if (_controller.currentDraft == null) {
      return 1;
    }
    if (_activePayStep <= 2) {
      return _activePayStep;
    }
    if (_controller.selectedHelper == null) {
      return 3;
    }
    return _activePayStep;
  }

  bool _canOpenPayStep(int stepNumber) {
    switch (stepNumber) {
      case 1:
        return true;
      case 2:
      case 3:
        return _controller.currentDraft != null;
      case 4:
        return _controller.currentDraft != null &&
            _controller.selectedHelper != null;
    }
    return false;
  }

  void _openPayStep(int stepNumber) {
    if (!_canOpenPayStep(stepNumber)) {
      return;
    }

    setState(() {
      _activePayStep = stepNumber;
      _collapsedPayStep = null;
    });
  }

  void _togglePayStep(int stepNumber) {
    if (!_canOpenPayStep(stepNumber)) return;
    setState(() {
      if (_resolvedPayStep() == stepNumber && _collapsedPayStep != stepNumber) {
        _collapsedPayStep = stepNumber;
      } else {
        _activePayStep = stepNumber;
        _collapsedPayStep = null;
      }
    });
  }

  void _handleSystemBack() {
    if (_transactionSelectionMode && _isTransactionsPage) {
      _exitTransactionSelection();
      return;
    }
    setState(() {
      if (_drawerView != _DrawerView.dashboard) {
        _drawerView = _DrawerView.dashboard;
        _selectedTabIndex = 0;
        _activePayStep = 1;
      } else if (_selectedTabIndex != 0) {
        _selectedTabIndex = 0;
      } else if (_resolvedPayStep() > 1) {
        _activePayStep = _resolvedPayStep() - 1;
      }
    });
  }

  Widget _buildStepNavigation({
    required BuildContext context,
    required VoidCallback? onBack,
    required String nextLabel,
    required VoidCallback? onNext,
    String backLabel = 'Back',
    Widget? nextIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: Text(backLabel, maxLines: 1, softWrap: false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: onNext,
            icon: nextIcon ?? const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(
              nextLabel,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  List<_TransactionGroup> _groupTransactionsByDate() {
    final groups = <String, List<PaymentRequestRecord>>{};

    for (final record in _controller.requestHistory) {
      final key = formatTransactionDate(record.createdAtIso);
      groups.putIfAbsent(key, () => <PaymentRequestRecord>[]).add(record);
    }

    return groups.entries
        .map(
          (entry) => _TransactionGroup(title: entry.key, records: entry.value),
        )
        .toList(growable: false);
  }

  void _enterTransactionSelection() {
    setState(() {
      _transactionSelectionMode = true;
      _selectedTransactionIds.clear();
    });
  }

  void _exitTransactionSelection() {
    setState(() {
      _transactionSelectionMode = false;
      _selectedTransactionIds.clear();
    });
  }

  void _toggleTransactionSelection(PaymentRequestRecord record) {
    setState(() {
      _transactionSelectionMode = true;
      if (!_selectedTransactionIds.add(record.id)) {
        _selectedTransactionIds.remove(record.id);
      }
      if (_selectedTransactionIds.isEmpty) {
        _transactionSelectionMode = false;
      }
    });
  }

  void _toggleSelectAllTransactions() {
    setState(() {
      if (_selectedTransactionIds.length == _controller.requestHistory.length) {
        _selectedTransactionIds.clear();
        _transactionSelectionMode = false;
      } else {
        _selectedTransactionIds
          ..clear()
          ..addAll(_controller.requestHistory.map((record) => record.id));
      }
    });
  }

  Future<void> _confirmDeleteSelectedTransactions() async {
    final ids = Set<String>.from(_selectedTransactionIds);
    final records = _controller.requestHistory
        .where((record) => ids.contains(record.id))
        .toList(growable: false);
    if (records.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${records.length} transaction${records.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'The selected records and proof images saved by this app will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _controller.removeRequests(ids);
    if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!);
      return;
    }
    await _dispatchService.deleteStoredProofImages(
      records.map((record) => record.proofImagePath),
    );
    if (!mounted) return;
    setState(() {
      _transactionSelectionMode = false;
      _selectedTransactionIds.clear();
    });
    _showSnackBar(
      '${records.length} transaction${records.length == 1 ? '' : 's'} deleted.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleSystemBack();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _transactionSelectionMode && _isTransactionsPage
                    ? '${_selectedTransactionIds.length} selected'
                    : switch (_drawerView) {
                        _DrawerView.dashboard => _titleForTab(
                          _selectedTabIndex,
                        ),
                        _DrawerView.faq => 'FAQ',
                        _DrawerView.donate => 'Support Xeta UPI Circle App',
                        _DrawerView.settings => 'Settings',
                      },
              ),
              actions: [
                if (_isTransactionsPage && _transactionSelectionMode) ...[
                  IconButton(
                    tooltip:
                        _selectedTransactionIds.length ==
                            _controller.requestHistory.length
                        ? 'Deselect all'
                        : 'Select all',
                    onPressed: _toggleSelectAllTransactions,
                    icon: Icon(
                      _selectedTransactionIds.length ==
                              _controller.requestHistory.length
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete selected',
                    onPressed:
                        _selectedTransactionIds.isEmpty || _controller.isSaving
                        ? null
                        : _confirmDeleteSelectedTransactions,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  IconButton(
                    tooltip: 'Cancel selection',
                    onPressed: _exitTransactionSelection,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ] else if (_isTransactionsPage)
                  IconButton(
                    tooltip: 'Select transactions',
                    onPressed: _enterTransactionSelection,
                    icon: const Icon(Icons.checklist_rounded),
                  ),
                IconButton(
                  tooltip: widget.darkModeEnabled
                      ? 'Use light theme'
                      : 'Use dark theme',
                  onPressed: widget.onDarkModeChanged == null
                      ? null
                      : () =>
                            widget.onDarkModeChanged!(!widget.darkModeEnabled),
                  icon: Icon(
                    widget.darkModeEnabled
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Image.asset('assets/app_icon.png'),
                            ),
                          ),
                          const SizedBox(width: 14),
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Get Cashback and save as a Family',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard_customize_rounded),
                      title: const Text('Dashboard'),
                      subtitle: const Text(
                        'Pay smarter and archive proof locally',
                      ),
                      selected: _drawerView == _DrawerView.dashboard,
                      onTap: () {
                        setState(() {
                          _drawerView = _DrawerView.dashboard;
                          _transactionSelectionMode = false;
                          _selectedTransactionIds.clear();
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings_rounded),
                      title: const Text('Settings'),
                      subtitle: const Text('Theme and permissions'),
                      selected: _drawerView == _DrawerView.settings,
                      onTap: () {
                        setState(() {
                          _drawerView = _DrawerView.settings;
                          _permissionSnapshot = _loadPermissionSnapshot();
                          _transactionSelectionMode = false;
                          _selectedTransactionIds.clear();
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.quiz_rounded),
                      title: const Text('FAQ'),
                      subtitle: const Text('Answers about safety and usage'),
                      selected: _drawerView == _DrawerView.faq,
                      onTap: () {
                        setState(() {
                          _drawerView = _DrawerView.faq;
                          _transactionSelectionMode = false;
                          _selectedTransactionIds.clear();
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite_rounded),
                      title: const Text('Donate'),
                      subtitle: const Text(
                        'Help app development or buy a coffee',
                      ),
                      selected: _drawerView == _DrawerView.donate,
                      onTap: () {
                        setState(() {
                          _drawerView = _DrawerView.donate;
                          _transactionSelectionMode = false;
                          _selectedTransactionIds.clear();
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedTabIndex = index;
                  _drawerView = _DrawerView.dashboard;
                  _transactionSelectionMode = false;
                  _selectedTransactionIds.clear();
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.payments_rounded),
                  label: 'Pay',
                ),
                NavigationDestination(
                  icon: Icon(Icons.verified_user_rounded),
                  label: 'Contacts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_rounded),
                  label: 'Transactions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_rounded),
                  label: 'Analytics',
                ),
              ],
            ),
            body: SafeArea(
              child: _controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: switch (_drawerView) {
                        _DrawerView.dashboard => _buildMainTab(context),
                        _DrawerView.faq => _buildFaqTab(context),
                        _DrawerView.donate => _buildDonateTab(context),
                        _DrawerView.settings => _buildSettingsTab(context),
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainTab(BuildContext context) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPayTab(context);
      case 1:
        return _buildTrustedContactsTab(context);
      case 2:
        return _buildTransactionsTab(context);
      case 3:
        return _buildAnalyticsTab(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildPayTab(BuildContext context) {
    final draft = _controller.currentDraft;
    final selectedHelper = _controller.selectedHelper;
    final activeStep = _resolvedPayStep();

    return ListView(
      key: const ValueKey('pay_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Color(0xFF18322F), Color(0xFF184B48), Color(0xFF102725)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF112522).withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Get Cashback and save as a Family',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Create a payment request, share it on WhatsApp or other sources, and save the proof locally when the screenshot comes back.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE29A45).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'No backend is used. Trusted contacts, transactions, and proof details stay stored on this device.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFE4B4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _PayStepCard(
          stepNumber: 1,
          title: 'Scan the payment QR',
          subtitle:
              'Scan a UPI QR to begin, or continue to Step 2 if a draft is already ready.',
          isActive: activeStep == 1 && _collapsedPayStep != 1,
          isOpenable: true,
          onTap: () => _togglePayStep(1),
          summary: draft == null
              ? 'Waiting for a QR scan'
              : 'QR ready to review',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _scanSupported ? _scanQr : null,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan QR'),
                  ),
                  OutlinedButton.icon(
                    onPressed: draft == null
                        ? null
                        : () {
                            _controller.clearDraft();
                            setState(() {
                              _activePayStep = 1;
                            });
                          },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (draft != null) ...[
                _MiniSummaryCard(
                  title: 'Scanned QR',
                  subtitle: '${draft.title} · ${draft.subtitle}',
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(height: 16),
              ],
              _buildStepNavigation(
                context: context,
                onBack: () {
                  setState(() {
                    _drawerView = _DrawerView.dashboard;
                    _selectedTabIndex = 0;
                    _activePayStep = 1;
                  });
                },
                nextLabel: 'Continue',
                onNext: draft == null ? null : () => _openPayStep(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PayStepCard(
          stepNumber: 2,
          title: 'Review payment details',
          subtitle:
              'Confirm Pay To, UPI ID, amount, note, and the QR before sharing.',
          isActive: activeStep == 2 && _collapsedPayStep != 2,
          isLocked: draft == null,
          isOpenable: draft != null,
          onTap: draft == null ? null : () => _togglePayStep(2),
          summary: draft == null
              ? 'Complete Step 1 first'
              : 'Review the scanned details',
          child: draft == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PaymentDetailsPreview(draft: draft),
                    const SizedBox(height: 16),
                    _buildStepNavigation(
                      context: context,
                      onBack: () => _openPayStep(1),
                      nextLabel: 'Continue',
                      onNext: () => _openPayStep(3),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _PayStepCard(
          stepNumber: 3,
          title: 'Select your trusted contact for this transaction',
          subtitle:
              'Choose who should receive this payment request and send the proof back.',
          isActive: activeStep == 3 && _collapsedPayStep != 3,
          isLocked: draft == null,
          isOpenable: draft != null,
          onTap: draft == null ? null : () => _togglePayStep(3),
          summary: selectedHelper == null
              ? 'Select a trusted contact'
              : 'Selected: ${selectedHelper.name}',
          child: draft == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_controller.trustedPeople.isEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No trusted contact saved yet.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _openTrustedPersonSheet(),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Add trusted contact'),
                          ),
                        ],
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedHelper?.id ??
                            _controller.trustedPeople.first.id,
                        items: _controller.trustedPeople
                            .map(
                              (person) => DropdownMenuItem<String>(
                                value: person.id,
                                child: Text(
                                  '${person.name} • ${person.phoneNumber}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            _controller.selectHelper(value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Trusted contact',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedTabIndex = 1;
                          });
                        },
                        icon: const Icon(Icons.manage_accounts_rounded),
                        label: const Text('Manage trusted contacts'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildStepNavigation(
                      context: context,
                      onBack: () => _openPayStep(2),
                      nextLabel: 'Continue',
                      onNext: selectedHelper == null
                          ? null
                          : () => _openPayStep(4),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _PayStepCard(
          stepNumber: 4,
          title: 'Select app to share',
          subtitle:
              'Share only through WhatsApp or other sources. The WhatsApp icon stays visible when WhatsApp is selected.',
          isActive: activeStep == 4 && _collapsedPayStep != 4,
          isLocked: draft == null || selectedHelper == null,
          isOpenable: draft != null && selectedHelper != null,
          onTap: draft == null || selectedHelper == null
              ? null
              : () => _togglePayStep(4),
          summary: _selectedShareTarget == _ShareTarget.whatsapp
              ? 'WhatsApp selected'
              : 'Other sources selected',
          child: draft == null || selectedHelper == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShareTargetSelector(
                      selectedTarget: _selectedShareTarget,
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedShareTarget = selection;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedShareTarget == _ShareTarget.whatsapp)
                      _WhatsAppPreviewCard(
                        draft: draft,
                        selectedHelper: selectedHelper,
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'The QR image and payment message will open in the share sheet so you can forward them through any other app.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildStepNavigation(
                      context: context,
                      onBack: () => _openPayStep(3),
                      nextLabel: _selectedShareTarget == _ShareTarget.whatsapp
                          ? 'WhatsApp'
                          : 'Share',
                      onNext: _controller.isSaving ? null : _shareRequest,
                      nextIcon: _controller.isSaving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : (_selectedShareTarget == _ShareTarget.whatsapp
                                ? const FaIcon(
                                    FontAwesomeIcons.whatsapp,
                                    size: 18,
                                  )
                                : const Icon(Icons.share_rounded, size: 18)),
                    ),
                  ],
                ),
        ),
        if (_controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _StatusBanner(
              message: _controller.errorMessage!,
              hasError: true,
            ),
          ),
      ],
    );
  }

  Widget _buildTrustedContactsTab(BuildContext context) {
    return ListView(
      key: const ValueKey('trusted_contacts_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 360;

                return Flex(
                  direction: isCompact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: isCompact
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: [
                    if (isCompact)
                      const _SectionTitle(
                        title: 'Managed trusted contacts',
                        subtitle:
                            'These are the people you trust to pay on your behalf and return the payment proof.',
                      )
                    else
                      const Expanded(
                        child: _SectionTitle(
                          title: 'Managed trusted contacts',
                          subtitle:
                              'These are the people you trust to pay on your behalf and return the payment proof.',
                        ),
                      ),
                    SizedBox(
                      width: isCompact ? 0 : 12,
                      height: isCompact ? 12 : 0,
                    ),
                    FilledButton.icon(
                      onPressed: () => _openTrustedPersonSheet(),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_controller.trustedPeople.isEmpty)
          _EmptyStateCard(
            title: 'No trusted contacts yet',
            description:
                'Add one trusted contact with a phone number so your dashboard can share requests straight away.',
            actionLabel: 'Add trusted contact',
            onAction: () => _openTrustedPersonSheet(),
          )
        else
          ..._controller.trustedPeople.map(
            (person) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TrustedPersonTile(
                person: person,
                isSelected: person.id == _controller.selectedHelper?.id,
                onTap: () => _controller.selectHelper(person.id),
                onEdit: () => _openTrustedPersonSheet(person: person),
                onDelete: () => _deleteTrustedPerson(person),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionsTab(BuildContext context) {
    final transactionGroups = _groupTransactionsByDate();

    return ListView(
      key: const ValueKey('transactions_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _SectionTitle(
              title: _transactionSelectionMode
                  ? 'Select transactions'
                  : 'Transactions',
              subtitle: _transactionSelectionMode
                  ? 'Tap records to select. Long-press also starts selection.'
                  : 'Review requests, save proof locally, or select records to delete.',
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_controller.requestHistory.isEmpty)
          const _EmptyStateCard(
            title: 'No transactions yet',
            description:
                'Shared payment requests will appear here once you send them from the dashboard.',
          )
        else
          ...transactionGroups.expand(
            (group) => [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...group.records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RequestHistoryTile(
                    record: record,
                    isSelected: _selectedTransactionIds.contains(record.id),
                    selectionMode: _transactionSelectionMode,
                    onLongPress: () => _toggleTransactionSelection(record),
                    onTap: () => _transactionSelectionMode
                        ? _toggleTransactionSelection(record)
                        : _openTransactionDetails(record),
                    onSavePayment: () => _openSavePaymentSheet(record),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
      ],
    );
  }

  double _balanceForContact(
    TrustedPerson person,
    List<PaymentRequestRecord> transactions,
  ) {
    final requested = transactions
        .where((record) => record.helper.id == person.id)
        .fold<double>(
          0,
          (sum, record) =>
              sum + (double.tryParse(record.draft.amount ?? '') ?? 0),
        );
    final returned = person.returns.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );
    return requested - returned;
  }

  Widget _buildAnalyticsTab(BuildContext context) {
    double totalSpent = 0;
    double totalCashback = 0;

    final sortedTransactions = List<PaymentRequestRecord>.from(
      _controller.requestHistory,
    )..sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));

    for (final record in sortedTransactions) {
      if (record.draft.amount != null) {
        totalSpent += double.tryParse(record.draft.amount!) ?? 0;
      }
      totalCashback += record.cashbackEarned ?? 0;
    }

    final contactBalances = _controller.trustedPeople
        .map(
          (person) =>
              MapEntry(person, _balanceForContact(person, sortedTransactions)),
        )
        .toList(growable: false);
    final totalOutstanding = contactBalances
        .where((entry) => entry.value > 0)
        .fold<double>(0, (sum, entry) => sum + entry.value);

    TrustedPerson? selectedPerson;
    if (_analyticsSelectedPersonId != null &&
        _controller.trustedPeople.isNotEmpty) {
      selectedPerson = _controller.trustedPeople
          .cast<TrustedPerson?>()
          .firstWhere(
            (p) => p?.id == _analyticsSelectedPersonId,
            orElse: () => null,
          );
    }

    double personCashback = 0;
    final personOwed = selectedPerson == null
        ? 0.0
        : _balanceForContact(selectedPerson, sortedTransactions);
    if (selectedPerson != null) {
      for (final record in sortedTransactions.where(
        (r) => r.helper.id == selectedPerson!.id,
      )) {
        personCashback += record.cashbackEarned ?? 0;
      }
    }
    final repayments =
        _controller.trustedPeople
            .expand(
              (person) => person.returns.map(
                (transaction) => MapEntry(person, transaction),
              ),
            )
            .where(
              (entry) =>
                  selectedPerson == null || entry.key.id == selectedPerson.id,
            )
            .toList()
          ..sort((a, b) => b.value.dateIso.compareTo(a.value.dateIso));

    return ListView(
      key: const ValueKey('analytics_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Total Transaction Amount',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '₹${totalSpent.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Total Cashback',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '₹${totalCashback.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1FA855),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding by contact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You owe ₹${totalOutstanding.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (contactBalances.isEmpty)
                  Text(
                    'Add a contact and share a request to track balances.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...contactBalances.map((entry) {
                    final balance = entry.value;
                    final description = balance > 0
                        ? 'You owe ₹${balance.toStringAsFixed(2)}'
                        : balance < 0
                        ? 'They owe you ₹${balance.abs().toStringAsFixed(2)}'
                        : 'Settled';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Text(
                          entry.key.name.isEmpty
                              ? '?'
                              : entry.key.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(entry.key.name),
                      subtitle: Text(description),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(
                        () => _analyticsSelectedPersonId = entry.key.id,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_controller.trustedPeople.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _analyticsSelectedPersonId,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Persons'),
              ),
              ..._controller.trustedPeople.map(
                (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _analyticsSelectedPersonId = val;
              });
            },
            decoration: const InputDecoration(labelText: 'Filter by Person'),
          ),
          const SizedBox(height: 12),
        ],
        if (_controller.trustedPeople.isNotEmpty) ...[
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE4D9C8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (selectedPerson != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                personOwed > 0
                                    ? 'You owe'
                                    : personOwed < 0
                                    ? 'They owe you'
                                    : 'Current Balance',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              Text(
                                personOwed == 0
                                    ? 'Settled'
                                    : '₹${personOwed.abs().toStringAsFixed(2)}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Cashback Received',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              Text(
                                'Rs $personCashback',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1FA855),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Record Repayment'),
                        onPressed: () =>
                            _openReturnTransactionSheet(selectedPerson!),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Repayments recorded',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (repayments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No repayments recorded yet.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  else
                    ...repayments.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.call_received_rounded),
                        title: Text(
                          '₹${entry.value.amount.toStringAsFixed(2)}',
                        ),
                        subtitle: Text(
                          '${selectedPerson == null ? '${entry.key.name} · ' : ''}${formatTransactionDate(entry.value.dateIso)} · ${entry.value.paidViaApp}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete repayment',
                          onPressed: () =>
                              _deleteReturnTransaction(entry.key, entry.value),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _buildFaqTab(BuildContext context) {
    return ListView(
      key: const ValueKey('faq_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: const _SectionTitle(
              title: 'FAQ',
              subtitle:
                  'Quick answers about how Xeta UPI Circle App works, what stays local, and who it is useful for.',
            ),
          ),
        ),
        const SizedBox(height: 18),
        ..._faqItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FaqCard(item: item),
          ),
        ),
      ],
    );
  }

  Widget _buildDonateTab(BuildContext context) {
    return const CryptoDonationContent();
  }

  Future<_PermissionSnapshot> _loadPermissionSnapshot() async {
    final cameraStatus = await ph.Permission.camera.status;
    PermissionStatus contactStatus;
    try {
      contactStatus = await FlutterContacts.permissions.check(
        PermissionType.read,
      );
    } catch (_) {
      contactStatus = PermissionStatus.notDetermined;
    }
    return _PermissionSnapshot(camera: cameraStatus, contacts: contactStatus);
  }

  void _refreshPermissionSnapshot() {
    unawaited(_refreshPermissionSnapshotAndWait());
  }

  Future<void> _refreshPermissionSnapshotAndWait() async {
    if (!mounted) return;
    final future = _loadPermissionSnapshot();
    setState(() => _permissionSnapshot = future);
    final snapshot = await future;
    if (!mounted) return;
    setState(() => _permissionSnapshot = Future.value(snapshot));
  }

  Future<void> _requestCameraPermission() async {
    setState(() => _requestingCameraPermission = true);
    try {
      final status = await ph.Permission.camera.request();
      final current = await _permissionSnapshot;
      if (!mounted) return;
      final updated = current.copyWith(camera: status);
      setState(() => _permissionSnapshot = Future.value(updated));
    } finally {
      if (mounted) setState(() => _requestingCameraPermission = false);
    }
  }

  Future<void> _requestContactsPermission() async {
    setState(() => _requestingContactsPermission = true);
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      final current = await _permissionSnapshot;
      if (!mounted) return;
      final updated = current.copyWith(contacts: status);
      setState(() => _permissionSnapshot = Future.value(updated));
    } finally {
      if (mounted) setState(() => _requestingContactsPermission = false);
    }
  }

  Future<void> _openSystemPermissionSettings() async {
    await ph.openAppSettings();
  }

  Widget _buildSettingsTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('settings_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _SectionTitle(
              title: 'Preferences',
              subtitle:
                  'Choose how Xeta UPI Circle App looks and review the permissions used by QR scanning and contact import.',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile.adaptive(
            value: widget.darkModeEnabled,
            onChanged: widget.onDarkModeChanged,
            secondary: Icon(
              widget.darkModeEnabled
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: scheme.primary,
            ),
            title: const Text('Dark theme'),
            subtitle: const Text('Remember this choice on this device'),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permissions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Permissions are requested only when you use the related feature.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<_PermissionSnapshot>(
                  future: _permissionSnapshot,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Permission status unavailable'),
                      );
                    }
                    final status = snapshot.data!;
                    return Column(
                      children: [
                        _PermissionStatusTile(
                          title: 'Camera',
                          detail: 'Scan payment QR codes',
                          status: _cameraPermissionLabel(status.camera),
                          onRequest: _requestCameraPermission,
                          isLoading: _requestingCameraPermission,
                        ),
                        _PermissionStatusTile(
                          title: 'Contacts',
                          detail: 'Import a trusted contact',
                          status: _contactsPermissionLabel(status.contacts),
                          onRequest: _requestContactsPermission,
                          isLoading: _requestingContactsPermission,
                        ),
                      ],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _refreshPermissionSnapshot,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                      TextButton.icon(
                        onPressed: _openSystemPermissionSettings,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('System settings'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.volunteer_activism_rounded,
              color: scheme.primary,
            ),
            title: const Text('Donate'),
            subtitle: const Text('View donation details and wallet QR codes'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => setState(() => _drawerView = _DrawerView.donate),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: Icon(Icons.code_rounded, color: scheme.primary),
            title: const Text('GitHub repository'),
            subtitle: const Text('github.com/xetawallet/Xeta-Upi-Circle-App'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: _openRepository,
          ),
        ),
      ],
    );
  }

  String _cameraPermissionLabel(ph.PermissionStatus status) => switch (status) {
    ph.PermissionStatus.granted => 'Granted',
    ph.PermissionStatus.limited => 'Limited access',
    ph.PermissionStatus.permanentlyDenied => 'Blocked in system settings',
    ph.PermissionStatus.restricted => 'Restricted',
    _ => 'Not granted',
  };

  String _contactsPermissionLabel(PermissionStatus status) => switch (status) {
    PermissionStatus.granted => 'Granted',
    PermissionStatus.limited => 'Limited access',
    PermissionStatus.permanentlyDenied => 'Blocked in system settings',
    PermissionStatus.restricted => 'Restricted',
    _ => 'Not granted',
  };

  Future<void> _openRepository() async {
    await launchUrl(
      Uri.parse('https://github.com/xetawallet/Xeta-Upi-Circle-App'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _titleForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Contacts';
      case 2:
        return 'Transactions';
      case 3:
        return 'Analytics';
    }
    return 'Xeta UPI Circle App';
  }

  Future<void> _scanQr() async {
    final rawValue = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (!mounted || rawValue == null) {
      return;
    }

    final scanDetails = await _openScannedDetailsSheet(rawValue);
    if (!mounted || scanDetails == null) {
      return;
    }

    _controller.createDraftFromInput(
      rawInput: rawValue,
      amountText: scanDetails.amount,
      noteText: scanDetails.note,
    );
    setState(() {
      _activePayStep = 2;
    });
  }

  Future<_ScanDetailsResult?> _openScannedDetailsSheet(String rawValue) {
    String? initialAmount;
    String? initialNote;
    if (rawValue.toLowerCase().startsWith('upi://pay')) {
      final uri = Uri.tryParse(rawValue);
      initialAmount = uri?.queryParameters['am'];
      initialNote = uri?.queryParameters['tn'];
    }

    return showModalBottomSheet<_ScanDetailsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScanDetailsSheet(
        initialAmount: initialAmount,
        initialNote: initialNote,
      ),
    );
  }

  Future<void> _openTrustedPersonSheet({TrustedPerson? person}) async {
    final wasEditing = person != null;
    final result = await showModalBottomSheet<TrustedPerson>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TrustedPersonSheet(person: person),
    );

    if (!mounted || result == null) {
      return;
    }

    await _controller.saveTrustedPerson(result);
    if (!mounted) {
      return;
    }
    _showSnackBar(
      wasEditing
          ? '${result.name} updated.'
          : '${result.name} added to your contacts.',
    );
  }

  Future<void> _deleteTrustedPerson(TrustedPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${person.name}?'),
        content: const Text(
          'This only removes the contact from your local device storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deleteTrustedPerson(person.id);
      if (mounted) _showSnackBar('${person.name} removed from contacts.');
    }
  }

  Future<void> _shareRequest() async {
    if (_controller.currentDraft == null) {
      _showSnackBar('Scan a QR first.');
      return;
    }

    if (_controller.trustedPeople.isEmpty) {
      _showSnackBar('Add a trusted contact first.');
      await _openTrustedPersonSheet();
      return;
    }

    final helper = _controller.selectedHelper;
    final draft = _controller.currentDraft;
    if (helper == null || draft == null) {
      _showSnackBar('Select a trusted contact first.');
      return;
    }

    if (helper.phoneNumber.trim().isEmpty) {
      _showSnackBar('Trusted contact needs a WhatsApp phone number.');
      setState(() {
        _selectedTabIndex = 1;
      });
      return;
    }

    final requestId = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      final message = _controller.buildRequestMessage();
      final result = _selectedShareTarget == _ShareTarget.whatsapp
          ? await _dispatchService.sendViaWhatsApp(
              helper: helper,
              message: message,
              draft: draft,
            )
          : await _dispatchService.sendViaOtherSources(
              message: message,
              draft: draft,
            );
      final transactionSaved = await _controller.recordSentRequestWithId(
        channel: result.channel,
        requestId: requestId,
      );
      if (!transactionSaved) {
        if (mounted) {
          _showSnackBar(
            _controller.errorMessage ?? 'Could not save this transaction.',
          );
        }
        return;
      }
      _controller.clearDraft();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedTabIndex = 0;
        _drawerView = _DrawerView.dashboard;
        _activePayStep = 1;
        _collapsedPayStep = 4;
      });
      _showSnackBar(
        _selectedShareTarget == _ShareTarget.whatsapp
            ? 'WhatsApp draft prepared with the QR image.'
            : 'Share sheet opened with the QR image and payment message.',
      );
    } catch (error) {
      _showSnackBar('$error');
    }
  }

  Future<void> _openTransactionDetails(PaymentRequestRecord record) async {
    final currentRecord = _controller.findRequestById(record.id) ?? record;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailsSheet(
        record: currentRecord,
        onSaveProof: () {
          Navigator.of(context).pop();
          _openSavePaymentSheet(currentRecord);
        },
      ),
    );
  }

  Future<void> _openSavePaymentSheet(PaymentRequestRecord record) async {
    final currentRecord = _controller.findRequestById(record.id) ?? record;
    var proofSaved = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavePaymentSheet(
        record: currentRecord,
        dispatchService: _dispatchService,
        onSaveProof: (proofImagePath, proofMessage, cashbackText) async {
          final saved = await _controller.saveProofForRequest(
            requestId: currentRecord.id,
            proofImagePath: proofImagePath,
            proofMessage: proofMessage,
            cashbackEarnedText: cashbackText,
          );
          if (!mounted) {
            return false;
          }
          proofSaved = saved;
          return saved;
        },
      ),
    );
    if (!mounted) return;
    if (proofSaved) {
      _showSnackBar('Proof saved locally for this transaction.');
    } else if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!);
    }
  }

  Future<void> _openReturnTransactionSheet(TrustedPerson person) async {
    final result = await showModalBottomSheet<ReturnTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddReturnTransactionSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    await _controller.addReturnTransaction(person.id, result);
    if (!mounted) {
      return;
    }

    setState(() {}); // Refresh analytics tab
    _showSnackBar('Repayment recorded for ${person.name}.');
  }

  Future<void> _deleteReturnTransaction(
    TrustedPerson person,
    ReturnTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete repayment?'),
        content: Text(
          'Remove ₹${transaction.amount.toStringAsFixed(2)} returned by ${person.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.removeReturnTransaction(person.id, transaction.id);
    if (!mounted) return;
    if (_controller.errorMessage != null) {
      _showSnackBar(_controller.errorMessage!);
    } else {
      _showSnackBar('Repayment deleted.');
    }
  }

  void _showSnackBar(String message) {
    showTransientNotice(context, message);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.hasError});

  final String message;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            (hasError
                    ? const Color(0xFFB74D31)
                    : Theme.of(context).colorScheme.primary)
                .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: hasError
              ? const Color(0xFF8B2E16)
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayStepCard extends StatelessWidget {
  const _PayStepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.summary,
    required this.child,
    this.isLocked = false,
    this.isOpenable = false,
    this.onTap,
  });

  final int stepNumber;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isLocked;
  final bool isOpenable;
  final String summary;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isLocked
        ? Theme.of(context).colorScheme.surfaceContainer
        : (isActive
              ? Theme.of(context).colorScheme.surfaceContainerLow
              : Theme.of(context).colorScheme.surfaceContainerLow);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      child: Card(
        color: backgroundColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: isOpenable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isLocked
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.14),
                      foregroundColor: isLocked
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.primary,
                      child: Text(
                        '$stepNumber',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isActive ? subtitle : summary,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isActive
                          ? Icons.keyboard_arrow_up_rounded
                          : isLocked
                          ? Icons.lock_outline_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (isActive) ...[const SizedBox(height: 16), child],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareTargetSelector extends StatelessWidget {
  const _ShareTargetSelector({
    required this.selectedTarget,
    required this.onSelectionChanged,
  });

  final _ShareTarget selectedTarget;
  final ValueChanged<_ShareTarget> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 390) {
          return SegmentedButton<_ShareTarget>(
            segments: const [
              ButtonSegment<_ShareTarget>(
                value: _ShareTarget.whatsapp,
                label: Text('WhatsApp'),
                icon: FaIcon(FontAwesomeIcons.whatsapp, size: 16),
              ),
              ButtonSegment<_ShareTarget>(
                value: _ShareTarget.otherSources,
                label: Text('Other sources'),
                icon: Icon(Icons.share_rounded),
              ),
            ],
            selected: {selectedTarget},
            onSelectionChanged: (selection) {
              onSelectionChanged(selection.first);
            },
          );
        }

        return Column(
          children: [
            _ShareTargetChoiceCard(
              title: 'WhatsApp',
              subtitle: 'Open a WhatsApp-ready share draft',
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 18,
                color: Color(0xFF1FA855),
              ),
              isSelected: selectedTarget == _ShareTarget.whatsapp,
              onTap: () => onSelectionChanged(_ShareTarget.whatsapp),
            ),
            const SizedBox(height: 10),
            _ShareTargetChoiceCard(
              title: 'Other sources',
              subtitle: 'Use the standard share sheet',
              icon: Icon(
                Icons.share_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              isSelected: selectedTarget == _ShareTarget.otherSources,
              onTap: () => onSelectionChanged(_ShareTarget.otherSources),
            ),
          ],
        );
      },
    );
  }
}

class _ShareTargetChoiceCard extends StatelessWidget {
  const _ShareTargetChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionGroup {
  const _TransactionGroup({required this.title, required this.records});

  final String title;
  final List<PaymentRequestRecord> records;
}

class _PermissionSnapshot {
  const _PermissionSnapshot({required this.camera, required this.contacts});

  final ph.PermissionStatus camera;
  final PermissionStatus contacts;

  _PermissionSnapshot copyWith({
    ph.PermissionStatus? camera,
    PermissionStatus? contacts,
  }) => _PermissionSnapshot(
    camera: camera ?? this.camera,
    contacts: contacts ?? this.contacts,
  );
}

class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.title,
    required this.detail,
    required this.status,
    required this.onRequest,
    required this.isLoading,
  });

  final String title;
  final String detail;
  final String status;
  final VoidCallback onRequest;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isGranted = status == 'Granted' || status == 'Limited access';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isGranted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
        color: isGranted
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text('$detail · $status'),
      trailing: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isGranted
          ? null
          : TextButton(onPressed: onRequest, child: const Text('Grant')),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _TransactionDetailsSheet extends StatelessWidget {
  const _TransactionDetailsSheet({
    required this.record,
    required this.onSaveProof,
  });

  final PaymentRequestRecord record;
  final VoidCallback onSaveProof;

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(record.draft.amount ?? '');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.draft.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to ${record.helper.name} via ${record.channel}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (amount != null) ...[
                const SizedBox(height: 6),
                Text(
                  'You owe ${record.helper.name} ₹${amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _DetailRow(
                label: 'Date',
                value: formatTransactionTimestamp(record.createdAtIso),
              ),
              _DetailRow(label: 'Channel', value: record.channel),
              _DetailRow(
                label: 'UPI ID',
                value: record.draft.upiId ?? 'Not available',
              ),
              _DetailRow(
                label: 'Amount',
                value:
                    record.draft.amount == null || record.draft.amount!.isEmpty
                    ? 'Not specified'
                    : 'Rs ${record.draft.amount}',
              ),
              _DetailRow(
                label: 'Note',
                value: record.draft.note == null || record.draft.note!.isEmpty
                    ? 'Not specified'
                    : record.draft.note!,
              ),
              if (record.cashbackEarned != null && record.cashbackEarned! > 0)
                _DetailRow(
                  label: 'Cashback',
                  value: 'Rs ${record.cashbackEarned}',
                ),
              const SizedBox(height: 18),
              Text(
                'Timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _TimelineTile(
                icon: Icons.send_rounded,
                title: 'Request sent',
                subtitle: _formatTimestamp(record.createdAtIso),
                isComplete: true,
              ),
              const SizedBox(height: 10),
              _TimelineTile(
                icon: Icons.verified_rounded,
                title: 'Proof saved',
                subtitle: record.proofSavedAtIso == null
                    ? 'Waiting for proof image or WhatsApp message'
                    : _formatTimestamp(record.proofSavedAtIso!),
                isComplete: record.isProofSaved,
              ),
              if (record.hasProofImage) ...[
                const SizedBox(height: 18),
                Text(
                  'Saved proof image',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _ProofImagePreview(path: record.proofImagePath),
              ],
              if (record.hasProofMessage) ...[
                const SizedBox(height: 18),
                Text(
                  'Saved WhatsApp message',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SelectableText(
                    record.proofMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSaveProof,
                  icon: Icon(
                    record.isProofSaved
                        ? Icons.verified_rounded
                        : Icons.save_rounded,
                  ),
                  label: Text(
                    record.isProofSaved ? 'Update Proof' : 'Save Proof',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(String iso) {
    return formatTransactionTimestamp(iso);
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isComplete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isComplete
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isComplete
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
                : const Color(0xFFA89A85).withValues(alpha: 0.16),
            foregroundColor: isComplete
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          final labelText = Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          );
          final valueText = Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), valueText],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 86, child: labelText),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

class _ScanDetailsResult {
  const _ScanDetailsResult({this.amount, this.note});

  final String? amount;
  final String? note;
}

class _ImportedTrustedContact {
  const _ImportedTrustedContact({
    required this.name,
    required this.phoneNumber,
  });

  final String name;
  final String phoneNumber;
}

class _ScanDetailsSheet extends StatefulWidget {
  const _ScanDetailsSheet({this.initialAmount, this.initialNote});

  final String? initialAmount;
  final String? initialNote;

  @override
  State<_ScanDetailsSheet> createState() => _ScanDetailsSheetState();
}

class _ScanDetailsSheetState extends State<_ScanDetailsSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount ?? '');
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add amount and note',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These details will appear below the UPI ID in the request you share.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _ScanDetailsResult(
                          amount: _amountController.text.trim(),
                          note: _noteController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Use this QR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustedPersonSheet extends StatefulWidget {
  const _TrustedPersonSheet({this.person});

  final TrustedPerson? person;

  @override
  State<_TrustedPersonSheet> createState() => _TrustedPersonSheetState();
}

class _TrustedPersonSheetState extends State<_TrustedPersonSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isImportingContact = false;

  bool get _supportsContactImport =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.person?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.person?.phoneNumber ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _importFromContacts() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isImportingContact = true;
    });

    try {
      final permissionStatus = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      if (!mounted) {
        return;
      }

      if (permissionStatus != PermissionStatus.granted &&
          permissionStatus != PermissionStatus.limited) {
        _showSnackBar(_permissionMessage(permissionStatus));
        return;
      }

      final contactId = await FlutterContacts.native.showPicker();
      if (!mounted || contactId == null || contactId.isEmpty) {
        return;
      }

      final contact = await FlutterContacts.get(
        contactId,
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (!mounted || contact == null) {
        _showSnackBar('The selected contact could not be loaded.');
        return;
      }

      final importedContact = _importedTrustedContactFrom(contact);
      if (importedContact == null) {
        _showSnackBar(
          'The selected contact needs both a saved name and phone number.',
        );
        return;
      }

      _nameController.text = importedContact.name;
      _phoneController.text = importedContact.phoneNumber;
      _showSnackBar('Imported ${importedContact.name} from contacts.');
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message ?? 'Unable to import from contacts.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to import from contacts right now.');
    } finally {
      if (mounted) {
        setState(() {
          _isImportingContact = false;
        });
      }
    }
  }

  _ImportedTrustedContact? _importedTrustedContactFrom(Contact contact) {
    final name = _contactName(contact);
    final phoneNumber = _contactPhone(contact);
    if (name == null || phoneNumber == null) {
      return null;
    }

    return _ImportedTrustedContact(name: name, phoneNumber: phoneNumber);
  }

  String? _contactName(Contact contact) {
    final displayName = contact.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final parts = <String>[
      contact.name?.prefix?.trim() ?? '',
      contact.name?.first?.trim() ?? '',
      contact.name?.middle?.trim() ?? '',
      contact.name?.last?.trim() ?? '',
      contact.name?.suffix?.trim() ?? '',
    ].where((value) => value.isNotEmpty).toList(growable: false);

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }

  String? _contactPhone(Contact contact) {
    Phone? selectedPhone;

    for (final phone in contact.phones) {
      if (phone.isPrimary == true && phone.number.trim().isNotEmpty) {
        selectedPhone = phone;
        break;
      }
    }

    selectedPhone ??= contact.phones.cast<Phone?>().firstWhere(
      (phone) => phone != null && phone.number.trim().isNotEmpty,
      orElse: () => null,
    );

    return selectedPhone?.number.trim();
  }

  String _permissionMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return 'Contacts permission is blocked. Please allow it in system settings.';
      case PermissionStatus.denied:
      case PermissionStatus.notDetermined:
        return 'Contacts permission is needed to import a trusted contact.';
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return 'Contacts are available.';
    }
  }

  void _showSnackBar(String message) {
    showTransientNotice(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.person == null
                        ? 'Add trusted contact'
                        : 'Edit trusted contact',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add the WhatsApp phone number for the family member or trusted person who will make the payment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_supportsContactImport) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isImportingContact
                          ? null
                          : _importFromContacts,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _isImportingContact
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.contacts_rounded, size: 18),
                      label: const Text('Import from contacts'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp phone number',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'WhatsApp phone number is required'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }

                        Navigator.of(context).pop(
                          TrustedPerson(
                            id:
                                widget.person?.id ??
                                DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                            name: _nameController.text.trim(),
                            phoneNumber: _phoneController.text.trim(),
                          ),
                        );
                      },
                      child: Text(
                        widget.person == null ? 'Add contact' : 'Save changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailsPreview extends StatelessWidget {
  const _PaymentDetailsPreview({required this.draft});

  final RequestDraft draft;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = draft.amount?.trim();
    final note = draft.note?.trim();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              _DetailRow(label: 'Pay To', value: draft.title),
              _DetailRow(
                label: 'UPI ID',
                value: draft.upiId?.trim().isNotEmpty == true
                    ? draft.upiId!.trim()
                    : '-',
              ),
              _DetailRow(
                label: 'Amount',
                value: amount?.isNotEmpty == true ? '₹$amount' : '-',
              ),
              _DetailRow(
                label: 'Note',
                value: note?.isNotEmpty == true ? note! : '-',
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 340;
                  final qrPreview = Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: PrettyQrView.data(
                      data: draft.qrValue,
                      decoration: const PrettyQrDecoration(
                        shape: PrettyQrSmoothSymbol(color: Color(0xFF132B29)),
                        background: Colors.white,
                        quietZone: PrettyQrQuietZone.modules(2),
                      ),
                    ),
                  );
                  final details = Text(
                    'Scan to pay this request with your UPI app.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        qrPreview,
                        const SizedBox(height: 12),
                        details,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      qrPreview,
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhatsAppPreviewCard extends StatelessWidget {
  const _WhatsAppPreviewCard({
    required this.draft,
    required this.selectedHelper,
  });

  final RequestDraft draft;
  final TrustedPerson? selectedHelper;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final qrCard = Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: PrettyQrView.data(
              data: draft.qrValue,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSmoothSymbol(color: Color(0xFF132B29)),
                background: Colors.white,
                quietZone: PrettyQrQuietZone.modules(2),
              ),
            ),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 18,
                    color: Color(0xFF1FA855),
                  ),
                  Text(
                    'WhatsApp preview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Pay To: ${draft.title}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'UPI ID: ${draft.upiId ?? 'Not available'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (draft.amount != null && draft.amount!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Amount: Rs ${draft.amount}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (draft.note != null && draft.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Note: ${draft.note}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (selectedHelper != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Trusted contact: ${selectedHelper!.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF0C5F59),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [qrCard, const SizedBox(height: 14), content],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              qrCard,
              const SizedBox(width: 16),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _SavePaymentSheet extends StatefulWidget {
  const _SavePaymentSheet({
    required this.record,
    required this.dispatchService,
    required this.onSaveProof,
  });

  final PaymentRequestRecord record;
  final RequestDispatchService dispatchService;
  final Future<bool> Function(
    String? proofImagePath,
    String? proofMessage,
    String? cashbackText,
  )
  onSaveProof;

  @override
  State<_SavePaymentSheet> createState() => _SavePaymentSheetState();
}

class _SavePaymentSheetState extends State<_SavePaymentSheet> {
  late final TextEditingController _proofMessageController;
  late final TextEditingController _cashbackController;
  String? _proofImagePath;
  bool _isPickingImage = false;
  bool _isSavingProof = false;

  @override
  void initState() {
    super.initState();
    _proofMessageController = TextEditingController(
      text: widget.record.proofMessage ?? '',
    );
    _cashbackController = TextEditingController(
      text: widget.record.cashbackEarned?.toString() ?? '',
    );
    _proofImagePath = widget.record.proofImagePath;
  }

  @override
  void dispose() {
    _proofMessageController.dispose();
    _cashbackController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    setState(() {
      _isPickingImage = true;
    });
    try {
      final path = await widget.dispatchService.pickAndStoreProofImage();
      if (!mounted || path == null) {
        return;
      }
      setState(() {
        _proofImagePath = path;
      });
      showTransientNotice(
        context,
        'Proof image selected and copied into Xeta UPI Circle App.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showTransientNotice(context, '$error');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _saveProof() async {
    final proofMessage = _proofMessageController.text.trim();
    final cashbackText = _cashbackController.text.trim();
    if ((_proofImagePath == null || _proofImagePath!.isEmpty) &&
        proofMessage.isEmpty &&
        cashbackText.isEmpty) {
      showTransientNotice(
        context,
        'Add a proof image, message, or cashback earned before saving.',
      );
      return;
    }

    setState(() {
      _isSavingProof = true;
    });
    final saved = await widget.onSaveProof(
      _proofImagePath,
      proofMessage.isEmpty ? null : proofMessage,
      cashbackText.isEmpty ? null : cashbackText,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingProof = false;
    });
    if (saved) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save proof',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Store the proof image and WhatsApp message locally so you can refer to this transaction later.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _PaymentDetailsPreview(draft: widget.record.draft),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isPickingImage ? null : _pickProofImage,
                  icon: _isPickingImage
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Save proof image'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This opens your file picker so you can choose the payment screenshot from WhatsApp.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_proofImagePath != null && _proofImagePath!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ProofImagePreview(path: _proofImagePath),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _proofMessageController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp message',
                  hintText: 'Paste the payment confirmation message here',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cashbackController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cashback Earned (INR)',
                  hintText: 'Optional',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSavingProof ? null : _saveProof,
                  icon: _isSavingProof
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save proof locally'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProofImagePreview extends StatelessWidget {
  const _ProofImagePreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return const SizedBox.shrink();
    }

    final file = File(path!);
    final exists = file.existsSync();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: exists
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: MediaQuery.sizeOf(context).height < 760
                          ? 220
                          : 300,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Saved proof image could not be previewed.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton.filledTonal(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.9),
                                child: SafeArea(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: InteractiveViewer(
                                          child: Image.file(file),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_full_rounded),
                        tooltip: 'Preview full screen',
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    path!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Saved proof image could not be loaded from:\n$path',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          iconColor: Theme.of(context).colorScheme.primary,
          title: Text(
            item.question,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            Text(
              item.answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _AddReturnTransactionSheet extends StatefulWidget {
  const _AddReturnTransactionSheet();

  @override
  State<_AddReturnTransactionSheet> createState() =>
      _AddReturnTransactionSheetState();
}

class _AddReturnTransactionSheetState
    extends State<_AddReturnTransactionSheet> {
  final _amountController = TextEditingController();
  final _appController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _amountController.dispose();
    _appController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submit() {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      showTransientNotice(context, 'Amount is required');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showTransientNotice(context, 'Enter a valid positive amount');
      return;
    }

    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final result = ReturnTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      dateIso: dt.toIso8601String(),
      paidViaApp: _appController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Repayment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid to Contact (INR)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                        ),
                        label: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 18),
                        label: Text(_selectedTime.format(context)),
                        onPressed: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _appController,
                  decoration: const InputDecoration(
                    labelText: 'Paid via Which App?',
                    hintText: 'e.g. PhonePe, GPay, Cash',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Save Repayment'),
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
