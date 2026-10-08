/// Public client configuration. Database access is restricted by RLS and RPC
/// grants; a service-role key must never be included in the app.
abstract final class SupabaseConfig {
  static const productionUrl = 'https://rmcppwjygjvvzawkobai.supabase.co';
  static const productionAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJtY3Bwd2p5Z2p2dnphd2tvYmFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5MzM4MTUsImV4cCI6MjEwNjUwOTgxNX0.1w8o6PRkEYV0urZpydcMfUFlazZFoVQh_kdmtn42qgo';
}
