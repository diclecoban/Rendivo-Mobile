import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import '../models/owner_signup.dart';
import 'session_service.dart';

class BackendService {
  BackendService._({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client() {
    final envBase =
        const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final effectiveBase = baseUrl ??
        (envBase.isNotEmpty
            ? envBase
            : Platform.isAndroid
                ? 'http://10.0.2.2:5000/api'
                : 'http://localhost:5000/api');
    _baseUrl = _normalizeBase(effectiveBase);
  }

  factory BackendService.test({http.Client? client, String? baseUrl}) {
    return BackendService._(client: client, baseUrl: baseUrl);
  }

  static BackendService? _singleton;
  static BackendService? _testOverride;

  static BackendService get instance {
    _singleton ??= BackendService._();
    return _testOverride ?? _singleton!;
  }

  @visibleForTesting
  static void overrideForTesting(BackendService? service) {
    _testOverride = service;
  }

  final http.Client _client;
  final SessionService _session = SessionService.instance;
  late String _baseUrl;

  static String _normalizeBase(String value) {
    var base = value.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    // Ensure we hit the API prefix; if none provided, append /api.
    try {
      final uri = Uri.parse(base);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      // If path already includes "api" anywhere (e.g., /api or /api/auth), keep as-is.
      final hasApi = segments.any((s) => s.toLowerCase() == 'api');
      if (!hasApi) {
        final updated = uri.replace(
          pathSegments: [...segments, 'api'],
        );
        return updated.toString();
      }
    } catch (_) {
      // Fall back to the raw string if parsing fails.
      return base;
    }

    return base;
  }

  /// Allow runtime override (e.g., when running on device, set to LAN IP).
  void setBaseUrl(String baseUrl) {
    _baseUrl = _normalizeBase(baseUrl);
  }

  Map<String, String> _headers({bool withAuth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _session.authToken;
    if (withAuth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return json.decode(response.body);
    } catch (_) {
      // Return plain text/HTML so the caller can surface a meaningful error.
      return response.body;
    }
  }

  T _handleResponse<T>(
    http.Response response,
    T Function(dynamic json) mapper,
  ) {
    final decoded = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return mapper(decoded);
      } catch (e) {
        throw AppException('Unexpected response from server.');
      }
    }

    final message = decoded is Map && decoded['message'] is String
        ? decoded['message'] as String
        : decoded is String && decoded.isNotEmpty
            ? decoded
            : 'Request failed with status ${response.statusCode}';
    throw AppException(message);
  }

  Future<AuthUser> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    return _handleResponse(response, (jsonBody) {
      final token = jsonBody['token'] as String?;
      final user = AuthUser.fromJson(
        Map<String, dynamic>.from(jsonBody['user'] as Map),
        token: token,
      );
      _session
        ..setUser(user)
        ..setToken(token);
      return user;
    });
  }

