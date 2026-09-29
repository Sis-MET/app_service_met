import 'package:flutter/foundation.dart';

import '../../../core/network/service_met_http_client.dart';
import '../models/bitrix_crm.dart';
import '../models/opportunity_draft.dart';
import 'bitrix_opportunity_api.dart';
import 'form_options_cache.dart';
import 'pending_opportunity_store.dart';

/// Pide la contraseña del técnico para renovar la sesión. [error] explica el
/// intento anterior fallido. Devuelve null si el técnico cancela.
typedef PasswordPrompt = Future<String?> Function(String? error);

enum OpportunitySubmitOutcome {
  /// Registrada en Bitrix24.
  sent,

  /// Guardada en el teléfono para enviarla después.
  savedPending,

  /// Rechazada: el técnico debe corregir los datos.
  failed,
}

class OpportunitySubmitResult {
  final OpportunitySubmitOutcome outcome;
  final PendingOpportunity? record;
  final BitrixApiException? error;
  final bool duplicate;

  const OpportunitySubmitResult._(
    this.outcome, {
    this.record,
    this.error,
    this.duplicate = false,
  });

  int? get leadId => record?.bitrixLeadId;
}

/// Orquesta la API METRICA y la tabla local de oportunidades.
///
/// Regla de oro: primero se guarda en el teléfono (con su UUID) y después se
/// envía. Si la conexión se corta en medio, el siguiente intento manda el
/// mismo UUID y el servidor reconoce el prospecto ya creado.
class OpportunityRepository {
  /// UUIDs que se están enviando ahora, en cualquier pantalla.
  static final Set<String> _inFlight = {};

  final PendingOpportunityStore _store;
  final FormOptionsCache _optionsCache;
  final String? Function() _apiUrl;
  final Future<String?> Function() _loggedUser;
  final BitrixOpportunityApi Function(String baseUrl) _apiFactory;
  BitrixOpportunityApi? _api;

  OpportunityRepository({
    required String? Function() apiUrl,
    required Future<String?> Function() loggedUser,
    PendingOpportunityStore? store,
    FormOptionsCache? optionsCache,
    BitrixOpportunityApi Function(String baseUrl)? apiFactory,
  })  : _apiUrl = apiUrl,
        _loggedUser = loggedUser,
        _store = store ?? PendingOpportunityStore(),
        _optionsCache =
            optionsCache ?? const SharedPreferencesFormOptionsCache(),
        _apiFactory = apiFactory ?? BitrixOpportunityApi.new;

  BitrixOpportunityApi _requireApi() {
    final current = _api;
    if (current != null) return current;
    final url = _apiUrl()?.trim() ?? '';
    if (url.isEmpty) {
      throw const BitrixApiException(
        'No hay un perfil de conexión con la API de METRICA.',
        kind: BitrixApiErrorKind.unavailable,
        code: 'NO_API_PROFILE',
      );
    }
    try {
      return _api = _apiFactory(url);
    } on ServiceMetNetworkException catch (error) {
      throw BitrixApiException(
        error.message,
        kind: BitrixApiErrorKind.unavailable,
        code: error.code,
      );
    }
  }

  Future<BitrixCompanySearch> searchCompanies(
    String query, {
    PasswordPrompt? onAuthRequired,
  }) =>
      _withAuth((api) => api.searchCompanies(query), onAuthRequired);

  Future<List<BitrixContact>> contactsOf(
    int companyId, {
    PasswordPrompt? onAuthRequired,
  }) =>
      _withAuth((api) => api.contactsOf(companyId), onAuthRequired);

  /// Últimas opciones del formulario guardadas en el teléfono.
  Future<BitrixFormOptions?> cachedFormOptions() async {
    try {
      return await _optionsCache.read();
    } catch (error) {
      debugPrint('[Bitrix] no se pudieron leer las opciones guardadas: $error');
      return null;
    }
  }

  /// Descarga las opciones del formulario y las guarda para trabajar sin
  /// conexión. Es un refresco silencioso: sin red o sin sesión devuelve null
  /// y no pide la contraseña.
  Future<BitrixFormOptions?> refreshFormOptions() async {
    final BitrixFormOptions options;
    try {
      options = await _requireApi().formOptions();
    } on BitrixApiException catch (error) {
      debugPrint('[Bitrix] opciones del formulario no disponibles: '
          '${error.code ?? error.kind}');
      return null;
    } catch (error) {
      debugPrint('[Bitrix] opciones del formulario no disponibles: $error');
      return null;
    }
    try {
      await _optionsCache.write(options);
    } catch (error) {
      debugPrint('[Bitrix] no se pudieron guardar las opciones: $error');
    }
    return options;
  }

