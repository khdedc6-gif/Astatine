// Lucian UX/UI Prompt #062 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#062
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/branding/app_branding_assets.dart';
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
    this.brandingAssetLoader,
  });

  final Authenticator? authenticator;
  final AccountRegistrar? registrar;
  final UserProfileLoader? profileLoader;
  final AppBrandingAssetsLoader? brandingAssetLoader;

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
          brandingAssetLoader: widget.brandingAssetLoader,
          adminTerminalOnForceLogout: _forceLogout,
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
      builder: (context, child) =>
          BlueCursorOverlay(child: child ?? const SizedBox.shrink()),
      theme: AstatinePalette.themeData(_selectedTheme),
      home: LoginScreen(
        selectedTheme: _selectedTheme,
        onThemeChanged: (theme) => setState(() => _selectedTheme = theme),
        authenticator: widget.authenticator,
        registrar: widget.registrar,
        profileLoader: widget.profileLoader,
        brandingAssetLoader: widget.brandingAssetLoader,
        adminTerminalOnForceLogout: _forceLogout,
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
    this.brandingAssetLoader,
    this.adminTerminalOnForceLogout,
  });

  final String selectedTheme;
  final ValueChanged<String>? onThemeChanged;
  final Authenticator? authenticator;
  final AccountRegistrar? registrar;
  final UserProfileLoader? profileLoader;
  final AppBrandingAssetsLoader? brandingAssetLoader;
  final Future<void> Function()? adminTerminalOnForceLogout;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const _shakeCurve = Cubic(0.36, 0.07, 0.19, 0.97);
  static const _learningQuotes =
      <
        ({
          String vietnamese,
          String english,
          String vietnameseAuthor,
          String englishAuthor,
        })
      >[
        (
          vietnamese: 'Tri thức là kho báu sẽ theo chân người sở hữu nó đi khắp mọi nơi.',
          english: 'Knowledge is a treasure that follows its owner everywhere.',
          vietnameseAuthor: 'Tục ngữ Trung Hoa',
          englishAuthor: 'Chinese proverb',
        ),
        (
          vietnamese: 'Hãy sống như thể bạn sẽ chết ngày mai, hãy học như thể bạn sẽ sống mãi mãi.',
          english: 'Live as if you were to die tomorrow. Learn as if you were to live forever.',
          vietnameseAuthor: 'Mahatma Gandhi',
          englishAuthor: 'Mahatma Gandhi',
        ),
        (
          vietnamese: 'Trí tuệ không phải sản phẩm của trường lớp, mà là kết quả của nỗ lực học hỏi suốt đời.',
          english: 'Wisdom is not a product of schooling, but the lifelong effort to learn.',
          vietnameseAuthor: 'Albert Einstein',
          englishAuthor: 'Albert Einstein',
        ),
        (
          vietnamese: 'Học không bao giờ là đau khổ. Đau khổ chỉ đến từ việc không hiểu.',
          english: 'Learning is never painful. Pain comes only from not understanding.',
          vietnameseAuthor: 'John Wooden',
          englishAuthor: 'John Wooden',
        ),
        (
          vietnamese: 'Thất bại là cơ hội học tập mới. Nếu bạn không thất bại, bạn chưa học hết.',
          english: 'Failure is a new opportunity to learn. If you are not failing, you are not learning enough.',
          vietnameseAuthor: 'Zig Ziglar',
          englishAuthor: 'Zig Ziglar',
        ),
      ];

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _signUpFullNameController =
      TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController =
      TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  final _passwordFocusNode = FocusNode(debugLabel: 'Login password');
  late final AnimationController _shakeController;
  late final Animation<Offset> _shakeOffset;
  late final Animation<double> _shakeRotation;
  Timer? _learningQuoteTimer;
  int _learningQuoteIndex = 0;
  bool obscurePassword = true;
  bool isVietnamese = true;
  bool loginError = false;
  String? loginErrorMessage;
  bool _isLoggingIn = false;
  bool _loginSuccess = false;

  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
  Color get _loginCta => widget.selectedTheme == 'Campus'
      ? const Color(0xFFEA580C)
      : _palette.accent;
  Color get _loginCtaText =>
      widget.selectedTheme == 'Campus' ? Colors.black : _palette.accentText;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeOffset = TweenSequence<Offset>([
      _shakeOffsetStep(Offset.zero, const Offset(-9, 0), 15),
      _shakeOffsetStep(const Offset(-9, 0), const Offset(8, 0), 15),
      _shakeOffsetStep(const Offset(8, 0), const Offset(-6, 0), 15),
      _shakeOffsetStep(const Offset(-6, 0), const Offset(4, 0), 15),
      _shakeOffsetStep(const Offset(4, 0), const Offset(-2, 0), 15),
      _shakeOffsetStep(const Offset(-2, 0), Offset.zero, 25),
    ]).animate(_shakeController);
    _shakeRotation = TweenSequence<double>([
      _shakeRotationStep(0, -0.010472, 15),
      _shakeRotationStep(-0.010472, 0.008727, 15),
      _shakeRotationStep(0.008727, 0, 15),
      _shakeRotationStep(0, 0, 55),
    ]).animate(_shakeController);
    _learningQuoteTimer = Timer.periodic(
      const Duration(seconds: 7),
      (_) => setState(() {
        _learningQuoteIndex =
            (_learningQuoteIndex + 1) % _learningQuotes.length;
      }),
    );
    _loadBrandingAssets();
  }

  TweenSequenceItem<Offset> _shakeOffsetStep(
    Offset begin,
    Offset end,
    double weight,
  ) => TweenSequenceItem<Offset>(
    tween: Tween<Offset>(
      begin: begin,
      end: end,
    ).chain(CurveTween(curve: _shakeCurve)),
    weight: weight,
  );

  TweenSequenceItem<double> _shakeRotationStep(
    double begin,
    double end,
    double weight,
  ) => TweenSequenceItem<double>(
    tween: Tween<double>(
      begin: begin,
      end: end,
    ).chain(CurveTween(curve: _shakeCurve)),
    weight: weight,
  );

  void _loadBrandingAssets() {
    final loader = widget.brandingAssetLoader;
    if (loader == null) return;
    unawaited(() async {
      try {
        AppBrandingAssets.publish(await loader());
      } catch (error) {
        debugPrint('Unable to load public app branding images: $error');
      }
    }());
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _signUpFullNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _passwordFocusNode.dispose();
    _learningQuoteTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      loginError = false;
      loginErrorMessage = null;
      _isLoggingIn = true;
      _loginSuccess = false;
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
        _loginSuccess = false;
        loginErrorMessage = error.toLowerCase().startsWith('account banned')
            ? error
            : null;
      });
      if (!_reduceMotion) _shakeController.forward(from: 0);
      return;
    }

    final profile =
        await (widget.profileLoader ?? AuthService.getCurrentUserProfile)();
    if (!mounted) return;
    if (!_reduceMotion) {
      setState(() => _loginSuccess = true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _loginSuccess = false;
      });
    }

    final dashboard = MainLayoutScreen(
      selectedTheme: widget.selectedTheme,
      onThemeChanged: widget.onThemeChanged,
      currentUserName: profile.displayName,
      currentUserEmail: profile.email,
      currentUserRole: profile.role,
      isVietnamese: isVietnamese,
      currentUserId: profile.id,
      brandingAssetLoader: widget.brandingAssetLoader,
    );
    final onForceLogout = widget.adminTerminalOnForceLogout;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => onForceLogout == null
            ? dashboard
            : AdminTerminalHost(onForceLogout: onForceLogout, child: dashboard),
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
                    GlideSelect<String>.dropdown(
                      key: const Key('signup-role'),
                      value: selectedRole,
                      decoration: _inputDecoration(
                        hintText: isVietnamese ? 'Vai trò' : 'Role',
                        prefixIcon: Icons.school_outlined,
                      ),
                      options: [
                        GlideSelectOption(
                          value: 'student',
                          label: isVietnamese ? 'Học sinh' : 'Student',
                        ),
                        GlideSelectOption(
                          value: 'teacher',
                          label: isVietnamese ? 'Giáo viên' : 'Teacher',
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
      backgroundColor: _palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 880;
            return ColoredBox(
              color: _palette.background,
              child: compact
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroPanel(compact: true),
                          ColoredBox(
                            color: _palette.card,
                            child: _buildLoginForm(compact: true),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildHeroPanel(compact: false),
                        ),
                        Expanded(
                          flex: 9,
                          child: ColoredBox(
                            key: const Key('login-form-panel'),
                            color: _palette.card,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: _buildLoginForm(compact: false),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroPanel({required bool compact}) {
    final title = isVietnamese
        ? 'Học tốt hơn,\ncùng nhau mỗi ngày.'
        : 'Make room to learn,\ngrow, and share.';
    return SizedBox(
      key: const Key('login-hero-panel'),
      height: compact ? 384 : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF18181B)),
          ValueListenableBuilder<Map<BrandingAssetSlot, BrandingImageSetting>>(
            valueListenable: AppBrandingAssets.current,
            builder: (context, assets, _) {
              final imageSetting = assets[BrandingAssetSlot.loginBackground];
              if (imageSetting == null) return const SizedBox.shrink();
              return BrandingNetworkImage(
                setting: imageSetting,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Unable to render the login background: $error');
                  return const SizedBox.shrink();
                },
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                  Color(0xF2000000),
                ],
                stops: [0, 0.34, 0.66, 1],
              ),
            ),
          ),
          Positioned(
            right: compact ? -30 : -10,
            top: compact ? 4 : 42,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: compact ? 108 : 220,
              color: Colors.white.withValues(alpha: 0.09),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 22 : 52,
              compact ? 20 : 54,
              compact ? 22 : 52,
              compact ? 18 : 46,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(height: compact ? 16 : 180),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVietnamese ? '' : '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFFFD6B8),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            fontSize: compact ? 25 : 38,
                          ),
                    ),
                    const SizedBox(height: 14),
                    _buildLearningQuote(compact: compact),
                    if (!compact) ...[
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _heroFeature(
                            Icons.groups_rounded,
                            isVietnamese
                                ? 'Lớp học kết nối'
                                : 'Connected classrooms',
                          ),
                          _heroFeature(
                            Icons.task_alt_rounded,
                            isVietnamese
                                ? 'Nhiệm vụ rõ ràng'
                                : 'Focused assignments',
                          ),
                          _heroFeature(
                            Icons.lightbulb_outline_rounded,
                            isVietnamese
                                ? 'Ý tưởng tỏa sáng'
                                : 'Ideas that shine',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningQuote({required bool compact}) {
    final quote = _learningQuotes[_learningQuoteIndex];
    final quoteText = isVietnamese ? quote.vietnamese : quote.english;
    final author = isVietnamese ? quote.vietnameseAuthor : quote.englishAuthor;
    final reduceMotion = _reduceMotion;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: AnimatedSwitcher(
        key: const Key('login-learning-quote'),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 700),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.topStart,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Column(
          key: ValueKey('${isVietnamese ? 'vi' : 'en'}-$_learningQuoteIndex'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“$quoteText”',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: compact ? 13 : null,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '— $author',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFeature(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFC58F)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildLoginForm({required bool compact}) {
    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              isVietnamese ? '' : '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _palette.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SegmentedButton<bool>(
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
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          isVietnamese ? 'Chào mừng trở lại' : 'Welcome back',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _palette.primaryText,
            fontWeight: FontWeight.w800,
            fontSize: 30,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isVietnamese
              ? 'Tiếp tục hành trình học tập của bạn.'
              : 'Pick up where your learning journey left off.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: _palette.secondaryText, height: 1.45),
        ),
        const SizedBox(height: 26),
        Form(
          key: _loginFormKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(
                  isVietnamese
                      ? 'EMAIL HOẶC TÊN NGƯỜI DÙNG'
                      : 'EMAIL OR USERNAME',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('login-username'),
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  autocorrect: false,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  style: TextStyle(color: _palette.primaryText, fontSize: 15),
                  decoration: _inputDecoration(
                    hintText: isVietnamese
                        ? 'Nhập email hoặc tên người dùng'
                        : 'Enter your email or username',
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? (isVietnamese
                            ? 'Vui lòng nhập email hoặc tên người dùng.'
                            : 'Enter your email or username.')
                      : null,
                ),
                const SizedBox(height: 18),
                _fieldLabel(isVietnamese ? 'MẬT KHẨU' : 'PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('login-password'),
                  controller: passwordController,
                  focusNode: _passwordFocusNode,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  obscureText: obscurePassword,
                  onFieldSubmitted: (_) => _login(),
                  style: TextStyle(color: _palette.primaryText, fontSize: 15),
                  decoration: _inputDecoration(
                    hintText: isVietnamese ? 'Nhập mật khẩu' : 'Enter password',
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? (isVietnamese ? 'Hiện mật khẩu' : 'Show password')
                          : (isVietnamese ? 'Ẩn mật khẩu' : 'Hide password'),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: _palette.secondaryText,
                        size: 19,
                      ),
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? (isVietnamese
                            ? 'Vui lòng nhập mật khẩu.'
                            : 'Enter your password.')
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (loginError) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('login-error'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      loginErrorMessage ??
                          (isVietnamese
                              ? 'Email hoặc mật khẩu không đúng.'
                              : 'Incorrect email or password.'),
                      style: const TextStyle(
                        color: Color(0xFF8F1D18),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final collapsed = _isLoggingIn || _loginSuccess;
            return Align(
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                curve: const Cubic(0.34, 1.45, 0.64, 1),
                width: collapsed ? 54 : constraints.maxWidth,
                height: 54,
                child: ElevatedButton(
                  key: const Key('login-submit'),
                  onPressed: collapsed ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _loginSuccess
                        ? const Color(0xFF119C72)
                        : _loginCta,
                    foregroundColor: _loginSuccess
                        ? Colors.white
                        : _loginCtaText,
                    disabledBackgroundColor: _loginSuccess
                        ? const Color(0xFF119C72)
                        : _loginCta,
                    disabledForegroundColor: _loginSuccess
                        ? Colors.white
                        : _loginCtaText,
                    elevation: 2,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(collapsed ? 27 : 17),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: _loginSuccess
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('success'),
                          )
                        : _isLoggingIn
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: _loginCtaText,
                            ),
                          )
                        : Text(
                            isVietnamese ? 'Đăng nhập' : 'Sign in',
                            key: const ValueKey('label'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: _showSignUpDialog,
            style: TextButton.styleFrom(
              foregroundColor: _palette.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(
              isVietnamese
                  ? 'Chưa có tài khoản? Tạo tài khoản mới'
                  : 'Don\'t have an account? Create one',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            isVietnamese
                ? 'Phiên bản beta. Một số tính năng có thể không hoạt động như mong đợi.'
                : 'Beta version. Some features may not work as expected.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: _palette.secondaryText, fontSize: 11),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.all(compact ? 22 : 40),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) => Transform.translate(
          offset: _shakeOffset.value,
          child: Transform.rotate(angle: _shakeRotation.value, child: child),
        ),
        child: formContent,
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: TextStyle(
      color: _palette.secondaryText,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.65,
    ),
  );

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _palette.secondaryText.withValues(alpha: 0.85),
        fontSize: 13,
      ),
      prefixIcon: Icon(prefixIcon, color: _palette.secondaryText, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _palette.input,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _palette.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _palette.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _palette.accent, width: 2),
      ),
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
