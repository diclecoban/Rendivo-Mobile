import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import '../models/owner_signup.dart';
import 'session_service.dart';

class BackendService {
  BackendService._({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client() {
    const envBase =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final effectiveBase = baseUrl ??
        (envBase.isNotEmpty
            ? envBase
            : Platform.isAndroid
                ? 'http://10.0.2.2:5001/api'
                : 'http://localhost:5001/api');
    _baseUrl = _normalizeBase(effectiveBase);
  }

  static final BackendService instance = BackendService._();

  final http.Client _client;
  final SessionService _session = SessionService.instance;
  late String _baseUrl;
  String get baseUrl => _baseUrl;

  static String _normalizeBase(String value) {
    var base = value.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    try {
      final uri = Uri.parse(base);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final hasApi = segments.any((s) => s.toLowerCase() == 'api');
      if (!hasApi) {
        final updated = uri.replace(pathSegments: [...segments, 'api']);
        return updated.toString();
      }
    } catch (_) {
      return base;
    }

    return base;
  }

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
      } catch (_) {
        throw const AppException('Unexpected response from server.');
      }
    }

    final message = decoded is Map && decoded['message'] is String
        ? decoded['message'] as String
        : decoded is String && decoded.isNotEmpty
            ? decoded
            : 'Request failed with status ${response.statusCode}';
    final details = decoded is Map
        ? Map<String, dynamic>.from(decoded as Map)
        : null;
    throw AppException(
      message,
      statusCode: response.statusCode,
      details: details,
    );
  }

  // Auth
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
    final uri = Uri.parse('$_baseUrl/auth/register/customer');
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
    final uri = Uri.parse('$_baseUrl/auth/register/business');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'fullName': model.fullName,
        'email': model.email,
        'password': model.password,
        'businessName': model.businessName,
        'businessType': model.businessType,
        'address': model.street,
        'city': model.city,
        'state': model.state,
        'zipCode': model.postalCode,
        'phone': model.phone,
        'website': '',
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

  Future<AuthUser> registerStaff({
    required String fullName,
    required String email,
    required String password,
    required String businessId,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register/staff');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
        'businessId': businessId,
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

  Future<void> requestPasswordReset(String email) async {
    final uri = Uri.parse('$_baseUrl/auth/password/reset/request');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'email': email}),
    );

    _handleResponse(response, (_) => null);
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/password/reset/confirm');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'email': email,
        'code': code,
        'password': password,
      }),
    );

    _handleResponse(response, (_) => null);
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/verify-email')
        .replace(queryParameters: {'email': email, 'code': code});
    final response = await _client.get(uri, headers: _headers());
    _handleResponse(response, (_) => null);
  }

  // Businesses & services
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

  Future<Business> fetchBusinessById(String businessId) async {
    final uri = Uri.parse('$_baseUrl/businesses/$businessId');
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(
      response,
      (jsonBody) => Business.fromJson(
        Map<String, dynamic>.from(jsonBody as Map),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchBusinessDashboard() async {
    final uri = Uri.parse('$_baseUrl/business/dashboard');
    final response = await _client.get(uri, headers: _headers(withAuth: true));
    return _handleResponse(
      response,
      (jsonBody) => Map<String, dynamic>.from(jsonBody as Map),
    );
  }

  Future<List<BusinessApplication>> fetchPendingBusinessApplications() async {
    final uri = Uri.parse('$_baseUrl/admin/businesses/pending');
    final response = await _client.get(uri, headers: _headers(withAuth: true));
    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <BusinessApplication>[];
      return jsonBody
          .map(
            (item) => BusinessApplication.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    });
  }

  Future<BusinessApplication> reviewBusinessApplication({
    required String businessId,
    required bool approve,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/admin/businesses/$businessId/review');
    final response = await _client.post(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'decision': approve ? 'approve' : 'reject',
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      }),
    );

    return _handleResponse(
      response,
      (jsonBody) => BusinessApplication.fromJson(
        Map<String, dynamic>.from(
          (jsonBody['business'] ?? jsonBody) as Map,
        ),
      ),
    );
  }

  // Owner service management
  Future<List<ServiceItem>> fetchOwnerServices() async {
    final uri = Uri.parse('$_baseUrl/services');
    final response = await _client.get(uri, headers: _headers(withAuth: true));

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <ServiceItem>[];
      return jsonBody
          .map((item) => ServiceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  Future<ServiceItem> createService({
    required String name,
    String description = '',
    required double price,
    required int durationMinutes,
  }) async {
    final uri = Uri.parse('$_baseUrl/services');
    final response = await _client.post(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'name': name,
        'description': description,
        'price': price,
        'duration': durationMinutes,
      }),
    );

    return _handleResponse(
      response,
      (jsonBody) => ServiceItem.fromJson(
        Map<String, dynamic>.from(jsonBody['service'] ?? jsonBody),
      ),
    );
  }

  Future<ServiceItem> updateService({
    required String id,
    required String name,
    String description = '',
    required double price,
    required int durationMinutes,
    bool? isActive,
  }) async {
    final uri = Uri.parse('$_baseUrl/services/$id');
    final response = await _client.put(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'name': name,
        'description': description,
        'price': price,
        'duration': durationMinutes,
        if (isActive != null) 'isActive': isActive,
      }),
    );

    return _handleResponse(
      response,
      (jsonBody) => ServiceItem.fromJson(
        Map<String, dynamic>.from(jsonBody['service'] ?? jsonBody),
      ),
    );
  }

  Future<void> deleteService(String id) async {
    final uri = Uri.parse('$_baseUrl/services/$id');
    final response =
        await _client.delete(uri, headers: _headers(withAuth: true));
    _handleResponse(response, (_) => null);
  }

  // Staff
  Future<List<StaffMember>> fetchBusinessStaff(String businessId) async {
    final uri = Uri.parse('$_baseUrl/businesses/$businessId/staff');
    final response = await _client.get(uri, headers: _headers());
    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <StaffMember>[];
      return jsonBody
          .map((item) => StaffMember.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  // Shifts
  Future<List<ShiftItem>> fetchBusinessShifts({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final uri = Uri.parse('$_baseUrl/shifts').replace(queryParameters: {
      'startDate': _formatDate(startDate),
      'endDate': _formatDate(endDate),
    });
    final response = await _client.get(uri, headers: _headers(withAuth: true));
    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <ShiftItem>[];
      return jsonBody
          .map((item) => ShiftItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  Future<List<StaffMember>> fetchShiftStaffMembers() async {
    final uri = Uri.parse('$_baseUrl/shifts/staff-members');
    final response = await _client.get(uri, headers: _headers(withAuth: true));
    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <StaffMember>[];
      return jsonBody
          .map((item) => StaffMember.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    });
  }

  Future<ShiftItem> createShift({
    required String staffId,
    required DateTime shiftDate,
    required String startTime,
    required String endTime,
  }) async {
    final uri = Uri.parse('$_baseUrl/shifts');
    final response = await _client.post(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'staffId': int.tryParse(staffId) ?? staffId,
        'shiftDate': _formatDate(shiftDate),
        'startTime': startTime,
        'endTime': endTime,
      }),
    );
    return _handleResponse(
      response,
      (jsonBody) =>
          ShiftItem.fromJson(Map<String, dynamic>.from(jsonBody as Map)),
    );
  }

  Future<ShiftItem> updateShift({
    required String shiftId,
    required String staffId,
    required DateTime shiftDate,
    required String startTime,
    required String endTime,
  }) async {
    final uri = Uri.parse('$_baseUrl/shifts/$shiftId');
    final response = await _client.put(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'staffId': int.tryParse(staffId) ?? staffId,
        'shiftDate': _formatDate(shiftDate),
        'startTime': startTime,
        'endTime': endTime,
      }),
    );
    return _handleResponse(
      response,
      (jsonBody) =>
          ShiftItem.fromJson(Map<String, dynamic>.from(jsonBody as Map)),
    );
  }

  Future<void> deleteShift(String shiftId) async {
    final uri = Uri.parse('$_baseUrl/shifts/$shiftId');
    final response = await _client.delete(
      uri,
      headers: _headers(withAuth: true),
    );
    _handleResponse(response, (_) => null);
  }

  // Appointments
  Future<List<Appointment>> fetchCustomerAppointments() {
    return fetchAppointments();
  }

  Future<List<Appointment>> fetchAppointments() async {
    String path = '/appointments';
    final role = _session.currentRole?.toLowerCase();
    if (role == 'business_owner') {
      path = '/business/appointments';
    } else if (role == 'staff') {
      path = '/staff/appointments';
    }

    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(uri, headers: _headers(withAuth: true));

    return _handleResponse(response, (jsonBody) {
      if (jsonBody is! List) return <Appointment>[];
      return jsonBody
          .map((item) => Appointment.fromJson(Map<String, dynamic>.from(item)))
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
    var resolvedStaffId = staffId ?? '';
    if (resolvedStaffId.isEmpty) {
      final staff = await fetchBusinessStaff(businessId);
      if (staff.isEmpty) {
        throw const AppException(
          'No staff available for this business. Please contact the business.',
        );
      }
      resolvedStaffId = staff.first.id;
    }

    final uri = Uri.parse('$_baseUrl/appointments');
    final response = await _client.post(
      uri,
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'businessId': int.tryParse(businessId) ?? businessId,
        'serviceIds': serviceIds.map((id) => int.tryParse(id) ?? id).toList(),
        'staffId': int.tryParse(resolvedStaffId) ?? resolvedStaffId,
        'appointmentDate': _formatDate(startAt),
        'startTime': _formatTime(startAt),
        'endTime': _formatTime(endAt),
        'notes': notes ?? '',
      }),
    );

    return _handleResponse(response, (jsonBody) {
      return (jsonBody['appointmentId'] ?? '').toString();
    });
  }

  Future<void> cancelAppointment(String appointmentId) async {
    final uri = Uri.parse('$_baseUrl/appointments/$appointmentId');
    final response = await _client.delete(
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
        'appointmentDate': _formatDate(startAt),
        'startTime': _formatTime(startAt),
        'endTime': _formatTime(endAt),
        'totalDuration': endAt.difference(startAt).inMinutes,
      }),
    );

    _handleResponse(response, (_) => null);
  }

  Future<void> updateAppointmentNotes({
    required String appointmentId,
    required String notes,
  }) async {
    // Backend does not support notes update; surface as unsupported.
    throw const AppException('Updating notes is not supported.');
  }

  Future<BusinessAvailability> fetchBusinessAvailability({
    required String businessId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = _formatDate(startDate);
    if (endDate != null) params['endDate'] = _formatDate(endDate);

    final uri = Uri.parse('$_baseUrl/businesses/$businessId/availability')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _client.get(uri, headers: _headers());

    return _handleResponse(
      response,
      (jsonBody) => BusinessAvailability.fromJson(
        Map<String, dynamic>.from(jsonBody as Map),
      ),
    );
  }

  String _formatDate(DateTime date) => date.toIso8601String().split('T').first;

  String _formatTime(DateTime date) =>
      date.toIso8601String().split('T').last.substring(0, 8);
}