  /// Guarda sin enviar (sin conexión o por decisión del técnico).
  Future<PendingOpportunity> savePending(OpportunityDraft draft) =>
      _store.save(draft, status: OpportunityStatus.pending);

  /// Registra la oportunidad en Bitrix24. Nunca lanza por falta de red: en
  /// ese caso la deja pendiente y lo informa en el resultado.
  Future<OpportunitySubmitResult> submit(
    OpportunityDraft draft, {
    PasswordPrompt? onAuthRequired,
  }) async {
    if (!draft.hasCompany) {
      throw ArgumentError('Seleccione la empresa de Bitrix24 antes de enviar.');
    }
    if (!_inFlight.add(draft.uuid)) {
      return OpportunitySubmitResult._(
        OpportunitySubmitOutcome.failed,
        error: const BitrixApiException(
          'Esta oportunidad ya se está enviando.',
          kind: BitrixApiErrorKind.rejected,
          code: 'IN_FLIGHT',
        ),
      );
    }
    try {
      final previous = await _store.byUuid(draft.uuid);
      if (previous != null && previous.isSent) {
        return OpportunitySubmitResult._(
          OpportunitySubmitOutcome.sent,
          record: previous,
          duplicate: true,
        );
      }
      await _store.save(
        draft,
        status: OpportunityStatus.sending,
        countAttempt: true,
      );
      try {
        final created = await _withAuth(
          (api) => api.createOpportunity(draft),
          onAuthRequired,
        );
        final record = await _store.markSent(draft.uuid, created.leadId);
        debugPrint(
            '[Bitrix] oportunidad enviada: prospecto #${created.leadId}');
        return OpportunitySubmitResult._(
          OpportunitySubmitOutcome.sent,
          record: record,
          duplicate: created.duplicate,
        );
      } on BitrixApiException catch (error) {
        final keepPending =
            error.retryable || error.kind == BitrixApiErrorKind.authRequired;
        final record = await _store.markFailed(
          draft.uuid,
          status:
              keepPending ? OpportunityStatus.pending : OpportunityStatus.error,
          error: error.message,
        );
        debugPrint('[Bitrix] envío no completado: ${error.code ?? error.kind}');
        return OpportunitySubmitResult._(
          keepPending
              ? OpportunitySubmitOutcome.savedPending
              : OpportunitySubmitOutcome.failed,
          record: record,
          error: error,
        );
      }
    } finally {
      _inFlight.remove(draft.uuid);
    }
  }

  /// Reenvía una oportunidad guardada, con su mismo UUID y contenido.
  Future<OpportunitySubmitResult> resend(
    PendingOpportunity record, {
    PasswordPrompt? onAuthRequired,
  }) =>
      submit(record.draft, onAuthRequired: onAuthRequired);

  Future<List<PendingOpportunity>> list() => _store.list();

  Future<int> countUnsent() => _store.countUnsent();

  Future<bool> discard(String uuid) => _store.discard(uuid);

  /// Ejecuta [operation]; si la sesión venció pide la contraseña (hasta tres
  /// veces si es incorrecta) y reintenta una sola vez.
  Future<T> _withAuth<T>(
    Future<T> Function(BitrixOpportunityApi api) operation,
    PasswordPrompt? onAuthRequired,
  ) async {
    final api = _requireApi();
    try {
      return await operation(api);
    } on BitrixApiException catch (error) {
      if (error.kind != BitrixApiErrorKind.authRequired ||
          onAuthRequired == null) {
        rethrow;
      }
      final usuario = await _loggedUser();
      if (usuario == null || usuario.isEmpty) {
        throw const BitrixApiException(
          'No hay un usuario activo. Cierre sesión e ingrese nuevamente.',
          kind: BitrixApiErrorKind.authRequired,
          code: 'NO_USER',
        );
      }
      String? message;
      for (var attempt = 0; attempt < 3; attempt++) {
        final password = await onAuthRequired(message);
        if (password == null || password.isEmpty) rethrow;
        try {
          await api.authenticate(usuario: usuario, password: password);
        } on BitrixApiException catch (authError) {
          if (authError.kind != BitrixApiErrorKind.authRequired) rethrow;
          message = authError.message;
          continue;
        }
        return operation(api);
      }
      rethrow;
    }
  }

  void close() {
    _api?.close();
    _api = null;
  }
}
