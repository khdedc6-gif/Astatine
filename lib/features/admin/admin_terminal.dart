import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/core/platform/desktop_window_service.dart';
import 'package:astatine_dashboard/features/chemistry/pseudo_3d_beaker.dart';
import 'package:astatine_dashboard/features/profile/subscription_name_effect.dart';
import 'package:astatine_dashboard/features/profile/user_profile_store.dart';

typedef AdminDevFlagLoader = Future<bool?> Function();
typedef AdminCacheClearer = Future<void> Function();
typedef AdminSessionLoader = Future<bool> Function();
typedef AdminMaintenanceLoader = Future<Map<String, dynamic>?> Function();
typedef AdminFullscreenToggler = Future<void> Function();

class AdminTerminalHost extends StatefulWidget {
  const AdminTerminalHost({
    super.key,
    required this.child,
    required this.onForceLogout,
    this.isDevLoader,
    this.cacheClearer,
    this.adminRpc,
    this.sessionLoader,
    this.maintenanceLoader,
    this.fullscreenToggler,
  });

  final Widget child;
  final Future<void> Function() onForceLogout;
  final AdminDevFlagLoader? isDevLoader;
  final AdminCacheClearer? cacheClearer;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  adminRpc;
  final AdminSessionLoader? sessionLoader;
  final AdminMaintenanceLoader? maintenanceLoader;
  final AdminFullscreenToggler? fullscreenToggler;

  @override
  State<AdminTerminalHost> createState() => _AdminTerminalHostState();
}

class AdminTerminalActions extends InheritedWidget {
  const AdminTerminalActions({
    super.key,
    required this.openTerminal,
    required this.toggleFullscreen,
    required super.child,
  });

  final VoidCallback openTerminal;
  final VoidCallback toggleFullscreen;

  static AdminTerminalActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminTerminalActions>();

  @override
  bool updateShouldNotify(AdminTerminalActions oldWidget) =>
      openTerminal != oldWidget.openTerminal ||
      toggleFullscreen != oldWidget.toggleFullscreen;
}

class AdminTerminalTapTarget extends StatefulWidget {
  const AdminTerminalTapTarget({super.key, required this.child});

  final Widget child;

  @override
  State<AdminTerminalTapTarget> createState() => _AdminTerminalTapTargetState();
}

class _AdminTerminalTapTargetState extends State<AdminTerminalTapTarget> {
  Timer? _tapResetTimer;
  int _tapCount = 0;

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final actions = AdminTerminalActions.maybeOf(context);
    if (actions == null) return;

    _tapResetTimer?.cancel();
    _tapCount++;
    if (_tapCount == 5) {
      _tapCount = 0;
      actions.openTerminal();
      return;
    }
    _tapResetTimer = Timer(const Duration(milliseconds: 1400), () {
      _tapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    excludeFromSemantics: true,
    behavior: HitTestBehavior.opaque,
    onTap: _handleTap,
    child: widget.child,
  );
}

class _AdminTerminalHostState extends State<AdminTerminalHost> {
  static const _threeFingerTapWindow = Duration(milliseconds: 800);
  static const _touchMovementTolerance = 24.0;

  bool _terminalOpen = false;
  bool _hasSession = false;
  bool _isDev = false;
  bool _maintenanceEnabled = false;
  bool _maintenanceChecking = true;
  String? _maintenanceMessage;
  Object? _maintenanceError;
  int _maintenanceRefreshRevision = 0;
  Timer? _maintenancePoll;
  StreamSubscription<AuthState>? _authStateSubscription;
  RealtimeChannel? _banStatusChannel;
  String? _watchedBanUserId;
  bool _forcingBannedUserLogout = false;
  final Map<int, Offset> _activeTouchPointers = {};
  Duration? _touchSequenceStartedAt;
  int _maximumTouchCount = 0;
  bool _touchSequenceIsTap = false;

  @override
  void initState() {
    super.initState();
    if (widget.maintenanceLoader == null) {
      final client = Supabase.instance.client;
      _authStateSubscription = client.auth.onAuthStateChange.listen((_) {
        _watchCurrentUserBanStatus();
        unawaited(_verifyCurrentUserBanStatus());
        _refreshMaintenance(markChecking: true);
      });
      _watchCurrentUserBanStatus();
      unawaited(_verifyCurrentUserBanStatus());
      _maintenancePoll = Timer.periodic(const Duration(seconds: 15), (_) {
        _refreshMaintenance();
        unawaited(_verifyCurrentUserBanStatus());
      });
    }
    _refreshMaintenance(markChecking: true);
  }

