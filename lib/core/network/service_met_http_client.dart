import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ServiceMetNetworkException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ServiceMetNetworkException(
    this.message, {
    this.code,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class ServiceMetHttpClient {
  ServiceMetHttpClient._();

  static const certificateSha256 =
      '9B77AAF79EC28476AEA6C18B16F8F98A07D4F264E3B92F22224BCB7AAAF85678';
  static const allowedHosts = {'192.168.1.5', '10.50.8.1'};

  static String normalizeBaseUrl(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');

  static http.Client create(String rawBaseUrl) {
    final baseUrl = normalizeBaseUrl(rawBaseUrl);
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host) ||
        uri.port != 3100) {
      throw const ServiceMetNetworkException(
        'La API debe usar HTTPS en una dirección interna autorizada.',
        code: 'INSECURE_API_URL',
      );
    }

    final context = SecurityContext(withTrustedRoots: false);
    final ioClient = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 20)
      ..badCertificateCallback = (certificate, host, port) {
        if (!allowedHosts.contains(host) || port != 3100) return false;
        final now = DateTime.now();
        if (now.isBefore(certificate.startValidity) ||
            now.isAfter(certificate.endValidity)) {
          return false;
        }
        final fingerprint = sha256
            .convert(certificate.der)
            .toString()
            .replaceAll(':', '')
            .toUpperCase();
        return fingerprint == certificateSha256;
      };
    return IOClient(ioClient);
  }
}
