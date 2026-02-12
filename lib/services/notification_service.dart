import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../login/services/database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

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
      initializationSettings,
      onDidReceiveNotificationResponse:
          (fln.NotificationResponse notificationResponse) async {
        // Manejar toque en notificación si es necesario
      },
    );

    // Solicitar permisos en Android 13+ (Notificaciones)
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // Solicitar permiso para alarmas exactas (Android 12+)
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  // 1. Recordatorio diario de actualización (Ej: 8:00 AM)
  Future<void> scheduleDailyUpdateReminder() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // ID único
      'Actualización de Datos',
      'Recuerda actualizar la precarga de datos para trabajar con información al día.',
      _nextInstanceOfTime(8, 0), // 8:00 AM
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'daily_reminders',
          'Recordatorios Diarios',
          channelDescription: 'Recordatorios diarios de actualización de datos',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
        ),
        iOS: fln.DarwinNotificationDetails(),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // 2. Alerta de vencimiento de calibración
  Future<void> checkAndScheduleCalibrationAlerts() async {
    try {
      final dbService = DatabaseService();
      // Nota: Necesitamos implementar getPrecargaDatabase en DatabaseService primero
      final db = await dbService.getPrecargaDatabase();

      // Corregir tipo de retorno de query para evitar error de casting
      final List<Map<String, Object?>> resultados = await db.query(
        'equipamientos',
        where: "estado != 'DESACTIVADO'",
      );

      // Convertir a List<Map<String, dynamic>>
      final List<Map<String, dynamic>> equipos =
          resultados.map((e) => Map<String, dynamic>.from(e)).toList();

      int expiredCount = 0;
      int warningCount = 0;

      for (var equipo in equipos) {
        final certFechaStr = equipo['cert_fecha'] as String?;
        if (certFechaStr != null) {
          try {
            final certFecha = DateTime.parse(certFechaStr);
            final now = DateTime.now();
            final difference = now.difference(certFecha).inDays;

            if (difference > 365) {
              expiredCount++;
            } else if (difference > 335) {
              // Aviso 30 días antes (aprox 11 meses)
              warningCount++;
            }
          } catch (e) {
            debugPrint('Error parseando fecha cert: $certFechaStr');
          }
        }
      }

      await db.close();

      if (expiredCount > 0 || warningCount > 0) {
        String bodyText = '';
        if (expiredCount > 0) {
          bodyText += 'Tienes $expiredCount equipos con calibración VENCIDA. ';
        }
        if (warningCount > 0) {
          bodyText +=
              'Tienes $warningCount equipos próximos a vencer su calibración.';
        }

        await flutterLocalNotificationsPlugin.show(
          1, // ID único
          'Alerta de Equipos',
          bodyText,
          fln.NotificationDetails(
            android: fln.AndroidNotificationDetails(
              'calibration_alerts',
              'Alertas de Calibración',
              channelDescription:
                  'Notificaciones sobre vencimiento de calibraciones',
              importance: fln.Importance.high,
              priority: fln.Priority.high,
              styleInformation: fln.BigTextStyleInformation(bodyText),
            ),
            iOS: const fln.DarwinNotificationDetails(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error verificando alertas de calibración: $e');
    }
  }
}
