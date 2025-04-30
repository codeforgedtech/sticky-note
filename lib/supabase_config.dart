import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://fbrxkeamnvzqffzqqsks.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZicnhrZWFtbnZ6cWZmenFxc2tzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ3MDY0MjMsImV4cCI6MjA2MDI4MjQyM30.JrOWl0Ix7oYKhqvYUGn0H5Gx0yUqzYJ1c82QO27UiJo';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
