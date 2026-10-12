import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/category_labels.dart';
import '../../auth/application/auth_controller.dart';
import '../../workspace/presentation/workspace_screen.dart';
import 'manager_crud_dialogs.dart';
import 'manager_leave_panel.dart';

/// Manager directory backed exclusively by the authenticated API.
class ApiManagerStaffScreen extends StatefulWidget {
  const ApiManagerStaffScreen({super.key});
  @override
  State<ApiManagerStaffScreen> createState() => _ApiManagerStaffScreenState();
}

class _ApiManagerStaffScreenState extends State<ApiManagerStaffScreen> {
  List<AppUser> _rows = const [];
  String? _error;
  bool _loading = true;
  int _request = 0;
  late AuthController _auth;
  Object? _session;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _session = _auth.currentUser;
    _auth.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (identical(_session, _auth.currentUser)) return;
    _session = _auth.currentUser;
    ++_request;
    if (mounted) {
      setState(() {
        _rows = const [];
        _error = null;
        _loading = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user?.role != UserRole.manager || user?.branchId == null) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().request(
        'GET',
        'users/branch/${Uri.encodeComponent(user!.branchId!)}',
      ) as List;
      if (!mounted ||
          request != _request ||
          !identical(user, _auth.currentUser)) {
        return;
      }
      setState(() {
        _rows = List.unmodifiable(
          data.map(
            (r) => AppUser.fromJson(Map<String, dynamic>.from(r as Map)),
          ),
        );
      });
    } on ApiException catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _edit([AppUser? person]) async {
    final user = _auth.currentUser;
    await showApiStaffEditor(context, person);
    if (mounted && identical(user, _auth.currentUser)) await _load();
  }

  @override
  void dispose() {
    ++_request;
    _auth.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quản lý Nhân viên'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Thêm nhân viên'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text(
            'Đội ngũ của bạn',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${_rows.length} nhân viên',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const ManagerLeavePanel(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const WorkspaceScreen(),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Quản lý ca làm'),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              ),
            )
          else if (_rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có nhân viên. Thêm hồ sơ để gửi Boss duyệt.'),
              ),
            )
          else
            ..._rows.map(
              (person) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        child: Text(
                          person.name.isEmpty
                              ? '?'
                              : person.name.characters.first,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(person.email),
                            const SizedBox(height: 6),
                            Text(categoryLabels(person.specializedCategoryIds)),
                            const SizedBox(height: 10),
                            Chip(
                              avatar: Icon(
                                person.isApproved
                                    ? Icons.check_circle_outline
                                    : Icons.schedule,
                                size: 18,
                              ),
                              label: Text(
                                person.isApproved
                                    ? 'Đã duyệt'
                                    : 'Chờ Boss duyệt',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sửa ${person.name}',
                        onPressed: () => _edit(person),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> showApiStaffEditor(BuildContext context, [AppUser? person]) async {
  final auth = context.read<AuthController>();
  final user = auth.currentUser;
  final client = context.read<ApiClient>();
  final revision = client.tokens.revision;
  await showDialog<void>(
    context: context,
    builder: (_) => ManagerCrudDialog.apiStaff(
      user: person,
      save: (body) async {
        if (!identical(user, auth.currentUser) ||
            revision != client.tokens.revision) {
          throw const ApiException(401, 'Phiên đăng nhập đã thay đổi.');
        }
        await client.request(
          person == null ? 'POST' : 'PATCH',
          person == null
              ? 'users/staff'
              : 'users/staff/${Uri.encodeComponent(person.id)}',
          body: body,
        );
        if (!identical(user, auth.currentUser) ||
            revision != client.tokens.revision) {
          throw const ApiException(401, 'Phiên đăng nhập đã thay đổi.');
        }
      },
    ),
  );
}
