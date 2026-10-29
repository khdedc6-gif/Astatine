import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/notifications/toast.dart';
import 'package:astatine_dashboard/features/admin/admin_terminal.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/custom_scroll_behavior.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/ui_motion.dart';
import 'package:astatine_dashboard/features/dashboard/main_dashboard.dart';

typedef Authenticator = Future<String?> Function({
  required String email,
  required String password,
});

typedef AccountRegistrar = Future<String?> Function({
  required String email,
  required String password,
  required String fullName,
  required String role,
});

typedef UserProfileLoader = Future<AuthUserProfile> Function();

class AuthService {
  static final _supabase = Supabase.instance.client;

  static Future<AuthUserProfile> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return const AuthUserProfile.guest();

      final email = user.email ?? '';
      final metadataName = user.userMetadata?['full_name'] as String?;
      var displayName = _profileName(metadataName, email);
      var profileEmail = email;
      var role = 'student';

      try {
        final data = await _supabase
            .from('users')
            .select('full_name, email, role')
            .eq('id', user.id)
            .maybeSingle();
        if (data != null) {
          displayName = _profileName(data['full_name'] as String?, email);
          profileEmail = (data['email'] as String?)?.trim().isNotEmpty == true
              ? (data['email'] as String).trim()
              : email;
          final storedRole = (data['role'] as String?)?.trim();
          if (storedRole != null && storedRole.isNotEmpty) role = storedRole;
        }
      } catch (_) {
        // Use the authenticated user's email and metadata if profile lookup fails.
      }

      return AuthUserProfile(
        displayName: displayName,
        email: profileEmail,
        role: role,
        id: user.id,
      );
    } catch (_) {
      return const AuthUserProfile.guest();
    }
  }

  static String _profileName(String? fullName, String email) {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final emailName = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return emailName.isEmpty ? 'User' : emailName;
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

      final user = response.user;
      if (user != null) {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
        });
      }
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    User? user;
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      user = response.user;
    } catch (error) {
      return error.toString();
    }

    if (user == null) return 'Sign-in completed without a user account.';

    Map<String, dynamic>? account;
    try {
      account = await _supabase
          .from('users')
          .select('is_banned, banned_until, ban_reason')
          .eq('id', user.id)
          .maybeSingle();
    } catch (error) {
      try {
        await _supabase.auth.signOut();
      } catch (signOutError) {
        return 'Unable to verify account status ($error); sign-out failed ($signOutError).';
      }
      return 'Unable to verify account status: $error';
    }

    if (account == null) {
      try {
        await _supabase.auth.signOut();
      } catch (error) {
        return 'Account status record is missing; sign-out failed: $error';
      }
      return 'Unable to verify account status: account record is missing.';
    }

    final bannedUntil = DateTime.tryParse(
      account['banned_until']?.toString() ?? '',
    );
    final isCurrentlyBanned =
        account['is_banned'] == true &&
        (bannedUntil == null || bannedUntil.isAfter(DateTime.now().toUtc()));
    if (!isCurrentlyBanned) return null;

    try {
      await _supabase.auth.signOut();
    } catch (error) {
      return 'This account is banned, but sign-out failed: $error';
    }

    final reason = account['ban_reason']?.toString().trim();
    final expiry = bannedUntil == null
        ? 'permanently'
        : 'until ${bannedUntil.toLocal()}';
    return 'Account banned $expiry${reason == null || reason.isEmpty ? '' : ': $reason'}';
  }

  static Future<String> getCurrentUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'guest';

    try {
      final data = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      return data['role'] as String? ?? 'student';
    } catch (_) {
      return 'student';
    }
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

class AuthUserProfile {
  const AuthUserProfile({
    required this.displayName,
    required this.email,
    required this.role,
    this.id,
  });

  const AuthUserProfile.guest()
    : displayName = 'User',
      email = '',
      role = 'guest',
      id = null;

  final String? id;
  final String displayName;
  final String email;
  final String role;
}

class AstatineLoginApp extends StatefulWidget {
  const AstatineLoginApp({
    super.key,
    this.authenticator,
    this.registrar,
    this.profileLoader,
  });

  final Authenticator? authenticator;
  final AccountRegistrar? registrar;
  final UserProfileLoader? profileLoader;

  @override
  State<AstatineLoginApp> createState() => _AstatineLoginAppState();
}

class _AstatineLoginAppState extends State<AstatineLoginApp> {
  String _selectedTheme = 'Campus';

