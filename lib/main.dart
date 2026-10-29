import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:astatine_dashboard/core/platform/desktop_window_service.dart';
import 'package:astatine_dashboard/features/auth/authentication.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindowService.initialize();

  // Khởi tạo Supabase
  await Supabase.initialize(
    url: 'https://yjfcmixhjqcfpbigmgps.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqZmNtaXhoanFjZnBiaWdtZ3BzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA4NjE1MzIsImV4cCI6MjEwNjQzNzUzMn0.w0uQ_HhEZCvI5YvbVM3l_RrfE2LV392QkZfLVgCVaaw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.authenticator,
    this.registrar,
    this.profileLoader,
  });

  final Authenticator? authenticator;
  final AccountRegistrar? registrar;
  final UserProfileLoader? profileLoader;

  @override
  Widget build(BuildContext context) {
    return AstatineLoginApp(
      authenticator: authenticator,
      registrar: registrar,
      profileLoader: profileLoader,
    );
  }
}
