import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../data/review_repository.dart';

class ReviewsArguments {
  const ReviewsArguments({
    required this.branchId,
    required this.staffId,
    this.appointmentId,
    this.staffName = 'Thợ cắt',
    this.branchName = 'Cơ sở',
    this.initialTarget = 'branch',
  });
  final String branchId, staffId, staffName, branchName;
  final String initialTarget;
  final String? appointmentId;
}

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.arguments});
  final ReviewsArguments arguments;
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late String _target =
      widget.arguments.initialTarget == 'staff' &&
          widget.arguments.staffId.isNotEmpty
      ? 'staff'
      : 'branch';
  int _rating = 5, _request = 0, _page = 1;
  bool _loading = true, _saving = false;
  Map<String, dynamic> _summary = {};
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _submitted = {};
  String? _error;
  final _comment = TextEditingController();
  String get _targetId => _target == 'branch'
      ? widget.arguments.branchId
      : widget.arguments.staffId;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _request++;
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    final request = ++_request, page = next ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<ReviewRepository>().list(
        _target,
        _targetId,
        page: page,
      );
      if (!mounted || request != _request) return;
      _summary = result;
      _page = page;
      if (!next) _items.clear();
      _items.addAll(
        (result['items'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      if (_items.any(
        (r) => r['appointmentId'] == widget.arguments.appointmentId,
      )) {
        _submitted.add(_target);
      }
    } catch (_) {
      if (mounted && request == _request) {
        _error = 'Không tải được đánh giá. Vui lòng thử lại.';
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || widget.arguments.appointmentId == null) return;
    final auth = context.read<AuthController>(),
        user = context.read<AuthController>().currentUser;
    final revision = auth.apiRepository?.client.tokens.revision;
    bool sameSession() =>
        identical(auth.currentUser, user) &&
        auth.apiRepository?.client.tokens.revision == revision;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ReviewRepository>().submit(
        widget.arguments.appointmentId!,
        _target,
        _rating,
        _comment.text,
      );
      if (!mounted ||
          !identical(auth.currentUser, user) ||
          auth.apiRepository?.client.tokens.revision != revision) {
        return;
      }
      _submitted.add(_target);
      _comment.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')));
      await _load();
    } catch (e) {
      if (mounted && sameSession()) setState(() => _error = e.toString());
    } finally {
      if (mounted && sameSession()) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đánh giá trải nghiệm')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              children: [
                for (final target in [
                  'branch',
                  if (widget.arguments.staffId.isNotEmpty) 'staff',
                ])
                  ChoiceChip(
                    label: Text(target == 'branch' ? 'Cơ sở' : 'Thợ cắt'),
                    selected: _target == target,
                    onSelected: _saving
                        ? null
                        : (_) {
                            setState(() {
                              _target = target;
                              _items.clear();
                              _summary = {};
                            });
                            _load();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _target == 'branch'
                  ? widget.arguments.branchName
                  : widget.arguments.staffName,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _loading ? null : () => _load(),
                child: const Text('Thử lại'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${((_summary['average'] as num?) ?? 0).toStringAsFixed(1)} / 5 · ${_summary['count'] ?? 0} đánh giá',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (widget.arguments.appointmentId != null &&
                !_submitted.contains(_target))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đánh giá buổi hẹn đã hoàn thành',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Wrap(
                        children: [
                          for (var value = 1; value <= 5; value++)
                            IconButton(
                              tooltip: '$value sao',
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _rating = value),
                              icon: Icon(
                                value <= _rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: const Color(0xFFB38B4E),
                                size: 30,
                              ),
                            ),
                        ],
                      ),
                      TextField(
                        controller: _comment,
                        maxLength: 1000,
                        maxLines: 3,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Chia sẻ trải nghiệm (không bắt buộc)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _saving || _loading ? null : _save,
                        child: Text(_saving ? 'Đang gửi…' : 'Gửi đánh giá'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_submitted.contains(_target))
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Bạn đã đánh giá mục này.'),
              ),
            if (!_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có đánh giá nào.'),
              ),
            ..._items.map(
              (r) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['customerName'] as String? ?? 'Khách hàng',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${r['rating']} ★',
                        style: const TextStyle(color: Color(0xFFB38B4E)),
                      ),
                      if ((r['comment'] as String? ?? '').isNotEmpty)
                        Text(r['comment'] as String),
                    ],
                  ),
                ),
              ),
            ),
            if (_items.length < ((_summary['count'] as num?) ?? 0))
              TextButton(
                onPressed: _loading ? null : () => _load(next: true),
                child: const Text('Tải thêm'),
              ),
          ],
        ),
      ),
    ),
  );
}
