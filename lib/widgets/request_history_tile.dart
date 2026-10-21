import 'package:flutter/material.dart';

import '../models/payment_request_record.dart';
import '../utils/date_labels.dart';

class RequestHistoryTile extends StatelessWidget {
  const RequestHistoryTile({
    super.key,
    required this.record,
    required this.onTap,
    required this.onSavePayment,
    this.isSelected = false,
    this.onLongPress,
    this.selectionMode = false,
  });

  final PaymentRequestRecord record;
  final VoidCallback onTap;
  final VoidCallback onSavePayment;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final timestampLabel = formatTransactionTimestamp(record.createdAtIso);
    final amount = double.tryParse(record.draft.amount ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: record.isProofSaved
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.draft.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: record.isProofSaved
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15)
                          : Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      record.isProofSaved ? 'Proof Saved' : 'Request Sent',
                      style: TextStyle(
                        color: record.isProofSaved
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to ${record.helper.name} via ${record.channel}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (amount != null) ...[
                const SizedBox(height: 4),
                Text(
                  'You owe ${record.helper.name} ₹${amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                timestampLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.hasProofMessage
                    ? 'Saved message proof is available for this transaction.'
                    : record.draft.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (record.cashbackEarned != null &&
                  record.cashbackEarned! > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cashback: ₹${record.cashbackEarned}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 340;

                  return Flex(
                    direction: isCompact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: isCompact
                        ? CrossAxisAlignment.stretch
                        : CrossAxisAlignment.center,
                    children: [
                      if (selectionMode)
                        Expanded(
                          child: Text(
                            isSelected ? 'Selected' : 'Tap to select',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        )
                      else if (!isCompact)
                        Expanded(child: _buildActionButton())
                      else
                        _buildActionButton(),
                      SizedBox(
                        width: isCompact ? 0 : 10,
                        height: isCompact ? 10 : 0,
                      ),
                      Align(
                        alignment: isCompact
                            ? Alignment.centerRight
                            : Alignment.center,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return FilledButton.tonalIcon(
      onPressed: onSavePayment,
      icon: Icon(
        record.isProofSaved ? Icons.verified_rounded : Icons.save_rounded,
      ),
      label: Text(record.isProofSaved ? 'Saved Proof' : 'Save Proof'),
    );
  }
}