  @override
  void dispose() {
    _maintenancePoll?.cancel();
    _authStateSubscription?.cancel();
    final channel = _banStatusChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  void _watchCurrentUserBanStatus() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final userId = user?.id;
    if (userId == _watchedBanUserId) return;

    final previousChannel = _banStatusChannel;
    _banStatusChannel = null;
    _watchedBanUserId = userId;
    if (previousChannel != null) {
      unawaited(client.removeChannel(previousChannel));
    }
    if (userId == null) return;

    _banStatusChannel = client
        .channel('account-ban-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            if (client.auth.currentUser?.id != userId) return;
            if (!_isActiveBan(payload.newRecord)) return;
            unawaited(_forceLogoutBannedUser());
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint('Account ban listener failed: $error');
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('Account ban listener status: $status');
          }
        });
  }

  bool _isActiveBan(Map<String, dynamic> record) {
    if (record['is_banned'] != true) return false;
    final untilText = record['banned_until']?.toString();
    if (untilText == null || untilText.isEmpty) return true;
    final until = DateTime.tryParse(untilText);
    return until == null || until.isAfter(DateTime.now().toUtc());
  }

  Future<void> _verifyCurrentUserBanStatus() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || _forcingBannedUserLogout) return;
    try {
      final account = await client
          .from('users')
          .select('is_banned, banned_until')
          .eq('id', user.id)
          .maybeSingle();
      if (client.auth.currentUser?.id != user.id) return;
      if (account != null && _isActiveBan(account)) {
        await _forceLogoutBannedUser();
      }
    } catch (error) {
      debugPrint('Failed to verify current account ban status: $error');
    }
  }

  Future<void> _forceLogoutBannedUser() async {
    if (_forcingBannedUserLogout || !mounted) return;
    _forcingBannedUserLogout = true;
    try {
      await widget.onForceLogout();
    } catch (error) {
      debugPrint('Forced sign-out after account ban failed: $error');
      _forcingBannedUserLogout = false;
    }
  }

  Future<bool?> _loadIsDevFlag() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final row = await Supabase.instance.client
        .from('users')
        .select('is_dev')
        .eq('id', user.id)
        .maybeSingle();
    return row?['is_dev'] as bool?;
  }

  Future<void> _clearLocalCache() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    UserProfileStore.instance.clearMemoryCache();
    SubscriptionTierCache.clear();
    MoleculeTilePainter.clearLabelCache();
  }

  Future<Map<String, dynamic>> _adminRpc(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    final result = await Supabase.instance.client.rpc(
      functionName,
      params: parameters,
    );
    if (result is! Map) {
      throw StateError('Unexpected response from $functionName.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>?> _loadMaintenanceSettings() async {
    return await Supabase.instance.client
        .from('app_runtime_settings')
        .select('maintenance_mode, maintenance_message')
        .eq('id', 1)
        .maybeSingle();
  }

  Future<bool> _loadHasSession() async =>
      Supabase.instance.client.auth.currentUser != null;

  Future<void> _refreshMaintenance({bool markChecking = false}) async {
    final revision = ++_maintenanceRefreshRevision;
    var hasSession = _hasSession;
    if (markChecking && mounted) {
      setState(() {
        _maintenanceChecking = true;
        _maintenanceError = null;
      });
    }

    try {
      hasSession = await (widget.sessionLoader ?? _loadHasSession)();
      final settings =
          await (widget.maintenanceLoader ?? _loadMaintenanceSettings)();
      final enabled = settings?['maintenance_mode'] == true;
      final isDev = hasSession
          ? await (widget.isDevLoader ?? _loadIsDevFlag)() == true
          : false;
      if (!mounted || revision != _maintenanceRefreshRevision) return;

      final message = settings?['maintenance_message']?.toString();
      if (_hasSession != hasSession ||
          _isDev != isDev ||
          _maintenanceEnabled != enabled ||
          _maintenanceMessage != message ||
          _maintenanceChecking ||
          _maintenanceError != null) {
        setState(() {
          _hasSession = hasSession;
          _isDev = isDev;
          _maintenanceEnabled = enabled;
          _maintenanceMessage = message;
          _maintenanceChecking = false;
          _maintenanceError = null;
        });
      }
    } catch (error) {
      if (!mounted || revision != _maintenanceRefreshRevision) return;
      if (_maintenanceError?.toString() != error.toString()) {
        debugPrint('Failed to read global maintenance state: $error');
      }
      if (_maintenanceError?.toString() == error.toString() &&
          !_maintenanceChecking) {
        return;
      }
      setState(() {
        _hasSession = hasSession;
        _maintenanceChecking = false;
        _maintenanceError = error;
      });
    }
  }

  void _toggleTerminal() {
    if (_hasSession && _maintenanceEnabled && !_isDev) return;
    final navigator = ToastService.navigatorKey.currentState;
    if (_terminalOpen) {
      navigator?.maybePop();
      return;
    }
    if (navigator == null) {
      debugPrint(
        'Admin terminal shortcut pressed before app navigator mounted.',
      );
      return;
    }

    _terminalOpen = true;
    showDialog<void>(
      context: navigator.context,
      barrierColor: const Color(0xD900060C),
      builder: (_) => _AdminTerminalDialog(
        isDevLoader: widget.isDevLoader ?? _loadIsDevFlag,
        cacheClearer: widget.cacheClearer ?? _clearLocalCache,
        adminRpc: widget.adminRpc ?? _adminRpc,
        onForceLogout: widget.onForceLogout,
      ),
    ).whenComplete(() => _terminalOpen = false);
  }

  Future<void> _toggleFullscreen() async {
    try {
      await (widget.fullscreenToggler ??
          DesktopWindowService.toggleFullscreen)();
    } catch (error) {
      debugPrint('Unable to toggle desktop fullscreen: $error');
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    if (_activeTouchPointers.isEmpty) {
      _touchSequenceStartedAt = event.timeStamp;
      _maximumTouchCount = 0;
      _touchSequenceIsTap = true;
    }
    _activeTouchPointers[event.pointer] = event.position;
    if (_activeTouchPointers.length > _maximumTouchCount) {
      _maximumTouchCount = _activeTouchPointers.length;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _activeTouchPointers[event.pointer];
    if (start != null &&
        (event.position - start).distance > _touchMovementTolerance) {
      _touchSequenceIsTap = false;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_activeTouchPointers.containsKey(event.pointer)) return;
    final startedAt = _touchSequenceStartedAt;
    if (startedAt == null ||
        event.timeStamp - startedAt > _threeFingerTapWindow) {
      _touchSequenceIsTap = false;
    }
    _activeTouchPointers.remove(event.pointer);
    if (_activeTouchPointers.isNotEmpty) return;

    final isThreeFingerTap = _touchSequenceIsTap && _maximumTouchCount >= 3;
    _resetTouchSequence();
    if (isThreeFingerTap) _toggleTerminal();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_activeTouchPointers.containsKey(event.pointer)) return;
    _activeTouchPointers.remove(event.pointer);
    _touchSequenceIsTap = false;
    if (_activeTouchPointers.isEmpty) _resetTouchSequence();
  }

  void _resetTouchSequence() {
    _activeTouchPointers.clear();
    _touchSequenceStartedAt = null;
    _maximumTouchCount = 0;
    _touchSequenceIsTap = false;
  }

  @override
  Widget build(BuildContext context) {
    final blocked =
        _hasSession &&
        (_maintenanceChecking ||
            _maintenanceError != null ||
            (_maintenanceEnabled && !_isDev));
    return AdminTerminalActions(
      openTerminal: _toggleTerminal,
      toggleFullscreen: _toggleFullscreen,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(
            LogicalKeyboardKey.keyK,
            control: true,
            shift: true,
          ): _toggleTerminal,
          const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
        },
        child: Focus(
          autofocus: !blocked,
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Offstage(offstage: blocked, child: widget.child),
                if (blocked)
                  _MaintenanceScreen(
                    title: _maintenanceError != null
                        ? 'Không thể xác minh dịch vụ'
                        : _maintenanceChecking
                        ? 'Đang kiểm tra hệ thống'
                        : 'Hệ thống đang bảo trì khẩn cấp',
                    message: _maintenanceError != null
                        ? 'Không thể xác minh trạng thái hệ thống. Vui lòng thử lại sau.'
                        : _maintenanceChecking
                        ? 'Đang xác minh trạng thái hệ thống...'
                        : _maintenanceMessage?.trim().isNotEmpty == true
                        ? _maintenanceMessage!
                        : 'Hệ thống đang bảo trì khẩn cấp',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF07131B),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.engineering_outlined,
                        color: Color(0xFF00F5D4),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE7F4F5),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message != title) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9CB2B8),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

enum _TerminalLogType { system, success, error, command }

class _TerminalLog {
  const _TerminalLog(this.text, this.type);

  final String text;
  final _TerminalLogType type;
}

class _AdminTerminalDialog extends StatefulWidget {
  const _AdminTerminalDialog({
    required this.isDevLoader,
    required this.cacheClearer,
    required this.adminRpc,
    required this.onForceLogout,
  });

  final AdminDevFlagLoader isDevLoader;
  final AdminCacheClearer cacheClearer;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  adminRpc;
  final Future<void> Function() onForceLogout;

  @override
  State<_AdminTerminalDialog> createState() => _AdminTerminalDialogState();
}

class _AdminTerminalDialogState extends State<_AdminTerminalDialog> {
  final _commandController = TextEditingController();
  final _commandFocusNode = FocusNode(debugLabel: 'Admin terminal command');
  final _logController = ScrollController();
  final List<_TerminalLog> _logs = [
    const _TerminalLog(
      'ASTATINE ADMIN TERMINAL [v1.0]',
      _TerminalLogType.system,
    ),
    const _TerminalLog(
      'Verifying Supabase is_dev flag...',
      _TerminalLogType.system,
    ),
  ];
  bool _authorized = false;
  bool _checkingIsDev = true;
  bool _executing = false;

  @override
  void initState() {
    super.initState();
    _authorize();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _commandFocusNode.dispose();
    _logController.dispose();
    super.dispose();
  }

  Future<void> _authorize() async {
    try {
      final isDev = await widget.isDevLoader();
      if (!mounted) return;
      final authorized = isDev == true;
      setState(() {
        _authorized = authorized;
        _checkingIsDev = false;
        _logs.add(
          _TerminalLog(
            authorized
                ? 'Access Granted · is_dev=true'
                : 'Access Denied · is_dev=true required',
            authorized ? _TerminalLogType.success : _TerminalLogType.error,
          ),
        );
      });
      _scrollToLatest();
      if (authorized) _requestCommandFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingIsDev = false;
        _logs.add(
          _TerminalLog(
            'is_dev verification failed: $error',
            _TerminalLogType.error,
          ),
        );
      });
      _scrollToLatest();
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logController.hasClients) return;
      _logController.jumpTo(_logController.position.maxScrollExtent);
    });
  }

  void _requestCommandFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_authorized ||
          _checkingIsDev ||
          _executing ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _commandFocusNode.requestFocus();
    });
  }

  void _appendLog(String text, _TerminalLogType type) {
    if (!mounted) return;
    setState(() => _logs.add(_TerminalLog(text, type)));
    _scrollToLatest();
  }

  Future<void> _runCommand(String rawCommand) async {
    final input = rawCommand.trim();
    _commandController.clear();
    if (input.isEmpty) {
      _requestCommandFocus();
      return;
    }
    if (_executing || _checkingIsDev) return;

    final command = input.split(RegExp(r'\s+')).first.toLowerCase();
    _appendLog('> $input', _TerminalLogType.command);
    if (!_authorized) {
      _appendLog(
        'Access denied. No command was executed.',
        _TerminalLogType.error,
      );
      _requestCommandFocus();
      return;
    }

    switch (command) {
      case 'help':
        _appendLog(
          'help  clear  clear-cache  ban  unban  give  shutdown database  maintenance on|off  force-logout  exit',
          _TerminalLogType.system,
        );
        _appendLog(
          'ban <username> <30m|2h|7d|p> <reason>  ·  unban <username>',
          _TerminalLogType.system,
        );
        _appendLog(
          'give <ast|coin> <username> <amount>  ·  give <pro|ultra> <username> <days>',
          _TerminalLogType.system,
        );
        break;
      case 'clear':
        setState(_logs.clear);
        break;
      case 'clear-cache':
        setState(() => _executing = true);
        try {
          await widget.cacheClearer();
          _appendLog(
            'Local in-memory caches cleared.',
            _TerminalLogType.success,
          );
        } catch (error) {
          _appendLog('Cache clear failed: $error', _TerminalLogType.error);
        } finally {
          if (mounted) setState(() => _executing = false);
        }
        break;
      case 'ban':
        await _runBan(input);
        break;
      case 'unban':
        await _runUnban(input);
        break;
      case 'give':
        await _runGive(input);
        break;
      case 'shutdown':
        final parts = input.split(RegExp(r'\s+'));
        if (parts.length != 2 || parts[1].toLowerCase() != 'database') {
          _appendLog('Usage: shutdown database', _TerminalLogType.error);
          break;
        }
        await _setMaintenance(true);
        break;
      case 'maintenance':
        final parts = input.split(RegExp(r'\s+'));
        if (parts.length != 2 ||
            !const {'on', 'off'}.contains(parts[1].toLowerCase())) {
          _appendLog('Usage: maintenance <on|off>', _TerminalLogType.error);
          break;
        }
        await _setMaintenance(parts[1].toLowerCase() == 'on');
        break;
      case 'force-logout':
        setState(() => _executing = true);
        _appendLog(
          'Signing out and returning to login...',
          _TerminalLogType.system,
        );
        try {
          await widget.onForceLogout();
          if (mounted) {
            _appendLog('Sign-out action completed.', _TerminalLogType.success);
            setState(() => _executing = false);
          }
        } catch (error) {
          _appendLog('Logout failed: $error', _TerminalLogType.error);
          if (mounted) setState(() => _executing = false);
        }
        break;
      case 'exit':
        Navigator.of(context).pop();
        break;
      default:
        _appendLog(
          'Unknown command. Type "help" for available commands.',
          _TerminalLogType.error,
        );
        break;
    }
    _requestCommandFocus();
  }

  Future<void> _setMaintenance(bool enabled) async {
    await _executeAdminAction(() async {
      final result = await widget.adminRpc('admin_set_maintenance_mode', {
        'p_enabled': enabled,
        'p_message': 'Hệ thống đang bảo trì khẩn cấp',
      });
      if (result['maintenance_mode'] != enabled) {
        throw StateError('The server did not confirm the requested state.');
      }
      _appendLog(
        enabled
            ? 'Global app maintenance enabled. Non-developer sessions are blocked.'
            : 'Global app maintenance disabled. Normal access restored.',
        _TerminalLogType.success,
      );
    }, failurePrefix: 'Maintenance update failed');
  }

  Future<void> _runBan(String input) async {
    final match = RegExp(
      r'^ban\s+(\S+)\s+(\S+)\s+([\s\S]+)$',
      caseSensitive: false,
    ).firstMatch(input);
    if (match == null) {
      _appendLog(
        'Usage: ban <username> <30m|2h|7d|p> <reason>',
        _TerminalLogType.error,
      );
      return;
    }

    final username = match.group(1)!;
    final duration = match.group(2)!.toLowerCase();
    final reason = match.group(3)!.trim();
    DateTime? bannedUntil;
    if (duration != 'p') {
      final parsed = RegExp(r'^(\d+)(m|h|d)$').firstMatch(duration);
      if (parsed == null) {
        _appendLog(
          'Invalid ban duration. Use a value such as 30m, 2h, 7d, or p.',
          _TerminalLogType.error,
        );
        return;
      }
      final amount = int.tryParse(parsed.group(1)!);
      if (amount == null || amount <= 0 || amount > 36500) {
        _appendLog(
          'Ban duration must be between 1 and 36500 units.',
          _TerminalLogType.error,
        );
        return;
      }
      final delta = switch (parsed.group(2)) {
        'm' => Duration(minutes: amount),
        'h' => Duration(hours: amount),
        _ => Duration(days: amount),
      };
      bannedUntil = DateTime.now().toUtc().add(delta);
    }

    await _executeAdminAction(() async {
      final result = await widget.adminRpc('admin_ban_user', {
        'p_username': username,
        'p_banned_until': bannedUntil?.toIso8601String(),
        'p_reason': reason,
      });
      _appendLog(
        'Banned ${result['username']}${bannedUntil == null ? ' permanently' : ' until ${bannedUntil.toLocal()}'}: $reason',
        _TerminalLogType.success,
      );
    }, failurePrefix: 'Ban failed');
  }

  Future<void> _runUnban(String input) async {
    final parts = input.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      _appendLog('Usage: unban <username>', _TerminalLogType.error);
      return;
    }

    await _executeAdminAction(() async {
      final result = await widget.adminRpc('admin_unban_user', {
        'p_username': parts[1],
      });
      _appendLog('Unbanned ${result['username']}.', _TerminalLogType.success);
    }, failurePrefix: 'Unban failed');
  }

  Future<void> _runGive(String input) async {
    final parts = input.split(RegExp(r'\s+'));
    if (parts.length != 4) {
      _appendLog(
        'Usage: give <ast|coin|ultra|pro> <username> <quantity>',
        _TerminalLogType.error,
      );
      return;
    }

    final kind = parts[1].toLowerCase();
    if (!const {'ast', 'coin', 'ultra', 'pro'}.contains(kind)) {
      _appendLog(
        'Unknown resource "$kind". Use ast, coin, ultra, or pro.',
        _TerminalLogType.error,
      );
      return;
    }
    final quantity = num.tryParse(parts[3]);
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      _appendLog('Quantity must be a positive number.', _TerminalLogType.error);
      return;
    }
    if ((kind == 'ultra' || kind == 'pro') &&
        (quantity % 1 != 0 || quantity > 36500)) {
      _appendLog(
        'Subscription quantity must be whole days (maximum 36500).',
        _TerminalLogType.error,
      );
      return;
    }

    await _executeAdminAction(() async {
      final result = await widget.adminRpc('admin_give_resource', {
        'p_kind': kind,
        'p_username': parts[2],
        'p_quantity': quantity,
      });
      final details = switch (kind) {
        'ast' => '${result['quantity']} AST (balance: ${result['balance']})',
        'coin' => '${result['quantity']} Coin (balance: ${result['balance']})',
        _ =>
          '${kind.toUpperCase()} for ${result['days']} days (expires: ${result['expires_at']})',
      };
      _appendLog(
        'Granted $details to ${result['username']}.',
        _TerminalLogType.success,
      );
    }, failurePrefix: 'Grant failed');
  }

  Future<void> _executeAdminAction(
    Future<void> Function() action, {
    required String failurePrefix,
  }) async {
    setState(() => _executing = true);
    try {
      await action();
    } catch (error) {
      _appendLog('$failurePrefix: $error', _TerminalLogType.error);
    } finally {
      if (mounted) setState(() => _executing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width - 32).clamp(0.0, 760.0);
    final height = (screen.height - 32).clamp(0.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3A3A3A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildLogs()),
                _buildCommandInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: Color(0xFF1F1F1F),
      border: Border(bottom: BorderSide(color: Color(0xFF3A3A3A))),
    ),
    child: Row(
      children: [
        const Icon(Icons.terminal_rounded, color: Color(0xFFCCCCCC), size: 19),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'ASTATINE  /  ADMIN TERMINAL',
            style: TextStyle(
              color: Color(0xFFF2F2F2),
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          _checkingIsDev
              ? 'AUTH'
              : _authorized
              ? 'AUTHORIZED'
              : 'LOCKED',
          style: TextStyle(
            color: _checkingIsDev
                ? const Color(0xFFD7BA7D)
                : _authorized
                ? const Color(0xFF6A9955)
                : const Color(0xFFF14C4C),
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Close terminal',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close_rounded,
            color: Color(0xFFCCCCCC),
            size: 18,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  Widget _buildLogs() => ListView.builder(
    controller: _logController,
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
    itemCount: _logs.length,
    itemBuilder: (context, index) {
      final log = _logs[index];
      final color = switch (log.type) {
        _TerminalLogType.success => const Color(0xFF6A9955),
        _TerminalLogType.error => const Color(0xFFF14C4C),
        _TerminalLogType.command => const Color(0xFFDCDCDC),
        _TerminalLogType.system => const Color(0xFFB8B8B8),
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SelectableText(
          log.text,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.45,
          ),
        ),
      );
    },
  );

  Widget _buildCommandInput() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 16, 14),
    child: Row(
      children: [
        const Text(
          'PS C:\\Astatine>',
          style: TextStyle(
            color: Color(0xFFD7BA7D),
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _commandController,
            focusNode: _commandFocusNode,
            enabled: _authorized && !_checkingIsDev && !_executing,
            onSubmitted: _runCommand,
            textInputAction: TextInputAction.send,
            style: const TextStyle(
              color: Color(0xFFF2F2F2),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            cursorColor: const Color(0xFFF2F2F2),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (_executing)
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF6A9955),
            ),
          ),
      ],
    ),
  );
}