  Future<void> _forceLogout() async {
    await AuthService.signOut();
    final navigator = ToastService.navigatorKey.currentState;
    if (navigator == null) {
      throw StateError('Cannot return to login without a mounted navigator.');
    }
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          selectedTheme: _selectedTheme,
          onThemeChanged: (theme) => setState(() => _selectedTheme = theme),
          authenticator: widget.authenticator,
          registrar: widget.registrar,
          profileLoader: widget.profileLoader,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: ToastService.navigatorKey,
      title: 'Astatine Login',
      scrollBehavior: const CustomScrollBehavior(),
      builder: (context, child) => AdminTerminalHost(
        onForceLogout: _forceLogout,
        child: BlueCursorOverlay(child: child ?? const SizedBox.shrink()),
      ),
      theme: AstatinePalette.themeData(_selectedTheme),
      home: LoginScreen(
        selectedTheme: _selectedTheme,
        onThemeChanged: (theme) => setState(() => _selectedTheme = theme),
        authenticator: widget.authenticator,
        registrar: widget.registrar,
        profileLoader: widget.profileLoader,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.selectedTheme = 'Campus',
    this.onThemeChanged,
    this.authenticator,
    this.registrar,
    this.profileLoader,
  });

  final String selectedTheme;
  final ValueChanged<String>? onThemeChanged;
  final Authenticator? authenticator;
  final AccountRegistrar? registrar;
  final UserProfileLoader? profileLoader;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _signUpFullNameController =
      TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController =
      TextEditingController();
  bool obscurePassword = true;
  bool isVietnamese = true;
  bool loginError = false;
  String? loginErrorMessage;
  bool _isLoggingIn = false;

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _signUpFullNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;
    setState(() {
      loginError = false;
      loginErrorMessage = null;
      _isLoggingIn = true;
    });

