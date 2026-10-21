import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../utils/transient_notice.dart';

class DonationWallet {
  const DonationWallet({
    required this.currency,
    required this.network,
    required this.address,
  });

  final String currency;
  final String network;
  final String address;

  static Future<List<DonationWallet>> load() async {
    final json = await rootBundle.loadString('assets/donation_wallets.json');
    final donations =
        (jsonDecode(json) as Map<String, dynamic>)['donations']
            as List<dynamic>;
    return donations
        .map(
          (item) => DonationWallet(
            currency: item['currency'] as String,
            network: item['network'] as String,
            address: item['address'] as String,
          ),
        )
        .toList(growable: false);
  }
}

class CryptoDonationContent extends StatefulWidget {
  const CryptoDonationContent({super.key});

  @override
  State<CryptoDonationContent> createState() => _CryptoDonationContentState();
}

class _CryptoDonationContentState extends State<CryptoDonationContent> {
  late final Future<List<DonationWallet>> _wallets = DonationWallet.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DonationWallet>>(
      future: _wallets,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Donation details are unavailable right now.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final scheme = Theme.of(context).colorScheme;
        return ListView(
          key: const ValueKey('donate_tab'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: scheme.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Support independent development',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Donations are optional and help us keep improving Xeta UPI Circle App. Never share your recovery phrase or private keys.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final wallet in snapshot.data!) ...[
              _DonationWalletCard(wallet: wallet),
              const SizedBox(height: 12),
            ],
            Text(
              'Check the currency and network carefully before sending. Crypto transactions cannot be reversed.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

class _DonationWalletCard extends StatelessWidget {
  const _DonationWalletCard({required this.wallet});

  final DonationWallet wallet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.currency_exchange_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${wallet.currency} · ${wallet.network}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final qrSize = (constraints.maxWidth - 32)
                    .clamp(120.0, 192.0)
                    .toDouble();
                return QrImageView(
                  data: wallet.address,
                  version: QrVersions.auto,
                  size: qrSize,
                  padding: const EdgeInsets.all(10),
                  backgroundColor: Colors.white,
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    wallet.address,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy address',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: wallet.address),
                    );
                    if (!context.mounted) return;
                    showTransientNotice(context, 'Address copied');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
