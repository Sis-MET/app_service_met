import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notifications/notification_plan.dart';
import 'notifications/notification_snapshot_loader.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Generado desde images/icon_notofy_black.png en res/drawable-*dpi.
  static const String _androidSmallIcon = 'ic_stat_notify';

  /// Tinte del icono en el panel desplegado (Amarillo Métrica oscurecido para
  /// que se lea sobre el fondo claro de la tarjeta de notificación).
  static const Color _androidAccent = Color(0xFFD4A017);

  /// Canales e IDs de versiones anteriores, reemplazados por [NoticeChannel].
  static const _legacyChannels = ['daily_reminders', 'calibration_alerts'];
  static const _legacyIds = [0, 1];

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  /// Payload de la última notificación tocada que el inicio aún no atendió.
  /// Se conserva si el toque abre la app en el login: el inicio lo consume al
  /// montarse.
  final ValueNotifier<String?> pendingTap = ValueNotifier(null);

  bool _initialized = false;
  Future<void>? _refreshing;
  String? _queuedFor;

  Future<void> init() async {
    tz.initializeTimeZones();

    // Android pinta el small icon como máscara: solo usa el alfa y lo tiñe
    // según el fondo (blanco en barra oscura, oscuro en barra clara). Por eso
    // basta un único drawable blanco sobre transparente; el ic_launcher opaco
    // es lo que se veía como un círculo/punto blanco.
    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings(_androidSmallIcon);

    const fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) pendingTap.value = payload;
      },
    );

    // App abierta desde una notificación estando cerrada.
    final launch =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    final launchPayload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      pendingTap.value = launchPayload;
    }

    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Solicitar permisos en Android 13+ (Notificaciones)
      await androidImplementation.requestNotificationsPermission();
      // Crear los canales de entrada hace que aparezcan en los ajustes de
      // Android, donde el técnico puede silenciar cada tipo por separado.
      for (final channel in NoticeChannel.values) {
        await androidImplementation.createNotificationChannel(
          fln.AndroidNotificationChannel(
            channel.id,
            channel.name,
            description: channel.description,
            importance: _importance(channel),
          ),
        );
      }
      for (final id in _legacyChannels) {
        await androidImplementation.deleteNotificationChannel(channelId: id);
      }
    }
    for (final id in _legacyIds) {
      await flutterLocalNotificationsPlugin.cancel(id: id);
    }

    _initialized = true;
  }

  /// Recalcula y reprograma todas las notificaciones para [personal].
  ///
  /// Los datos solo cambian mientras se usa la app, así que basta llamarlo al
  /// entrar al inicio y cada vez que la app pasa a segundo plano: las
  /// notificaciones programadas llegan a su hora aunque la app esté cerrada.
  Future<void> refresh(String personal) async {
    if (!_initialized || personal.trim().isEmpty) return;
    final running = _refreshing;
    if (running != null) {
      // Una sola lectura a la vez; la última petición se repite al terminar.
      _queuedFor = personal;
      return running;
    }
    _refreshing = _refresh(personal);
    try {
      await _refreshing;
    } finally {
      _refreshing = null;
    }
    final queued = _queuedFor;
    _queuedFor = null;
    if (queued != null) await refresh(queued);
  }

  Future<void> _refresh(String personal) async {
    try {
      final snapshot = await NotificationSnapshotLoader().load(personal);
      final now = DateTime.now();
      final planned = planNotifications(snapshot, now);
      final plannedIds = planned.map((notice) => notice.id).toSet();

      for (final id in NoticeIds.all) {
        if (!plannedIds.contains(id)) {
          await flutterLocalNotificationsPlugin.cancel(id: id);
        }
      }
      for (final notice in planned) {
        if (!notice.at.isAfter(now)) continue;
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: notice.id,
          title: notice.title,
          body: notice.body,
          // Instante absoluto: correcto aunque tz.local quede en UTC.
          scheduledDate: tz.TZDateTime.from(notice.at, tz.local),
          notificationDetails: _details(notice),
          // Un aviso de las 8:00 que llega a las 8:05 no importa, y así no
          // hace falta el permiso de alarmas exactas.
          androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
          payload: notice.payload,
        );
      }
    } catch (e) {
      debugPrint('Error programando notificaciones: $e');
    }
  }

  fln.NotificationDetails _details(PlannedNotice notice) {
    final channel = notice.channel;
    return fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: _importance(channel),
        priority: channel == NoticeChannel.recordatorios
            ? fln.Priority.defaultPriority
            : fln.Priority.high,
        icon: _androidSmallIcon,
        color: _androidAccent,
        styleInformation: notice.lines.isEmpty
            ? fln.BigTextStyleInformation(notice.body)
            : fln.InboxStyleInformation(
                notice.lines,
                contentTitle: notice.title,
                // Si el cuerpo ya es la suma de las líneas, repetirlo sobra.
                summaryText: notice.lines.join(' · ') == notice.body
                    ? null
                    : notice.body,
              ),
      ),
      iOS: fln.DarwinNotificationDetails(threadIdentifier: channel.id),
    );
  }

  static fln.Importance _importance(NoticeChannel channel) =>
      channel == NoticeChannel.recordatorios
          ? fln.Importance.defaultImportance
          : fln.Importance.high;
}
