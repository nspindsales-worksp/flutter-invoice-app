class UserModel {
  final String id;
  final String userId;
  final String password;
  final String name;
  final String role;
  final String mobile;
  final bool isSystem;
  final bool isLocal;
  final DateTime? expiresAt;
  final Map<String, bool> featurePermissions;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.userId,
    required this.password,
    this.name = '',
    this.role = 'User',
    this.mobile = '',
    this.isSystem = false,
    this.isLocal = false,
    this.expiresAt,
    this.featurePermissions = const {'createInvoice': true, 'invoiceHistory': true},
    this.createdAt,
  });

  bool get isSuperAdmin => role == 'Super Admin';
  bool get isAdmin => role == 'Admin' || role == 'Super Admin';

  bool hasPermission(String featureKey) {
    if (isAdmin) return true;
    return featurePermissions[featureKey] ?? true;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? exp;
    if (map['expires_at'] != null) {
      exp = DateTime.tryParse(map['expires_at'].toString());
    } else if (map['expiresAt'] != null) {
      exp = DateTime.tryParse(map['expiresAt'].toString());
    }

    DateTime? created;
    if (map['created_at'] != null) {
      created = DateTime.tryParse(map['created_at'].toString());
    }

    Map<String, bool> permissions = {'createInvoice': true, 'invoiceHistory': true};
    if (map['featurePermissions'] is Map) {
      final rawMap = map['featurePermissions'] as Map;
      permissions = rawMap.map((k, v) => MapEntry(k.toString(), v == true));
    }

    return UserModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? map['userId']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      role: map['role']?.toString() ?? 'User',
      mobile: map['mobile']?.toString() ?? '',
      isSystem: map['is_system'] == true || map['isSystem'] == true,
      isLocal: map['is_local'] == true || map['isLocal'] == true,
      expiresAt: exp,
      featurePermissions: permissions,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'password': password,
      'name': name,
      'role': role,
      'mobile': mobile,
      'is_system': isSystem,
      'is_local': isLocal,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? userId,
    String? password,
    String? name,
    String? role,
    String? mobile,
    bool? isSystem,
    bool? isLocal,
    DateTime? expiresAt,
    Map<String, bool>? featurePermissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      password: password ?? this.password,
      name: name ?? this.name,
      role: role ?? this.role,
      mobile: mobile ?? this.mobile,
      isSystem: isSystem ?? this.isSystem,
      isLocal: isLocal ?? this.isLocal,
      expiresAt: expiresAt ?? this.expiresAt,
      featurePermissions: featurePermissions ?? this.featurePermissions,
      createdAt: createdAt,
    );
  }
}
