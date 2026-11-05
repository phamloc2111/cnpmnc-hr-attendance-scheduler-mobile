import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import '../features/auth/data/api_auth_repository.dart';
import '../features/auth/domain/auth.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(const SecureTokenStore(FlutterSecureStorage()));
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
