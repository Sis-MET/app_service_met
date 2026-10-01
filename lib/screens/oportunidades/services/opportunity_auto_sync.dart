import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../widgets/opportunity_password_prompt.dart';
import 'opportunity_repository.dart';

/// Completa y envía solas las oportunidades pendientes cuando vuelve la
/// conexión con el servidor.
///
/// Se dispara al abrir la app, al volver a ella y cuando el teléfono recupera
/// la red. Que haya red no garantiza llegar al servidor (red interna o VPN):
/// si la primera llamada falla, la pasada termina y se reintenta en el
/// siguiente disparo. Nunca pide la contraseña: si la sesión venció, lo
/// informa en [lastReport] para que el técnico la ingrese desde Servicios ›
/// Oportunidades comerciales.
class OpportunityAutoSync {
  OpportunityAutoSync._();

  static final OpportunityAutoSync instance = OpportunityAutoSync._();

  /// Espera tras recuperar la red, para que la conexión se estabilice.
  static const settleDelay = Duration(seconds: 5);

  /// Separación mínima entre dos pasadas automáticas.
  static const minInterval = Duration(minutes: 2);

  /// Última pasada que tuvo algo que contar (enviadas, por completar o sin
  /// sesión). Las pantallas la escuchan para avisar y refrescar contadores.
  final ValueNotifier<OpportunitySyncReport?> lastReport = ValueNotifier(null);

  String? Function()? _apiUrl;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _timer;
  bool _running = false;
  DateTime? _lastRun;

  /// Empieza a vigilar la conexión. [apiUrl] da la dirección de la API del
  /// perfil de conexión elegido.
  void start({required String? Function() apiUrl}) {
    _apiUrl = apiUrl;
    try {
      _connectivity ??= Connectivity().onConnectivityChanged.listen(
        (results) {
          if (results.any((result) => result != ConnectivityResult.none)) {
            schedule(force: true);
          }
        },
        onError: (Object error) =>
            debugPrint('[Bitrix] conectividad no disponible: $error'),
      );
    } catch (error) {
      debugPrint('[Bitrix] conectividad no disponible: $error');
    }
    schedule();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _connectivity?.cancel();
    _connectivity = null;
    _apiUrl = null;
  }

  /// Programa una pasada. Con [force] no respeta [minInterval] (la red acaba
  /// de volver).
  void schedule({bool force = false}) {
    if (_apiUrl == null) return;
    _timer?.cancel();
    _timer = Timer(settleDelay, () => unawaited(run(force: force)));
  }

  /// Sincroniza ahora. Devuelve null si no había nada pendiente, si ya hay
  /// una pasada en curso o si la última fue hace muy poco.
  Future<OpportunitySyncReport?> run({bool force = false}) async {
    final apiUrl = _apiUrl;
    if (apiUrl == null || _running) return null;
    final last = _lastRun;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < minInterval) {
      return null;
    }
    _running = true;
    final repository = OpportunityRepository(
      apiUrl: apiUrl,
      loggedUser: loggedServiceMetUser,
    );
    try {
      // Sin pendientes no se toca la red.
      if (await repository.countUnsent() == 0) return null;
      final report = await repository.syncPending();
      if (report.sent > 0 ||
          report.linked > 0 ||
          report.needCompany > 0 ||
          report.authRequired) {
        lastReport.value = report;
      }
      return report;
    } catch (error) {
      debugPrint('[Bitrix] sincronización automática fallida: $error');
      return null;
    } finally {
      repository.close();
      _running = false;
      _lastRun = DateTime.now();
    }
  }
}
