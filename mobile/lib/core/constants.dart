/// Compile-time config:
///   Android emulator:  --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   iOS simulator:     --dart-define=API_BASE_URL=http://localhost:3000
///   Physical device:   your machine's LAN IP, e.g. http://192.168.1.20:3000
///   Release build:     --dart-define=API_BASE_URL=https://`<your-app>`.onrender.com
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

const String kAppVersion = '1.1.0';

const String kTokenKey = 'jwt_token';

/// Menu identifiers returned by the server (single source of truth).
const Map<String, String> kMenuLabels = {
  'dashboard': 'Dashboard',
  'users': 'Users',
  'reports': 'Reports',
  'user_management': 'User Management',
  'settings': 'Settings',
};
