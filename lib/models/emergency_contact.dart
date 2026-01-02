class EmergencyContact {
  final String id;
  String name;
  String? phone;
  String? email;

  bool canCall;
  bool canSms;
  bool canEmail;

  EmergencyContact({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.canCall = true,
    this.canSms = true,
    this.canEmail = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'canCall': canCall,
    'canSms': canSms,
    'canEmail': canEmail,
  };

  static EmergencyContact fromJson(Map<String, dynamic> j) => EmergencyContact(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    canCall: (j['canCall'] as bool?) ?? true,
    canSms: (j['canSms'] as bool?) ?? true,
    canEmail: (j['canEmail'] as bool?) ?? false,
  );
}