  Future<AuthUser> registerCustomer({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName ?? '',
        'email': email,
        'password': password,
        'phone': phone ?? '',
      }),
    );

    return _handleResponse(response, (jsonBody) {
      final token = jsonBody['token'] as String?;
      final user = AuthUser.fromJson(
        Map<String, dynamic>.from(jsonBody['user'] as Map),
        token: token,
      );
      _session
        ..setUser(user)
        ..setToken(token);
      return user;
    });
  }

  Future<AuthUser> registerBusinessOwner(OwnerSignupModel model) async {
    final uri = Uri.parse('$_baseUrl/auth/register-business');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'fullName': model.fullName,
        'email': model.email,
        'password': model.password,
        'businessName': model.businessName,
        'businessType': model.businessType,
        'phone': model.phone,
        'publicEmail': model.publicEmail,
        'street': model.street,
        'city': model.city,
        'state': model.state,
        'postalCode': model.postalCode,
      }),
    );

    return _handleResponse(response, (jsonBody) {
      final token = jsonBody['token'] as String?;
      final user = AuthUser.fromJson(
        Map<String, dynamic>.from(jsonBody['user'] as Map),
        token: token,
      );
      _session
        ..setUser(user)
        ..setToken(token);
      return user;
    });
  }

  Future<List<Business>> fetchBusinesses() async {
    final uri = Uri.parse('$_baseUrl/businesses');
    final response = await _client.get(uri, headers: _headers());

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <Business>[];
      return jsonBody
          .map((item) => Business.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  Future<List<ServiceItem>> fetchBusinessServices(String businessId) async {
    final uri = Uri.parse('$_baseUrl/businesses/$businessId/services');
    final response = await _client.get(uri, headers: _headers());

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <ServiceItem>[];
      return jsonBody
          .map((item) => ServiceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  Future<Business?> findBusinessById(String businessId) async {
    final businesses = await fetchBusinesses();
    try {
      return businesses.firstWhere((b) => b.id == businessId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Appointment>> fetchCustomerAppointments() async {
    final uri = Uri.parse('$_baseUrl/appointments/me');
    final response = await _client.get(uri, headers: _headers(withAuth: true));

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <Appointment>[];
      return jsonBody
          .map(
            (item) => Appointment.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    });
  }

  Future<List<Business>> fetchMyBusinesses() async {
    final uri = Uri.parse('$_baseUrl/businesses/me');
    final response = await _client.get(uri, headers: _headers(withAuth: true));

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <Business>[];
      return jsonBody
          .map((item) => Business.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    });
  }

  Future<List<Appointment>> fetchStaffAppointments({String? staffId}) async {
    var uri = Uri.parse('$_baseUrl/staff/appointments');
    if (staffId != null && staffId.isNotEmpty) {
      uri = uri.replace(queryParameters: {'staffId': staffId});
    }
    final response = await _client.get(uri, headers: _headers(withAuth: true));

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <Appointment>[];
      return jsonBody
          .map(
            (item) => Appointment.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    });
  }

  Future<Map<String, dynamic>> fetchCustomerDashboard() async {
    final uri = Uri.parse('$_baseUrl/customer/dashboard');
    final response = await _client.get(uri, headers: _headers(withAuth: true));
    return _handleResponse<Map<String, dynamic>>(response, (jsonBody) {
      if (jsonBody is Map<String, dynamic>) {
        return jsonBody;
      }
      throw AppException('Unexpected response from dashboard endpoint.');
    });
  }

  Future<List<AvailabilitySlot>> fetchBusinessAvailability({
    required String businessId,
    required DateTime date,
    int? durationMinutes,
  }) async {
    final params = <String, String>{
      'date': _formatDate(date),
    };
    if (durationMinutes != null && durationMinutes > 0) {
      params['durationMinutes'] = '$durationMinutes';
    }

    final uri = Uri.parse('$_baseUrl/businesses/$businessId/availability')
        .replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers());

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! Map) return <AvailabilitySlot>[];
      final slots = jsonBody['slots'];
      if (slots is! List) return <AvailabilitySlot>[];
      return slots
          .whereType<Map>()
          .map(
            (item) => AvailabilitySlot.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    });
  }

  Future<String> createAppointment({
    required String businessId,
    required List<String> serviceIds,
    required DateTime startAt,
    required DateTime endAt,
    String? staffId,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/appointments');
    final response = await _client.post(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'businessId': int.tryParse(businessId) ?? businessId,
        'serviceIds': serviceIds.map((id) => int.tryParse(id) ?? id).toList(),
        'staffId': staffId != null ? int.tryParse(staffId) ?? staffId : null,
        'appointmentDate': startAt.toIso8601String().split('T').first,
        'startTime': startAt.toIso8601String().split('T').last.substring(0, 8),
        'endTime': endAt.toIso8601String().split('T').last.substring(0, 8),
        'notes': notes ?? '',
      }),
    );

    return _handleResponse(response, (jsonBody) {
      return (jsonBody['appointmentId'] ?? '').toString();
    });
  }

  Future<void> cancelAppointment(String appointmentId) async {
    final uri = Uri.parse('$_baseUrl/appointments/$appointmentId/cancel');
    final response = await _client.patch(
      uri,
      headers: _headers(withAuth: true),
    );

    _handleResponse(response, (_) => null);
  }

  Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final uri = Uri.parse('$_baseUrl/appointments/$appointmentId/reschedule');
    final response = await _client.patch(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
      }),
    );

    _handleResponse(response, (_) => null);
  }

  Future<void> updateAppointmentNotes({
    required String appointmentId,
    required String notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/appointments/$appointmentId/notes');
    final response = await _client.patch(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({'notes': notes}),
    );
    _handleResponse(response, (_) => null);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
