import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/storage/cache_store.dart';
import '../core/storage/token_store.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/calendar_repository.dart';
import '../data/repositories/events_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../data/repositories/wellness_repository.dart';

/// Se sobreescribe en `main()` con la instancia ya inicializada, para que el
/// resto de la app pueda leer preferencias de forma síncrona.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider sin inicializar'),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(sharedPreferencesProvider)),
);

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => CacheStore(ref.watch(sharedPreferencesProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(tokenStore: ref.watch(tokenStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final repo = CalendarRepository(
    ref.watch(apiClientProvider),
    ref.watch(cacheStoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(apiClientProvider)),
);

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(ref.watch(apiClientProvider)),
);

final wellnessRepositoryProvider = Provider<WellnessRepository>(
  (ref) => WellnessRepository(ref.watch(apiClientProvider)),
);
