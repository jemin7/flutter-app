import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'external_user.dart';

/// Talks ONLY to our backend (the app never calls jsonplaceholder directly).
class ExternalUsersRepository {
  ExternalUsersRepository(this._dio);

  final Dio _dio;

  Future<List<ExternalUser>> list() async {
    try {
      final res = await _dio.get('/api/external-users');
      final data = (res.data['data'] as List?) ?? const [];
      return data.map((e) => ExternalUser.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<ExternalUser> byId(String id) async {
    try {
      final res = await _dio.get('/api/external-users/$id');
      return ExternalUser.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final externalUsersRepositoryProvider = Provider<ExternalUsersRepository>(
  (ref) => ExternalUsersRepository(ref.watch(dioProvider)),
);

/// autoDispose: cache dies with the screen; pull-to-refresh invalidates it.
final externalUsersProvider = FutureProvider.autoDispose<List<ExternalUser>>(
  (ref) => ref.watch(externalUsersRepositoryProvider).list(),
);

final externalUserByIdProvider = FutureProvider.autoDispose.family<ExternalUser, String>(
  (ref, id) => ref.watch(externalUsersRepositoryProvider).byId(id),
);
