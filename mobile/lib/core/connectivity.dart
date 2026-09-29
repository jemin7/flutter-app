import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetStatus { online, offline }

final connectivityProvider = StreamProvider<NetStatus>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.contains(ConnectivityResult.none) ? NetStatus.offline : NetStatus.online,
  );
});