    final error = await (widget.authenticator ?? AuthService.signIn)(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoggingIn = false;
        loginError = true;
        loginErrorMessage = error.toLowerCase().startsWith('account banned')
            ? error
            : null;
      });
      return;
    }

    final profile =
        await (widget.profileLoader ?? AuthService.getCurrentUserProfile)();
    if (!mounted) return;
    setState(() => _isLoggingIn = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainLayoutScreen(
          selectedTheme: widget.selectedTheme,
          onThemeChanged: widget.onThemeChanged,
          currentUserName: profile.displayName,
          currentUserEmail: profile.email,
          currentUserRole: profile.role,
          isVietnamese: isVietnamese,
          currentUserId: profile.id,
        ),
      ),
    );
  }

  Future<void> _showSignUpDialog() async {
    final formKey = GlobalKey<FormState>();
    _signUpFullNameController.clear();
    _signUpEmailController.clear();
    _signUpPasswordController.clear();
    var selectedRole = 'student';
    var isSubmitting = false;
    String? submissionError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuildContext, setDialogState) => AlertDialog(
          backgroundColor: _palette.card,
          title: Text(
            isVietnamese ? 'Tạo tài khoản' : 'Create account',
            style: TextStyle(color: _palette.primaryText),
          ),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const Key('signup-full-name'),
                      controller: _signUpFullNameController,
                      style: TextStyle(color: _palette.primaryText),
                      decoration: _inputDecoration(
                        hintText: isVietnamese ? 'Họ và tên' : 'Full name',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? (isVietnamese
                                ? 'Vui lòng nhập họ tên.'
                                : 'Enter your full name.')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup-email'),
                      controller: _signUpEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: _palette.primaryText),
                      decoration: _inputDecoration(
                        hintText: isVietnamese ? 'Email' : 'Email address',
                        prefixIcon: Icons.mail_outline,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return isVietnamese
                              ? 'Email không hợp lệ.'
                              : 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup-password'),
                      controller: _signUpPasswordController,
                      obscureText: true,
                      style: TextStyle(color: _palette.primaryText),
                      decoration: _inputDecoration(
                        hintText: isVietnamese ? 'Mật khẩu' : 'Password',
                        prefixIcon: Icons.lock_outline,
                      ),
                      validator: (value) => (value?.length ?? 0) < 6
                          ? (isVietnamese
                                ? 'Mật khẩu cần ít nhất 6 ký tự.'
                                : 'Password must be at least 6 characters.')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: const Key('signup-role'),
                      initialValue: selectedRole,
                      dropdownColor: _palette.card,
                      style: TextStyle(color: _palette.primaryText),
                      decoration: _inputDecoration(
                        hintText: isVietnamese ? 'Vai trò' : 'Role',
                        prefixIcon: Icons.school_outlined,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'student',
                          child: GlideSelect(
                            selected: selectedRole == 'student',
                            child: Text(isVietnamese ? 'Học sinh' : 'Student'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: GlideSelect(
                            selected: selectedRole == 'teacher',
                            child: Text(isVietnamese ? 'Giáo viên' : 'Teacher'),
                          ),
                        ),
                      ],
                      onChanged: isSubmitting
                          ? null
                          : (role) {
                              if (role != null) {
                                setDialogState(() => selectedRole = role);
                              }
                            },
                    ),
                    if (submissionError != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          submissionError!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text(isVietnamese ? 'Hủy' : 'Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSubmitting = true;
                        submissionError = null;
                      });

                      final error =
                          await (widget.registrar ?? AuthService.signUp)(
                            email: _signUpEmailController.text.trim(),
                            password: _signUpPasswordController.text,
                            fullName: _signUpFullNameController.text.trim(),
                            role: selectedRole,
                          );

                      if (!mounted || !dialogContext.mounted) return;
                      if (error != null) {
                        setDialogState(() {
                          isSubmitting = false;
                          submissionError = error;
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop();
                      ToastService.showSuccess(
                        isVietnamese
                            ? 'Đăng ký thành công. Kiểm tra email để xác nhận tài khoản.'
                            : 'Account created. Check your email to confirm it.',
                      );
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isVietnamese ? 'Đăng ký' : 'Sign up'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 300,
            top: MediaQuery.of(context).size.height / 2 - 300,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _palette.accent.withValues(alpha: 0.24),
                    _palette.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.1, 0.5, 1.0],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                width: MediaQuery.sizeOf(context).width < 472
                    ? MediaQuery.sizeOf(context).width - 32
                    : 440,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: _palette.card.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _palette.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _palette.accent.withValues(alpha: 0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: _palette.accent.withValues(alpha: 0.08),
                      blurRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: SegmentedButton<bool>(
                        key: const Key('login-language-toggle'),
                        segments: [
                          ButtonSegment(
                            value: true,
                            label: GlideSelect(
                              selected: isVietnamese,
                              child: const Text('VI'),
                            ),
                          ),
                          ButtonSegment(
                            value: false,
                            label: GlideSelect(
                              selected: !isVietnamese,
                              child: const Text('EN'),
                            ),
                          ),
                        ],
                        selected: {isVietnamese},
                        onSelectionChanged: (selection) =>
                            setState(() => isVietnamese = selection.first),
                        style: SegmentedButton.styleFrom(
                          foregroundColor: _palette.secondaryText,
                          selectedForegroundColor: _palette.accentText,
                          selectedBackgroundColor: _palette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Logo Astatine
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _palette.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: _palette.accentText,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Astatine',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 22, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isVietnamese
                          ? 'Không gian lớp học và học tập thông minh Astatine.'
                          : 'The Discord-hybrid educational classroom workspace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _palette.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Ô nhập Username hoặc Email
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVietnamese ? 'ĐỊA CHỈ EMAIL' : 'EMAIL',
                          style: TextStyle(
                            color: _palette.secondaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('login-username'),
                          controller: emailController,
                          onSubmitted: (_) => _login(),
                          style: TextStyle(
                            color: _palette.primaryText,
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration(
                            hintText: isVietnamese
                                ? 'Nhập email của bạn'
                                : 'Enter your email',
                            prefixIcon: Icons.person_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Ô nhập Password
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVietnamese ? 'MẬT KHẨU' : 'PASSWORD',
                          style: TextStyle(
                            color: _palette.secondaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('login-password'),
                          controller: passwordController,
                          onSubmitted: (_) => _login(),
                          obscureText: obscurePassword,
                          style: TextStyle(
                            color: _palette.primaryText,
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: _palette.secondaryText,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (loginError) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          loginErrorMessage ??
                              (isVietnamese
                                  ? 'Email hoặc mật khẩu không đúng.'
                                  : 'Incorrect email or password.'),
                          key: const Key('login-error'),
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Nút Log In chính
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoggingIn ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _palette.accent,
                          foregroundColor: _palette.accentText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoggingIn
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _palette.accentText,
                                ),
                              )
                            : Text(
                                isVietnamese ? 'Đăng nhập' : 'Log In',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dòng phụ trợ đăng ký nhanh
                    TextButton(
                      onPressed: _showSignUpDialog,
                      child: Text(
                        isVietnamese
                            ? 'Mới dùng Astatine? Tạo tài khoản'
                            : 'New to Astatine? Create an account',
                        style: TextStyle(
                          color: _palette.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Đường kẻ OR CONNECT WITH
                    Row(
                      children: [
                        Expanded(child: Divider(color: _palette.border)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            isVietnamese
                                ? 'HOẶC KẾT NỐI VỚI'
                                : 'OR CONNECT WITH',
                            style: TextStyle(
                              color: _palette.secondaryText,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: _palette.border)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Hai nút đăng nhập mạng xã hội (Google & Microsoft)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: Icon(
                              Icons.g_mobiledata,
                              color: _palette.primaryText,
                              size: 22,
                            ),
                            label: Text(
                              'Google',
                              style: TextStyle(
                                color: _palette.primaryText,
                                fontSize: 12,
                              ),
                            ),
                            style: _socialButtonStyle(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: Icon(
                              Icons.window,
                              color: _palette.primaryText,
                              size: 16,
                            ),
                            label: Text(
                              'Microsoft',
                              style: TextStyle(
                                color: _palette.primaryText,
                                fontSize: 12,
                              ),
                            ),
                            style: _socialButtonStyle(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: _palette.secondaryText, fontSize: 12),
      prefixIcon: Icon(prefixIcon, color: _palette.secondaryText, size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _palette.input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _palette.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _socialButtonStyle() {
    return OutlinedButton.styleFrom(
      backgroundColor: _palette.card,
      foregroundColor: _palette.canvasText,
      side: BorderSide(color: _palette.border),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
