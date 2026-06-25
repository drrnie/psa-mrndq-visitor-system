// lib/models/visitor_model.dart

class VisitorRecord {
  final int? id;
  final String visitorId;
  final String visitorName;
  final String purpose;
  final String agency;
  final String visitorType;   // 'individual' or 'group'
  final int? groupCount;
  final String guardOnDuty;
  final String unitId;        // which unit this record belongs to
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool isActive;

  const VisitorRecord({
    this.id,
    required this.visitorId,
    required this.visitorName,
    required this.purpose,
    required this.agency,
    required this.visitorType,
    this.groupCount,
    required this.guardOnDuty,
    required this.unitId,
    required this.checkInTime,
    this.checkOutTime,
    this.isActive = true,
  });

  bool get isGroup => visitorType == 'group';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'visitor_id':     visitorId,
      'visitor_name':   visitorName,
      'purpose':        purpose,
      'agency':         agency,
      'visitor_type':   visitorType,
      'group_count':    groupCount,
      'guard_on_duty':  guardOnDuty,
      'unit_id':        unitId,
      'check_in_time':  checkInTime.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'is_active':      isActive ? 1 : 0,
    };
  }

  factory VisitorRecord.fromMap(Map<String, dynamic> map) {
    return VisitorRecord(
      id:           map['id'] as int?,
      visitorId:    map['visitor_id'] as String,
      visitorName:  map['visitor_name'] as String,
      purpose:      map['purpose'] as String,
      agency:       map['agency'] as String,
      visitorType:  map['visitor_type'] as String,
      groupCount:   map['group_count'] as int?,
      guardOnDuty:  map['guard_on_duty'] as String,
      unitId:       (map['unit_id'] as String?) ?? 'unknown',
      checkInTime:  DateTime.parse(map['check_in_time'] as String),
      checkOutTime: map['check_out_time'] != null
          ? DateTime.parse(map['check_out_time'] as String)
          : null,
      isActive:     (map['is_active'] as int) == 1,
    );
  }

  VisitorRecord copyWith({
    int? id,
    String? visitorId,
    String? visitorName,
    String? purpose,
    String? agency,
    String? visitorType,
    int? groupCount,
    String? guardOnDuty,
    String? unitId,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    bool? isActive,
  }) {
    return VisitorRecord(
      id:           id ?? this.id,
      visitorId:    visitorId ?? this.visitorId,
      visitorName:  visitorName ?? this.visitorName,
      purpose:      purpose ?? this.purpose,
      agency:       agency ?? this.agency,
      visitorType:  visitorType ?? this.visitorType,
      groupCount:   groupCount ?? this.groupCount,
      guardOnDuty:  guardOnDuty ?? this.guardOnDuty,
      unitId:       unitId ?? this.unitId,
      checkInTime:  checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      isActive:     isActive ?? this.isActive,
    );
  }
}
