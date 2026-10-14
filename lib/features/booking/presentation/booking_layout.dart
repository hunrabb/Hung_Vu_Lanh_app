import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'booking_banner.dart';

/// Presentation shared by the server-backed and local booking flows.
class BookingLayout extends StatelessWidget {
  const BookingLayout({
    super.key,
    required this.walkIn,
    required this.children,
    required this.confirm,
    this.price,
    this.summary,
  });

  final bool walkIn;
  final List<Widget> children;
  final Widget confirm;
  final String? price, summary;

  @override
  Widget build(BuildContext context) {
    final selectionsKey = GlobalKey();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          walkIn ? 'Tạo lịch nhanh' : 'Đặt lịch',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingBanner(
                    walkIn: walkIn,
                    onBook: () {
                      final target = selectionsKey.currentContext;
                      if (target != null) {
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 350),
                          alignment: 0,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    key: selectionsKey,
                    'DÀNH THỜI GIAN CHO BẠN',
                    style: TextStyle(
                      color: Color(0xFF8D7353),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    walkIn
                        ? 'Một cuộc hẹn chỉn chu.'
                        : 'Diện mạo mới,\nkhởi đầu mới.',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 29,
                      height: 1.2,
                      letterSpacing: -0.9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn dịch vụ yêu thích và thời gian phù hợp với bạn.',
                    style: TextStyle(
                      color: Color(0xFF817368),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Tổng tiền',
                          style: TextStyle(
                            color: Color(0xFF817368),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          price ?? 'Chọn dịch vụ',
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (summary != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        summary!,
                        style: const TextStyle(
                          color: Color(0xFF817368),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    confirm,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookingSection extends StatelessWidget {
  const BookingSection({
    super.key,
    required this.number,
    required this.title,
    required this.children,
  });
  final String number, title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.outline),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1E8DC),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );
}

class BookingNotice extends StatelessWidget {
  const BookingNotice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : AppTheme.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.schedule_outlined,
          size: 18,
          color: error ? Theme.of(context).colorScheme.error : AppTheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: error
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : const Color(0xFF817368),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
