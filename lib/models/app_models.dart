class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? authToken;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.authToken,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json, {String? token}) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      role: json['role'] ?? 'customer',
      authToken: token,
    );
  }
}

class Address {
  final String street;
  final String city;
  final String state;
  final String postalCode;

  const Address({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  Map<String, String> toMap() => {
        'street': street,
        'city': city,
        'state': state,
        'postalCode': postalCode,
      };
}

class ServiceItem {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final String description;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.description = '',
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final rawDuration =
        json['duration'] ?? json['durationMinutes'] ?? json['duration_minutes'];
    return ServiceItem(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : (json['price'] is String)
              ? double.tryParse(json['price']) ?? 0
              : (json['price'] is num)
                  ? (json['price'] as num).toDouble()
                  : 0,
      durationMinutes: rawDuration is num
          ? rawDuration.toInt()
          : int.tryParse(rawDuration?.toString() ?? '') ?? 0,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'duration': durationMinutes,
        'description': description,
      };
}

class StaffMember {
  final String id;
  final String name;
  final String role;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    String resolveName() {
      if (user != null) {
        final full = (user['fullName'] ?? '').toString().trim();
        if (full.isNotEmpty) return full;
        final first = (user['firstName'] ?? '').toString().trim();
        final last = (user['lastName'] ?? '').toString().trim();
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
      return (json['name'] ?? '').toString();
    }

    return StaffMember(
      id: (json['id'] ?? '').toString(),
      name: resolveName(),
      role: (json['position'] ?? json['role'] ?? '').toString(),
    );
  }
}

class StaffUserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phone;

  const StaffUserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  factory StaffUserProfile.fromJson(Map<String, dynamic> json) {
    final fullName = (json['fullName'] ?? '').toString().trim();
    final firstName = (json['firstName'] ?? '').toString().trim();
    final lastName = (json['lastName'] ?? '').toString().trim();
    final resolvedName = fullName.isNotEmpty
        ? fullName
        : [firstName, lastName].where((value) => value.isNotEmpty).join(' ');
    return StaffUserProfile(
      id: (json['id'] ?? '').toString(),
      firstName: firstName,
      lastName: lastName,
      fullName: resolvedName,
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }
}

class StaffProfile {
  final String id;
  final String userId;
  final String businessId;
  final String position;
  final bool isActive;
  final DateTime? joinedAt;
  final StaffUserProfile? user;

  const StaffProfile({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.position,
    required this.isActive,
    required this.joinedAt,
    required this.user,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    return StaffProfile(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      isActive: json['isActive'] == true,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString())
          : null,
      user: userMap != null ? StaffUserProfile.fromJson(userMap) : null,
    );
  }

  String get displayName {
    final userName = user?.fullName ?? '';
    if (userName.isNotEmpty) return userName;
    final first = user?.firstName ?? '';
    final last = user?.lastName ?? '';
    final combined = '$first $last'.trim();
    return combined.isNotEmpty ? combined : 'Unknown';
  }
}

class Business {
  final String id;
  final String businessId;
  final String businessName;
  final String businessType;
  final String phone;
  final String email;
  final Address address;
  final List<ServiceItem> services;
  final List<StaffMember> staff;
  final String approvalStatus;
  final bool isActive;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Business({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.businessType,
    required this.phone,
    required this.email,
    required this.address,
    required this.services,
    required this.staff,
    this.approvalStatus = 'pending',
    this.isActive = false,
    this.approvedAt,
    this.rejectedAt,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    final serviceList = (json['services'] as List?)
            ?.map((item) => ServiceItem.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList() ??
        [];
    final staffList = (json['staff'] as List?)
            ?.map((item) => StaffMember.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList() ??
        [];
    return Business(
      id: (json['id'] ?? json['businessId'] ?? '').toString(),
      businessId: (json['businessId'] ?? json['business_id'] ?? '').toString(),
      businessName: json['businessName'] ?? json['name'] ?? '',
      businessType: json['businessType'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: Address(
        street: json['address'] ?? json['street'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        postalCode: json['zipCode'] ?? json['postalCode'] ?? '',
      ),
      services: serviceList,
      staff: staffList,
      approvalStatus: (json['approvalStatus'] ?? 'pending').toString(),
      isActive: json['isActive'] == true,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.tryParse(json['rejectedAt'].toString())
          : null,
      reviewNotes: json['reviewNotes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'businessId': businessId,
        'businessName': businessName,
        'businessType': businessType,
        'phone': phone,
        'email': email,
        'address': address.toMap(),
        'services': services.map((s) => s.toMap()).toList(),
        'staff': staff
            .map((member) => {
                  'id': member.id,
                  'name': member.name,
                  'role': member.role,
                })
            .toList(),
        'approvalStatus': approvalStatus,
        'isActive': isActive,
        'approvedAt': approvedAt?.toIso8601String(),
        'rejectedAt': rejectedAt?.toIso8601String(),
        'reviewNotes': reviewNotes,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

class BusinessApplication {
  final String id;
  final String businessName;
  final String businessType;
  final String status;
  final String ownerName;
  final String ownerEmail;
  final String? ownerPhone;
  final String? city;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const BusinessApplication({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.status,
    required this.ownerName,
    required this.ownerEmail,
    this.ownerPhone,
    this.city,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewNotes,
  });

  factory BusinessApplication.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] is Map
        ? Map<String, dynamic>.from(json['owner'] as Map)
        : const <String, dynamic>{};
    final ownerFullName = owner['fullName']?.toString() ?? '';
    final ownerNameParts = [
      owner['firstName']?.toString() ?? '',
      owner['lastName']?.toString() ?? '',
    ].where((value) => value.isNotEmpty).toList();
    final resolvedOwnerName = ownerFullName.isNotEmpty
        ? ownerFullName
        : ownerNameParts.isNotEmpty
            ? ownerNameParts.join(' ')
            : '';

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return BusinessApplication(
      id: (json['id'] ?? json['businessId'] ?? '').toString(),
      businessName: json['businessName'] ?? '',
      businessType: json['businessType']?.toString() ?? '',
      status: json['approvalStatus']?.toString() ?? 'pending',
      ownerName: resolvedOwnerName.isNotEmpty
          ? resolvedOwnerName
          : owner['email']?.toString() ?? 'Unknown owner',
      ownerEmail: owner['email']?.toString() ?? '',
      ownerPhone: owner['phone']?.toString(),
      city: json['city']?.toString(),
      submittedAt: parseDate(json['createdAt']) ?? DateTime.now(),
      reviewedAt: parseDate(json['approvedAt']) ?? parseDate(json['rejectedAt']),
      reviewNotes: json['reviewNotes']?.toString(),
    );
  }
}

class Appointment {
  final String id;
  final String businessId;
  final String businessName;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final List<ServiceItem> services;
  final double totalPrice;
  final int totalDurationMinutes;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String? staffId;
  final String? staffName;
  final String notes;

  const Appointment({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.services,
    required this.totalPrice,
    required this.totalDurationMinutes,
    required this.status,
    required this.startAt,
    required this.endAt,
    this.staffId,
    this.staffName,
    this.notes = '',
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final servicesJson = (json['services'] as List?)
            ?.where((item) => item != null)
            .map(
              (item) => ServiceItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList() ??
        [];

    final business = json['business'] is Map
        ? Map<String, dynamic>.from(json['business'] as Map)
        : null;
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : null;
    final staff = json['staff'] is Map
        ? Map<String, dynamic>.from(json['staff'] as Map)
        : null;
    final staffUser = staff?['user'] is Map
        ? Map<String, dynamic>.from(staff?['user'] as Map)
        : null;

    final appointmentDate = json['appointmentDate'] ?? json['date'];
    final startTime = json['startTime'] ?? json['start_at'];
    final endTime = json['endTime'] ?? json['end_at'];

    DateTime parseDateTime(dynamic date, dynamic time) {
      if (date == null || time == null) return DateTime.now();
      final combined = '${date}T$time';
      final alt = '$date $time';
      return DateTime.tryParse(combined) ??
          DateTime.tryParse(alt) ??
          DateTime.now();
    }

    final durationRaw = json['totalDuration'] ??
        json['totalDurationMinutes'] ??
        json['total_duration'];

    String resolveCustomerName() {
      if (customer != null) {
        final full = (customer['fullName'] ?? '').toString().trim();
        if (full.isNotEmpty) return full;
        final first = (customer['firstName'] ?? '').toString().trim();
        final last = (customer['lastName'] ?? '').toString().trim();
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
      return (json['customerName'] ?? '').toString();
    }

    String resolveStaffName() {
      if (staffUser != null) {
        final full = (staffUser['fullName'] ?? '').toString().trim();
        if (full.isNotEmpty) return full;
        final first = (staffUser['firstName'] ?? '').toString().trim();
        final last = (staffUser['lastName'] ?? '').toString().trim();
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
      return (json['staffName'] ?? json['staffPosition'] ?? '').toString();
    }

    return Appointment(
      id: (json['id'] ?? '').toString(),
      businessId:
          (json['businessId'] ?? business?['id'] ?? '').toString(),
      businessName: json['businessName'] ??
          (business?['businessName'] ?? '').toString(),
      customerId:
          (json['customerId'] ?? customer?['id'] ?? '').toString(),
      customerName: resolveCustomerName(),
      customerEmail:
          (json['customerEmail'] ?? customer?['email'] ?? '').toString(),
      services: servicesJson,
      totalPrice: (json['totalPrice'] is int)
          ? (json['totalPrice'] as int).toDouble()
          : (json['totalPrice'] is String)
              ? double.tryParse(json['totalPrice']) ?? 0
              : (json['totalPrice'] is num)
                  ? (json['totalPrice'] as num).toDouble()
                  : 0,
      totalDurationMinutes: durationRaw is num
          ? durationRaw.toInt()
          : int.tryParse(durationRaw?.toString() ?? '') ?? 0,
      status: json['status'] ?? 'confirmed',
      startAt: parseDateTime(appointmentDate, startTime),
      endAt: parseDateTime(appointmentDate, endTime),
      staffId: (json['staffId'] ?? staff?['id'])?.toString(),
      staffName: resolveStaffName(),
      notes: json['notes'] ?? '',
    );
  }

  Appointment copyWith({
    String? status,
    DateTime? startAt,
    DateTime? endAt,
    String? notes,
  }) {
    return Appointment(
      id: id,
      businessId: businessId,
      businessName: businessName,
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      services: services,
      totalPrice: totalPrice,
      totalDurationMinutes: totalDurationMinutes,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      staffId: staffId,
      staffName: staffName,
      notes: notes ?? this.notes,
    );
  }
}

class ShiftItem {
  final String id;
  final String staffId;
  final String shiftDate;
  final String startTime;
  final String endTime;
  final String staffName;

  const ShiftItem({
    required this.id,
    required this.staffId,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.staffName,
  });

  factory ShiftItem.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] is Map
        ? Map<String, dynamic>.from(json['staff'] as Map)
        : null;
    final staffUser = staff?['user'] is Map
        ? Map<String, dynamic>.from(staff?['user'] as Map)
        : null;

    String resolveStaffName() {
      if (staffUser != null) {
        final full = (staffUser['fullName'] ?? '').toString().trim();
        if (full.isNotEmpty) return full;
        final first = (staffUser['firstName'] ?? '').toString().trim();
        final last = (staffUser['lastName'] ?? '').toString().trim();
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
      return (json['staffName'] ?? 'Staff').toString();
    }

    return ShiftItem(
      id: (json['id'] ?? '').toString(),
      staffId: (json['staffId'] ?? staff?['id'] ?? '').toString(),
      shiftDate: (json['shiftDate'] ?? '').toString(),
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
      staffName: resolveStaffName(),
    );
  }
}

class AvailabilitySlot {
  final DateTime startAt;
  final DateTime endAt;

  const AvailabilitySlot({
    required this.startAt,
    required this.endAt,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final startStr = json['startAt']?.toString() ?? json['start']?.toString();
    final endStr = json['endAt']?.toString() ?? json['end']?.toString();
    final fallback = DateTime.now();
    return AvailabilitySlot(
      startAt: startStr != null ? DateTime.parse(startStr) : fallback,
      endAt: endStr != null ? DateTime.parse(endStr) : fallback,
    );
  }

  String label() {
    String format(DateTime time) {
      final local = time.toLocal();
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final suffix = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }

    return '${format(startAt)} - ${format(endAt)}';
  }
}

class BusinessAvailability {
  final String businessId;
  final String startDate;
  final String endDate;
  final List<String> bookedDays;
  final List<AvailabilitySlot> bookedSlots;
  final List<AvailabilitySlot> shiftSlots;

  const BusinessAvailability({
    required this.businessId,
    required this.startDate,
    required this.endDate,
    required this.bookedDays,
    required this.bookedSlots,
    required this.shiftSlots,
  });

  factory BusinessAvailability.fromJson(Map<String, dynamic> json) {
    final slots = (json['bookedSlots'] as List?)
            ?.map((item) => AvailabilitySlot.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList() ??
        <AvailabilitySlot>[];
    final shifts = (json['shiftSlots'] as List?)
            ?.map((item) => AvailabilitySlot.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList() ??
        <AvailabilitySlot>[];
    final days =
        (json['bookedDays'] as List?)?.map((d) => d.toString()).toList() ??
            <String>[];
    return BusinessAvailability(
      businessId: (json['businessId'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      bookedDays: days,
      bookedSlots: slots,
      shiftSlots: shifts,
    );
  }
}

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const AppException(
    this.message, {
    this.statusCode,
    this.details,
  });

  @override
  String toString() => message;
}
