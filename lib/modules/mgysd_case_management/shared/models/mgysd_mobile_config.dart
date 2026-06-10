class MgysdMobileConfig {
  final bool enabled;
  final MgysdAccessControl accessControl;
  final Map<String, String> programs;
  final Map<String, String> programStages;
  final Map<String, String> dataElements;

  const MgysdMobileConfig({
    required this.enabled,
    required this.accessControl,
    this.programs = const {},
    this.programStages = const {},
    this.dataElements = const {},
  });

  factory MgysdMobileConfig.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return MgysdMobileConfig.disabled();
    }

    return MgysdMobileConfig(
      enabled: json['enabled'] == true,
      accessControl: MgysdAccessControl.fromJson(json['accessControl']),
      programs: _stringMap(json['programs']),
      programStages: _stringMap(json['programStages']),
      dataElements: _stringMap(json['dataElements']),
    );
  }

  factory MgysdMobileConfig.disabled() {
    return const MgysdMobileConfig(
      enabled: false,
      accessControl: MgysdAccessControl(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'accessControl': accessControl.toJson(),
      'programs': programs,
      'programStages': programStages,
      'dataElements': dataElements,
    };
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value == null || value is! Map) return <String, String>{};

    final map = <String, String>{};
    value.forEach((key, val) {
      final k = (key ?? '').toString().trim();
      final v = (val ?? '').toString().trim();
      if (k.isNotEmpty) map[k] = v;
    });
    return map;
  }
}

class MgysdAccessControl {
  final List<String> requiredUserGroups;
  final List<String> requiredRoles;

  /// ANY means user can access if they match at least one configured group OR role.
  /// ALL means user must match at least one configured group AND at least one configured role,
  /// but only when both lists are configured.
  final String mode;

  const MgysdAccessControl({
    this.requiredUserGroups = const [],
    this.requiredRoles = const [],
    this.mode = 'ANY',
  });

  factory MgysdAccessControl.fromJson(dynamic json) {
    if (json == null || json is! Map) return const MgysdAccessControl();

    return MgysdAccessControl(
      requiredUserGroups: _stringList(json['requiredUserGroups']),
      requiredRoles: _stringList(json['requiredRoles']),
      mode: (json['mode'] ?? 'ANY').toString().trim().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requiredUserGroups': requiredUserGroups,
      'requiredRoles': requiredRoles,
      'mode': mode,
    };
  }

  static List<String> _stringList(dynamic value) {
    if (value == null || value is! List) return <String>[];

    return value
        .map((item) => (item ?? '').toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
}
