// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SpacesTable extends Spaces with TableInfo<$SpacesTable, Space> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _settingsMeta = const VerificationMeta(
    'settings',
  );
  @override
  late final GeneratedColumn<String> settings = GeneratedColumn<String>(
    'settings',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    slug,
    settings,
    capabilities,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Space> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    }
    if (data.containsKey('settings')) {
      context.handle(
        _settingsMeta,
        settings.isAcceptableOrUnknown(data['settings']!, _settingsMeta),
      );
    } else if (isInserting) {
      context.missing(_settingsMeta);
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Space map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Space(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      ),
      settings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings'],
      )!,
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SpacesTable createAlias(String alias) {
    return $SpacesTable(attachedDatabase, alias);
  }
}

class Space extends DataClass implements Insertable<Space> {
  final String id;
  final String name;
  final String? slug;
  final String settings;
  final String capabilities;
  final String createdAt;
  final String updatedAt;
  const Space({
    required this.id,
    required this.name,
    this.slug,
    required this.settings,
    required this.capabilities,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || slug != null) {
      map['slug'] = Variable<String>(slug);
    }
    map['settings'] = Variable<String>(settings);
    map['capabilities'] = Variable<String>(capabilities);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  SpacesCompanion toCompanion(bool nullToAbsent) {
    return SpacesCompanion(
      id: Value(id),
      name: Value(name),
      slug: slug == null && nullToAbsent ? const Value.absent() : Value(slug),
      settings: Value(settings),
      capabilities: Value(capabilities),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Space.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Space(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      slug: serializer.fromJson<String?>(json['slug']),
      settings: serializer.fromJson<String>(json['settings']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'slug': serializer.toJson<String?>(slug),
      'settings': serializer.toJson<String>(settings),
      'capabilities': serializer.toJson<String>(capabilities),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Space copyWith({
    String? id,
    String? name,
    Value<String?> slug = const Value.absent(),
    String? settings,
    String? capabilities,
    String? createdAt,
    String? updatedAt,
  }) => Space(
    id: id ?? this.id,
    name: name ?? this.name,
    slug: slug.present ? slug.value : this.slug,
    settings: settings ?? this.settings,
    capabilities: capabilities ?? this.capabilities,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Space copyWithCompanion(SpacesCompanion data) {
    return Space(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      slug: data.slug.present ? data.slug.value : this.slug,
      settings: data.settings.present ? data.settings.value : this.settings,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Space(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('slug: $slug, ')
          ..write('settings: $settings, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, slug, settings, capabilities, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Space &&
          other.id == this.id &&
          other.name == this.name &&
          other.slug == this.slug &&
          other.settings == this.settings &&
          other.capabilities == this.capabilities &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SpacesCompanion extends UpdateCompanion<Space> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> slug;
  final Value<String> settings;
  final Value<String> capabilities;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const SpacesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.slug = const Value.absent(),
    this.settings = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpacesCompanion.insert({
    required String id,
    required String name,
    this.slug = const Value.absent(),
    required String settings,
    required String capabilities,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       settings = Value(settings),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Space> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? slug,
    Expression<String>? settings,
    Expression<String>? capabilities,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (settings != null) 'settings': settings,
      if (capabilities != null) 'capabilities': capabilities,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpacesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? slug,
    Value<String>? settings,
    Value<String>? capabilities,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return SpacesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      settings: settings ?? this.settings,
      capabilities: capabilities ?? this.capabilities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (settings.present) {
      map['settings'] = Variable<String>(settings.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpacesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('slug: $slug, ')
          ..write('settings: $settings, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MembersTable extends Members with TableInfo<$MembersTable, Member> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    displayName,
    role,
    avatarUrl,
    capabilities,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'members';
  @override
  VerificationContext validateIntegrity(
    Insertable<Member> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Member map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Member(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MembersTable createAlias(String alias) {
    return $MembersTable(attachedDatabase, alias);
  }
}

class Member extends DataClass implements Insertable<Member> {
  final String id;
  final String? spaceId;
  final String displayName;
  final String role;
  final String? avatarUrl;
  final String capabilities;
  final String createdAt;
  final String updatedAt;
  const Member({
    required this.id,
    this.spaceId,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    required this.capabilities,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || spaceId != null) {
      map['space_id'] = Variable<String>(spaceId);
    }
    map['display_name'] = Variable<String>(displayName);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['capabilities'] = Variable<String>(capabilities);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  MembersCompanion toCompanion(bool nullToAbsent) {
    return MembersCompanion(
      id: Value(id),
      spaceId: spaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(spaceId),
      displayName: Value(displayName),
      role: Value(role),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      capabilities: Value(capabilities),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Member.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Member(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String?>(json['spaceId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      role: serializer.fromJson<String>(json['role']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String?>(spaceId),
      'displayName': serializer.toJson<String>(displayName),
      'role': serializer.toJson<String>(role),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'capabilities': serializer.toJson<String>(capabilities),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Member copyWith({
    String? id,
    Value<String?> spaceId = const Value.absent(),
    String? displayName,
    String? role,
    Value<String?> avatarUrl = const Value.absent(),
    String? capabilities,
    String? createdAt,
    String? updatedAt,
  }) => Member(
    id: id ?? this.id,
    spaceId: spaceId.present ? spaceId.value : this.spaceId,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    capabilities: capabilities ?? this.capabilities,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Member copyWithCompanion(MembersCompanion data) {
    return Member(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      role: data.role.present ? data.role.value : this.role,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Member(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    displayName,
    role,
    avatarUrl,
    capabilities,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Member &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.displayName == this.displayName &&
          other.role == this.role &&
          other.avatarUrl == this.avatarUrl &&
          other.capabilities == this.capabilities &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MembersCompanion extends UpdateCompanion<Member> {
  final Value<String> id;
  final Value<String?> spaceId;
  final Value<String> displayName;
  final Value<String> role;
  final Value<String?> avatarUrl;
  final Value<String> capabilities;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const MembersCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.role = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MembersCompanion.insert({
    required String id,
    this.spaceId = const Value.absent(),
    required String displayName,
    required String role,
    this.avatarUrl = const Value.absent(),
    required String capabilities,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       role = Value(role),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Member> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? displayName,
    Expression<String>? role,
    Expression<String>? avatarUrl,
    Expression<String>? capabilities,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (displayName != null) 'display_name': displayName,
      if (role != null) 'role': role,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (capabilities != null) 'capabilities': capabilities,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MembersCompanion copyWith({
    Value<String>? id,
    Value<String?>? spaceId,
    Value<String>? displayName,
    Value<String>? role,
    Value<String?>? avatarUrl,
    Value<String>? capabilities,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return MembersCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      capabilities: capabilities ?? this.capabilities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MembersCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('displayName: $displayName, ')
          ..write('role: $role, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageRangeMeta = const VerificationMeta(
    'ageRange',
  );
  @override
  late final GeneratedColumn<String> ageRange = GeneratedColumn<String>(
    'age_range',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    name,
    ageRange,
    color,
    capabilities,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('age_range')) {
      context.handle(
        _ageRangeMeta,
        ageRange.isAcceptableOrUnknown(data['age_range']!, _ageRangeMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ageRange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_range'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final String id;
  final String spaceId;
  final String name;
  final String? ageRange;
  final String? color;
  final String capabilities;
  final String createdAt;
  final String updatedAt;
  const Group({
    required this.id,
    required this.spaceId,
    required this.name,
    this.ageRange,
    this.color,
    required this.capabilities,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || ageRange != null) {
      map['age_range'] = Variable<String>(ageRange);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['capabilities'] = Variable<String>(capabilities);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      name: Value(name),
      ageRange: ageRange == null && nullToAbsent
          ? const Value.absent()
          : Value(ageRange),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      capabilities: Value(capabilities),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      name: serializer.fromJson<String>(json['name']),
      ageRange: serializer.fromJson<String?>(json['ageRange']),
      color: serializer.fromJson<String?>(json['color']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'name': serializer.toJson<String>(name),
      'ageRange': serializer.toJson<String?>(ageRange),
      'color': serializer.toJson<String?>(color),
      'capabilities': serializer.toJson<String>(capabilities),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Group copyWith({
    String? id,
    String? spaceId,
    String? name,
    Value<String?> ageRange = const Value.absent(),
    Value<String?> color = const Value.absent(),
    String? capabilities,
    String? createdAt,
    String? updatedAt,
  }) => Group(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    name: name ?? this.name,
    ageRange: ageRange.present ? ageRange.value : this.ageRange,
    color: color.present ? color.value : this.color,
    capabilities: capabilities ?? this.capabilities,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      name: data.name.present ? data.name.value : this.name,
      ageRange: data.ageRange.present ? data.ageRange.value : this.ageRange,
      color: data.color.present ? data.color.value : this.color,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('name: $name, ')
          ..write('ageRange: $ageRange, ')
          ..write('color: $color, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    name,
    ageRange,
    color,
    capabilities,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.name == this.name &&
          other.ageRange == this.ageRange &&
          other.color == this.color &&
          other.capabilities == this.capabilities &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> name;
  final Value<String?> ageRange;
  final Value<String?> color;
  final Value<String> capabilities;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.ageRange = const Value.absent(),
    this.color = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String spaceId,
    required String name,
    this.ageRange = const Value.absent(),
    this.color = const Value.absent(),
    required String capabilities,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       name = Value(name),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Group> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? name,
    Expression<String>? ageRange,
    Expression<String>? color,
    Expression<String>? capabilities,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (name != null) 'name': name,
      if (ageRange != null) 'age_range': ageRange,
      if (color != null) 'color': color,
      if (capabilities != null) 'capabilities': capabilities,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? name,
    Value<String?>? ageRange,
    Value<String?>? color,
    Value<String>? capabilities,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      name: name ?? this.name,
      ageRange: ageRange ?? this.ageRange,
      color: color ?? this.color,
      capabilities: capabilities ?? this.capabilities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ageRange.present) {
      map['age_range'] = Variable<String>(ageRange.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('name: $name, ')
          ..write('ageRange: $ageRange, ')
          ..write('color: $color, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubjectsTable extends Subjects with TableInfo<$SubjectsTable, Subject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dobMeta = const VerificationMeta('dob');
  @override
  late final GeneratedColumn<String> dob = GeneratedColumn<String>(
    'dob',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allergiesMeta = const VerificationMeta(
    'allergies',
  );
  @override
  late final GeneratedColumn<String> allergies = GeneratedColumn<String>(
    'allergies',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dropoffWindowStartMeta =
      const VerificationMeta('dropoffWindowStart');
  @override
  late final GeneratedColumn<String> dropoffWindowStart =
      GeneratedColumn<String>(
        'dropoff_window_start',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dropoffWindowEndMeta = const VerificationMeta(
    'dropoffWindowEnd',
  );
  @override
  late final GeneratedColumn<String> dropoffWindowEnd = GeneratedColumn<String>(
    'dropoff_window_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pickupWindowStartMeta = const VerificationMeta(
    'pickupWindowStart',
  );
  @override
  late final GeneratedColumn<String> pickupWindowStart =
      GeneratedColumn<String>(
        'pickup_window_start',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pickupWindowEndMeta = const VerificationMeta(
    'pickupWindowEnd',
  );
  @override
  late final GeneratedColumn<String> pickupWindowEnd = GeneratedColumn<String>(
    'pickup_window_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    groupId,
    firstName,
    lastName,
    dob,
    photoUrl,
    allergies,
    notes,
    capabilities,
    dropoffWindowStart,
    dropoffWindowEnd,
    pickupWindowStart,
    pickupWindowEnd,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subjects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('dob')) {
      context.handle(
        _dobMeta,
        dob.isAcceptableOrUnknown(data['dob']!, _dobMeta),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('allergies')) {
      context.handle(
        _allergiesMeta,
        allergies.isAcceptableOrUnknown(data['allergies']!, _allergiesMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('dropoff_window_start')) {
      context.handle(
        _dropoffWindowStartMeta,
        dropoffWindowStart.isAcceptableOrUnknown(
          data['dropoff_window_start']!,
          _dropoffWindowStartMeta,
        ),
      );
    }
    if (data.containsKey('dropoff_window_end')) {
      context.handle(
        _dropoffWindowEndMeta,
        dropoffWindowEnd.isAcceptableOrUnknown(
          data['dropoff_window_end']!,
          _dropoffWindowEndMeta,
        ),
      );
    }
    if (data.containsKey('pickup_window_start')) {
      context.handle(
        _pickupWindowStartMeta,
        pickupWindowStart.isAcceptableOrUnknown(
          data['pickup_window_start']!,
          _pickupWindowStartMeta,
        ),
      );
    }
    if (data.containsKey('pickup_window_end')) {
      context.handle(
        _pickupWindowEndMeta,
        pickupWindowEnd.isAcceptableOrUnknown(
          data['pickup_window_end']!,
          _pickupWindowEndMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      dob: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dob'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      allergies: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allergies'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      dropoffWindowStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dropoff_window_start'],
      ),
      dropoffWindowEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dropoff_window_end'],
      ),
      pickupWindowStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pickup_window_start'],
      ),
      pickupWindowEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pickup_window_end'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SubjectsTable createAlias(String alias) {
    return $SubjectsTable(attachedDatabase, alias);
  }
}

class Subject extends DataClass implements Insertable<Subject> {
  final String id;
  final String spaceId;
  final String? groupId;
  final String firstName;
  final String lastName;
  final String? dob;
  final String? photoUrl;
  final String? allergies;
  final String? notes;
  final String capabilities;
  final String? dropoffWindowStart;
  final String? dropoffWindowEnd;
  final String? pickupWindowStart;
  final String? pickupWindowEnd;
  final String createdAt;
  final String updatedAt;
  const Subject({
    required this.id,
    required this.spaceId,
    this.groupId,
    required this.firstName,
    required this.lastName,
    this.dob,
    this.photoUrl,
    this.allergies,
    this.notes,
    required this.capabilities,
    this.dropoffWindowStart,
    this.dropoffWindowEnd,
    this.pickupWindowStart,
    this.pickupWindowEnd,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    if (!nullToAbsent || dob != null) {
      map['dob'] = Variable<String>(dob);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    if (!nullToAbsent || allergies != null) {
      map['allergies'] = Variable<String>(allergies);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['capabilities'] = Variable<String>(capabilities);
    if (!nullToAbsent || dropoffWindowStart != null) {
      map['dropoff_window_start'] = Variable<String>(dropoffWindowStart);
    }
    if (!nullToAbsent || dropoffWindowEnd != null) {
      map['dropoff_window_end'] = Variable<String>(dropoffWindowEnd);
    }
    if (!nullToAbsent || pickupWindowStart != null) {
      map['pickup_window_start'] = Variable<String>(pickupWindowStart);
    }
    if (!nullToAbsent || pickupWindowEnd != null) {
      map['pickup_window_end'] = Variable<String>(pickupWindowEnd);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  SubjectsCompanion toCompanion(bool nullToAbsent) {
    return SubjectsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      firstName: Value(firstName),
      lastName: Value(lastName),
      dob: dob == null && nullToAbsent ? const Value.absent() : Value(dob),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      allergies: allergies == null && nullToAbsent
          ? const Value.absent()
          : Value(allergies),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      capabilities: Value(capabilities),
      dropoffWindowStart: dropoffWindowStart == null && nullToAbsent
          ? const Value.absent()
          : Value(dropoffWindowStart),
      dropoffWindowEnd: dropoffWindowEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(dropoffWindowEnd),
      pickupWindowStart: pickupWindowStart == null && nullToAbsent
          ? const Value.absent()
          : Value(pickupWindowStart),
      pickupWindowEnd: pickupWindowEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(pickupWindowEnd),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Subject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subject(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      dob: serializer.fromJson<String?>(json['dob']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      allergies: serializer.fromJson<String?>(json['allergies']),
      notes: serializer.fromJson<String?>(json['notes']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      dropoffWindowStart: serializer.fromJson<String?>(
        json['dropoffWindowStart'],
      ),
      dropoffWindowEnd: serializer.fromJson<String?>(json['dropoffWindowEnd']),
      pickupWindowStart: serializer.fromJson<String?>(
        json['pickupWindowStart'],
      ),
      pickupWindowEnd: serializer.fromJson<String?>(json['pickupWindowEnd']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'groupId': serializer.toJson<String?>(groupId),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'dob': serializer.toJson<String?>(dob),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'allergies': serializer.toJson<String?>(allergies),
      'notes': serializer.toJson<String?>(notes),
      'capabilities': serializer.toJson<String>(capabilities),
      'dropoffWindowStart': serializer.toJson<String?>(dropoffWindowStart),
      'dropoffWindowEnd': serializer.toJson<String?>(dropoffWindowEnd),
      'pickupWindowStart': serializer.toJson<String?>(pickupWindowStart),
      'pickupWindowEnd': serializer.toJson<String?>(pickupWindowEnd),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Subject copyWith({
    String? id,
    String? spaceId,
    Value<String?> groupId = const Value.absent(),
    String? firstName,
    String? lastName,
    Value<String?> dob = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    Value<String?> allergies = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? capabilities,
    Value<String?> dropoffWindowStart = const Value.absent(),
    Value<String?> dropoffWindowEnd = const Value.absent(),
    Value<String?> pickupWindowStart = const Value.absent(),
    Value<String?> pickupWindowEnd = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Subject(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    groupId: groupId.present ? groupId.value : this.groupId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    dob: dob.present ? dob.value : this.dob,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    allergies: allergies.present ? allergies.value : this.allergies,
    notes: notes.present ? notes.value : this.notes,
    capabilities: capabilities ?? this.capabilities,
    dropoffWindowStart: dropoffWindowStart.present
        ? dropoffWindowStart.value
        : this.dropoffWindowStart,
    dropoffWindowEnd: dropoffWindowEnd.present
        ? dropoffWindowEnd.value
        : this.dropoffWindowEnd,
    pickupWindowStart: pickupWindowStart.present
        ? pickupWindowStart.value
        : this.pickupWindowStart,
    pickupWindowEnd: pickupWindowEnd.present
        ? pickupWindowEnd.value
        : this.pickupWindowEnd,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Subject copyWithCompanion(SubjectsCompanion data) {
    return Subject(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      dob: data.dob.present ? data.dob.value : this.dob,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      allergies: data.allergies.present ? data.allergies.value : this.allergies,
      notes: data.notes.present ? data.notes.value : this.notes,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      dropoffWindowStart: data.dropoffWindowStart.present
          ? data.dropoffWindowStart.value
          : this.dropoffWindowStart,
      dropoffWindowEnd: data.dropoffWindowEnd.present
          ? data.dropoffWindowEnd.value
          : this.dropoffWindowEnd,
      pickupWindowStart: data.pickupWindowStart.present
          ? data.pickupWindowStart.value
          : this.pickupWindowStart,
      pickupWindowEnd: data.pickupWindowEnd.present
          ? data.pickupWindowEnd.value
          : this.pickupWindowEnd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subject(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('dob: $dob, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('allergies: $allergies, ')
          ..write('notes: $notes, ')
          ..write('capabilities: $capabilities, ')
          ..write('dropoffWindowStart: $dropoffWindowStart, ')
          ..write('dropoffWindowEnd: $dropoffWindowEnd, ')
          ..write('pickupWindowStart: $pickupWindowStart, ')
          ..write('pickupWindowEnd: $pickupWindowEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    groupId,
    firstName,
    lastName,
    dob,
    photoUrl,
    allergies,
    notes,
    capabilities,
    dropoffWindowStart,
    dropoffWindowEnd,
    pickupWindowStart,
    pickupWindowEnd,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subject &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.groupId == this.groupId &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.dob == this.dob &&
          other.photoUrl == this.photoUrl &&
          other.allergies == this.allergies &&
          other.notes == this.notes &&
          other.capabilities == this.capabilities &&
          other.dropoffWindowStart == this.dropoffWindowStart &&
          other.dropoffWindowEnd == this.dropoffWindowEnd &&
          other.pickupWindowStart == this.pickupWindowStart &&
          other.pickupWindowEnd == this.pickupWindowEnd &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SubjectsCompanion extends UpdateCompanion<Subject> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> groupId;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String?> dob;
  final Value<String?> photoUrl;
  final Value<String?> allergies;
  final Value<String?> notes;
  final Value<String> capabilities;
  final Value<String?> dropoffWindowStart;
  final Value<String?> dropoffWindowEnd;
  final Value<String?> pickupWindowStart;
  final Value<String?> pickupWindowEnd;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const SubjectsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.dob = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.allergies = const Value.absent(),
    this.notes = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.dropoffWindowStart = const Value.absent(),
    this.dropoffWindowEnd = const Value.absent(),
    this.pickupWindowStart = const Value.absent(),
    this.pickupWindowEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectsCompanion.insert({
    required String id,
    required String spaceId,
    this.groupId = const Value.absent(),
    required String firstName,
    required String lastName,
    this.dob = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.allergies = const Value.absent(),
    this.notes = const Value.absent(),
    required String capabilities,
    this.dropoffWindowStart = const Value.absent(),
    this.dropoffWindowEnd = const Value.absent(),
    this.pickupWindowStart = const Value.absent(),
    this.pickupWindowEnd = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       firstName = Value(firstName),
       lastName = Value(lastName),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Subject> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? groupId,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? dob,
    Expression<String>? photoUrl,
    Expression<String>? allergies,
    Expression<String>? notes,
    Expression<String>? capabilities,
    Expression<String>? dropoffWindowStart,
    Expression<String>? dropoffWindowEnd,
    Expression<String>? pickupWindowStart,
    Expression<String>? pickupWindowEnd,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (groupId != null) 'group_id': groupId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (dob != null) 'dob': dob,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (allergies != null) 'allergies': allergies,
      if (notes != null) 'notes': notes,
      if (capabilities != null) 'capabilities': capabilities,
      if (dropoffWindowStart != null)
        'dropoff_window_start': dropoffWindowStart,
      if (dropoffWindowEnd != null) 'dropoff_window_end': dropoffWindowEnd,
      if (pickupWindowStart != null) 'pickup_window_start': pickupWindowStart,
      if (pickupWindowEnd != null) 'pickup_window_end': pickupWindowEnd,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? groupId,
    Value<String>? firstName,
    Value<String>? lastName,
    Value<String?>? dob,
    Value<String?>? photoUrl,
    Value<String?>? allergies,
    Value<String?>? notes,
    Value<String>? capabilities,
    Value<String?>? dropoffWindowStart,
    Value<String?>? dropoffWindowEnd,
    Value<String?>? pickupWindowStart,
    Value<String?>? pickupWindowEnd,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return SubjectsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      groupId: groupId ?? this.groupId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      photoUrl: photoUrl ?? this.photoUrl,
      allergies: allergies ?? this.allergies,
      notes: notes ?? this.notes,
      capabilities: capabilities ?? this.capabilities,
      dropoffWindowStart: dropoffWindowStart ?? this.dropoffWindowStart,
      dropoffWindowEnd: dropoffWindowEnd ?? this.dropoffWindowEnd,
      pickupWindowStart: pickupWindowStart ?? this.pickupWindowStart,
      pickupWindowEnd: pickupWindowEnd ?? this.pickupWindowEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (dob.present) {
      map['dob'] = Variable<String>(dob.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (allergies.present) {
      map['allergies'] = Variable<String>(allergies.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (dropoffWindowStart.present) {
      map['dropoff_window_start'] = Variable<String>(dropoffWindowStart.value);
    }
    if (dropoffWindowEnd.present) {
      map['dropoff_window_end'] = Variable<String>(dropoffWindowEnd.value);
    }
    if (pickupWindowStart.present) {
      map['pickup_window_start'] = Variable<String>(pickupWindowStart.value);
    }
    if (pickupWindowEnd.present) {
      map['pickup_window_end'] = Variable<String>(pickupWindowEnd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('dob: $dob, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('allergies: $allergies, ')
          ..write('notes: $notes, ')
          ..write('capabilities: $capabilities, ')
          ..write('dropoffWindowStart: $dropoffWindowStart, ')
          ..write('dropoffWindowEnd: $dropoffWindowEnd, ')
          ..write('pickupWindowStart: $pickupWindowStart, ')
          ..write('pickupWindowEnd: $pickupWindowEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttendanceRecordsTable extends AttendanceRecords
    with TableInfo<$AttendanceRecordsTable, AttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedByMeta = const VerificationMeta(
    'recordedBy',
  );
  @override
  late final GeneratedColumn<String> recordedBy = GeneratedColumn<String>(
    'recorded_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<String> recordedAt = GeneratedColumn<String>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedByMeta = const VerificationMeta(
    'lastUpdatedBy',
  );
  @override
  late final GeneratedColumn<String> lastUpdatedBy = GeneratedColumn<String>(
    'last_updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    groupId,
    subjectId,
    date,
    status,
    notes,
    recordedBy,
    recordedAt,
    updatedAt,
    lastUpdatedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('recorded_by')) {
      context.handle(
        _recordedByMeta,
        recordedBy.isAcceptableOrUnknown(data['recorded_by']!, _recordedByMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedByMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_updated_by')) {
      context.handle(
        _lastUpdatedByMeta,
        lastUpdatedBy.isAcceptableOrUnknown(
          data['last_updated_by']!,
          _lastUpdatedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      recordedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_by'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      lastUpdatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_updated_by'],
      ),
    );
  }

  @override
  $AttendanceRecordsTable createAlias(String alias) {
    return $AttendanceRecordsTable(attachedDatabase, alias);
  }
}

class AttendanceRecord extends DataClass
    implements Insertable<AttendanceRecord> {
  final String id;
  final String spaceId;
  final String? groupId;
  final String subjectId;
  final String date;
  final String status;
  final String? notes;
  final String recordedBy;
  final String recordedAt;
  final String updatedAt;
  final String? lastUpdatedBy;
  const AttendanceRecord({
    required this.id,
    required this.spaceId,
    this.groupId,
    required this.subjectId,
    required this.date,
    required this.status,
    this.notes,
    required this.recordedBy,
    required this.recordedAt,
    required this.updatedAt,
    this.lastUpdatedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['subject_id'] = Variable<String>(subjectId);
    map['date'] = Variable<String>(date);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['recorded_by'] = Variable<String>(recordedBy);
    map['recorded_at'] = Variable<String>(recordedAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || lastUpdatedBy != null) {
      map['last_updated_by'] = Variable<String>(lastUpdatedBy);
    }
    return map;
  }

  AttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRecordsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      subjectId: Value(subjectId),
      date: Value(date),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      recordedBy: Value(recordedBy),
      recordedAt: Value(recordedAt),
      updatedAt: Value(updatedAt),
      lastUpdatedBy: lastUpdatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdatedBy),
    );
  }

  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceRecord(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      date: serializer.fromJson<String>(json['date']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      recordedBy: serializer.fromJson<String>(json['recordedBy']),
      recordedAt: serializer.fromJson<String>(json['recordedAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      lastUpdatedBy: serializer.fromJson<String?>(json['lastUpdatedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'groupId': serializer.toJson<String?>(groupId),
      'subjectId': serializer.toJson<String>(subjectId),
      'date': serializer.toJson<String>(date),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'recordedBy': serializer.toJson<String>(recordedBy),
      'recordedAt': serializer.toJson<String>(recordedAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'lastUpdatedBy': serializer.toJson<String?>(lastUpdatedBy),
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? spaceId,
    Value<String?> groupId = const Value.absent(),
    String? subjectId,
    String? date,
    String? status,
    Value<String?> notes = const Value.absent(),
    String? recordedBy,
    String? recordedAt,
    String? updatedAt,
    Value<String?> lastUpdatedBy = const Value.absent(),
  }) => AttendanceRecord(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    groupId: groupId.present ? groupId.value : this.groupId,
    subjectId: subjectId ?? this.subjectId,
    date: date ?? this.date,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    recordedBy: recordedBy ?? this.recordedBy,
    recordedAt: recordedAt ?? this.recordedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastUpdatedBy: lastUpdatedBy.present
        ? lastUpdatedBy.value
        : this.lastUpdatedBy,
  );
  AttendanceRecord copyWithCompanion(AttendanceRecordsCompanion data) {
    return AttendanceRecord(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      recordedBy: data.recordedBy.present
          ? data.recordedBy.value
          : this.recordedBy,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastUpdatedBy: data.lastUpdatedBy.present
          ? data.lastUpdatedBy.value
          : this.lastUpdatedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecord(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('subjectId: $subjectId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUpdatedBy: $lastUpdatedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    groupId,
    subjectId,
    date,
    status,
    notes,
    recordedBy,
    recordedAt,
    updatedAt,
    lastUpdatedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRecord &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.groupId == this.groupId &&
          other.subjectId == this.subjectId &&
          other.date == this.date &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.recordedBy == this.recordedBy &&
          other.recordedAt == this.recordedAt &&
          other.updatedAt == this.updatedAt &&
          other.lastUpdatedBy == this.lastUpdatedBy);
}

class AttendanceRecordsCompanion extends UpdateCompanion<AttendanceRecord> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> groupId;
  final Value<String> subjectId;
  final Value<String> date;
  final Value<String> status;
  final Value<String?> notes;
  final Value<String> recordedBy;
  final Value<String> recordedAt;
  final Value<String> updatedAt;
  final Value<String?> lastUpdatedBy;
  final Value<int> rowid;
  const AttendanceRecordsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.recordedBy = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastUpdatedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttendanceRecordsCompanion.insert({
    required String id,
    required String spaceId,
    this.groupId = const Value.absent(),
    required String subjectId,
    required String date,
    required String status,
    this.notes = const Value.absent(),
    required String recordedBy,
    required String recordedAt,
    required String updatedAt,
    this.lastUpdatedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       subjectId = Value(subjectId),
       date = Value(date),
       status = Value(status),
       recordedBy = Value(recordedBy),
       recordedAt = Value(recordedAt),
       updatedAt = Value(updatedAt);
  static Insertable<AttendanceRecord> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? groupId,
    Expression<String>? subjectId,
    Expression<String>? date,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? recordedBy,
    Expression<String>? recordedAt,
    Expression<String>? updatedAt,
    Expression<String>? lastUpdatedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (groupId != null) 'group_id': groupId,
      if (subjectId != null) 'subject_id': subjectId,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (recordedBy != null) 'recorded_by': recordedBy,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastUpdatedBy != null) 'last_updated_by': lastUpdatedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttendanceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? groupId,
    Value<String>? subjectId,
    Value<String>? date,
    Value<String>? status,
    Value<String?>? notes,
    Value<String>? recordedBy,
    Value<String>? recordedAt,
    Value<String>? updatedAt,
    Value<String?>? lastUpdatedBy,
    Value<int>? rowid,
  }) {
    return AttendanceRecordsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      groupId: groupId ?? this.groupId,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedAt: recordedAt ?? this.recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (recordedBy.present) {
      map['recorded_by'] = Variable<String>(recordedBy.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<String>(recordedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (lastUpdatedBy.present) {
      map['last_updated_by'] = Variable<String>(lastUpdatedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('subjectId: $subjectId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastUpdatedBy: $lastUpdatedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvitesTable extends Invites with TableInfo<$InvitesTable, Invite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<String> expiresAt = GeneratedColumn<String>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<String> acceptedAt = GeneratedColumn<String>(
    'accepted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acceptedByMeta = const VerificationMeta(
    'acceptedBy',
  );
  @override
  late final GeneratedColumn<String> acceptedBy = GeneratedColumn<String>(
    'accepted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    email,
    code,
    role,
    subjectId,
    capabilities,
    createdBy,
    createdAt,
    expiresAt,
    acceptedAt,
    acceptedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Invite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    }
    if (data.containsKey('accepted_by')) {
      context.handle(
        _acceptedByMeta,
        acceptedBy.isAcceptableOrUnknown(data['accepted_by']!, _acceptedByMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Invite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Invite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expires_at'],
      ),
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accepted_at'],
      ),
      acceptedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accepted_by'],
      ),
    );
  }

  @override
  $InvitesTable createAlias(String alias) {
    return $InvitesTable(attachedDatabase, alias);
  }
}

class Invite extends DataClass implements Insertable<Invite> {
  final String id;
  final String spaceId;
  final String? email;
  final String? code;
  final String role;

  /// Set for guardian-intent invites — the child this guardian is
  /// being invited as a parent / family member for. Null for staff.
  final String? subjectId;
  final String capabilities;
  final String? createdBy;
  final String createdAt;
  final String? expiresAt;
  final String? acceptedAt;
  final String? acceptedBy;
  const Invite({
    required this.id,
    required this.spaceId,
    this.email,
    this.code,
    required this.role,
    this.subjectId,
    required this.capabilities,
    this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.acceptedAt,
    this.acceptedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    map['capabilities'] = Variable<String>(capabilities);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<String>(expiresAt);
    }
    if (!nullToAbsent || acceptedAt != null) {
      map['accepted_at'] = Variable<String>(acceptedAt);
    }
    if (!nullToAbsent || acceptedBy != null) {
      map['accepted_by'] = Variable<String>(acceptedBy);
    }
    return map;
  }

  InvitesCompanion toCompanion(bool nullToAbsent) {
    return InvitesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      role: Value(role),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      capabilities: Value(capabilities),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdAt: Value(createdAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      acceptedAt: acceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedAt),
      acceptedBy: acceptedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedBy),
    );
  }

  factory Invite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Invite(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      email: serializer.fromJson<String?>(json['email']),
      code: serializer.fromJson<String?>(json['code']),
      role: serializer.fromJson<String>(json['role']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      expiresAt: serializer.fromJson<String?>(json['expiresAt']),
      acceptedAt: serializer.fromJson<String?>(json['acceptedAt']),
      acceptedBy: serializer.fromJson<String?>(json['acceptedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'email': serializer.toJson<String?>(email),
      'code': serializer.toJson<String?>(code),
      'role': serializer.toJson<String>(role),
      'subjectId': serializer.toJson<String?>(subjectId),
      'capabilities': serializer.toJson<String>(capabilities),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdAt': serializer.toJson<String>(createdAt),
      'expiresAt': serializer.toJson<String?>(expiresAt),
      'acceptedAt': serializer.toJson<String?>(acceptedAt),
      'acceptedBy': serializer.toJson<String?>(acceptedBy),
    };
  }

  Invite copyWith({
    String? id,
    String? spaceId,
    Value<String?> email = const Value.absent(),
    Value<String?> code = const Value.absent(),
    String? role,
    Value<String?> subjectId = const Value.absent(),
    String? capabilities,
    Value<String?> createdBy = const Value.absent(),
    String? createdAt,
    Value<String?> expiresAt = const Value.absent(),
    Value<String?> acceptedAt = const Value.absent(),
    Value<String?> acceptedBy = const Value.absent(),
  }) => Invite(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    email: email.present ? email.value : this.email,
    code: code.present ? code.value : this.code,
    role: role ?? this.role,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    capabilities: capabilities ?? this.capabilities,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    acceptedAt: acceptedAt.present ? acceptedAt.value : this.acceptedAt,
    acceptedBy: acceptedBy.present ? acceptedBy.value : this.acceptedBy,
  );
  Invite copyWithCompanion(InvitesCompanion data) {
    return Invite(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      email: data.email.present ? data.email.value : this.email,
      code: data.code.present ? data.code.value : this.code,
      role: data.role.present ? data.role.value : this.role,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
      acceptedBy: data.acceptedBy.present
          ? data.acceptedBy.value
          : this.acceptedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Invite(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('email: $email, ')
          ..write('code: $code, ')
          ..write('role: $role, ')
          ..write('subjectId: $subjectId, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('acceptedBy: $acceptedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    email,
    code,
    role,
    subjectId,
    capabilities,
    createdBy,
    createdAt,
    expiresAt,
    acceptedAt,
    acceptedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Invite &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.email == this.email &&
          other.code == this.code &&
          other.role == this.role &&
          other.subjectId == this.subjectId &&
          other.capabilities == this.capabilities &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.acceptedAt == this.acceptedAt &&
          other.acceptedBy == this.acceptedBy);
}

class InvitesCompanion extends UpdateCompanion<Invite> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> email;
  final Value<String?> code;
  final Value<String> role;
  final Value<String?> subjectId;
  final Value<String> capabilities;
  final Value<String?> createdBy;
  final Value<String> createdAt;
  final Value<String?> expiresAt;
  final Value<String?> acceptedAt;
  final Value<String?> acceptedBy;
  final Value<int> rowid;
  const InvitesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.email = const Value.absent(),
    this.code = const Value.absent(),
    this.role = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.acceptedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvitesCompanion.insert({
    required String id,
    required String spaceId,
    this.email = const Value.absent(),
    this.code = const Value.absent(),
    required String role,
    this.subjectId = const Value.absent(),
    required String capabilities,
    this.createdBy = const Value.absent(),
    required String createdAt,
    this.expiresAt = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.acceptedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       role = Value(role),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt);
  static Insertable<Invite> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? email,
    Expression<String>? code,
    Expression<String>? role,
    Expression<String>? subjectId,
    Expression<String>? capabilities,
    Expression<String>? createdBy,
    Expression<String>? createdAt,
    Expression<String>? expiresAt,
    Expression<String>? acceptedAt,
    Expression<String>? acceptedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (email != null) 'email': email,
      if (code != null) 'code': code,
      if (role != null) 'role': role,
      if (subjectId != null) 'subject_id': subjectId,
      if (capabilities != null) 'capabilities': capabilities,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (acceptedBy != null) 'accepted_by': acceptedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvitesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? email,
    Value<String?>? code,
    Value<String>? role,
    Value<String?>? subjectId,
    Value<String>? capabilities,
    Value<String?>? createdBy,
    Value<String>? createdAt,
    Value<String?>? expiresAt,
    Value<String?>? acceptedAt,
    Value<String?>? acceptedBy,
    Value<int>? rowid,
  }) {
    return InvitesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      email: email ?? this.email,
      code: code ?? this.code,
      role: role ?? this.role,
      subjectId: subjectId ?? this.subjectId,
      capabilities: capabilities ?? this.capabilities,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<String>(expiresAt.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<String>(acceptedAt.value);
    }
    if (acceptedBy.present) {
      map['accepted_by'] = Variable<String>(acceptedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvitesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('email: $email, ')
          ..write('code: $code, ')
          ..write('role: $role, ')
          ..write('subjectId: $subjectId, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('acceptedBy: $acceptedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTable extends GroupMembers
    with TableInfo<$GroupMembersTable, GroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleInGroupMeta = const VerificationMeta(
    'roleInGroup',
  );
  @override
  late final GeneratedColumn<String> roleInGroup = GeneratedColumn<String>(
    'role_in_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assignedAtMeta = const VerificationMeta(
    'assignedAt',
  );
  @override
  late final GeneratedColumn<String> assignedAt = GeneratedColumn<String>(
    'assigned_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    memberId,
    spaceId,
    roleInGroup,
    assignedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('role_in_group')) {
      context.handle(
        _roleInGroupMeta,
        roleInGroup.isAcceptableOrUnknown(
          data['role_in_group']!,
          _roleInGroupMeta,
        ),
      );
    }
    if (data.containsKey('assigned_at')) {
      context.handle(
        _assignedAtMeta,
        assignedAt.isAcceptableOrUnknown(data['assigned_at']!, _assignedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_assignedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      roleInGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_in_group'],
      ),
      assignedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_at'],
      )!,
    );
  }

  @override
  $GroupMembersTable createAlias(String alias) {
    return $GroupMembersTable(attachedDatabase, alias);
  }
}

class GroupMember extends DataClass implements Insertable<GroupMember> {
  final String id;
  final String groupId;
  final String memberId;
  final String spaceId;
  final String? roleInGroup;
  final String assignedAt;
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.spaceId,
    this.roleInGroup,
    required this.assignedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['member_id'] = Variable<String>(memberId);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || roleInGroup != null) {
      map['role_in_group'] = Variable<String>(roleInGroup);
    }
    map['assigned_at'] = Variable<String>(assignedAt);
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      id: Value(id),
      groupId: Value(groupId),
      memberId: Value(memberId),
      spaceId: Value(spaceId),
      roleInGroup: roleInGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(roleInGroup),
      assignedAt: Value(assignedAt),
    );
  }

  factory GroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMember(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      memberId: serializer.fromJson<String>(json['memberId']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      roleInGroup: serializer.fromJson<String?>(json['roleInGroup']),
      assignedAt: serializer.fromJson<String>(json['assignedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'memberId': serializer.toJson<String>(memberId),
      'spaceId': serializer.toJson<String>(spaceId),
      'roleInGroup': serializer.toJson<String?>(roleInGroup),
      'assignedAt': serializer.toJson<String>(assignedAt),
    };
  }

  GroupMember copyWith({
    String? id,
    String? groupId,
    String? memberId,
    String? spaceId,
    Value<String?> roleInGroup = const Value.absent(),
    String? assignedAt,
  }) => GroupMember(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    memberId: memberId ?? this.memberId,
    spaceId: spaceId ?? this.spaceId,
    roleInGroup: roleInGroup.present ? roleInGroup.value : this.roleInGroup,
    assignedAt: assignedAt ?? this.assignedAt,
  );
  GroupMember copyWithCompanion(GroupMembersCompanion data) {
    return GroupMember(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      roleInGroup: data.roleInGroup.present
          ? data.roleInGroup.value
          : this.roleInGroup,
      assignedAt: data.assignedAt.present
          ? data.assignedAt.value
          : this.assignedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMember(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('memberId: $memberId, ')
          ..write('spaceId: $spaceId, ')
          ..write('roleInGroup: $roleInGroup, ')
          ..write('assignedAt: $assignedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, memberId, spaceId, roleInGroup, assignedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMember &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.memberId == this.memberId &&
          other.spaceId == this.spaceId &&
          other.roleInGroup == this.roleInGroup &&
          other.assignedAt == this.assignedAt);
}

class GroupMembersCompanion extends UpdateCompanion<GroupMember> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> memberId;
  final Value<String> spaceId;
  final Value<String?> roleInGroup;
  final Value<String> assignedAt;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.roleInGroup = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required String id,
    required String groupId,
    required String memberId,
    required String spaceId,
    this.roleInGroup = const Value.absent(),
    required String assignedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       memberId = Value(memberId),
       spaceId = Value(spaceId),
       assignedAt = Value(assignedAt);
  static Insertable<GroupMember> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? memberId,
    Expression<String>? spaceId,
    Expression<String>? roleInGroup,
    Expression<String>? assignedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (memberId != null) 'member_id': memberId,
      if (spaceId != null) 'space_id': spaceId,
      if (roleInGroup != null) 'role_in_group': roleInGroup,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? memberId,
    Value<String>? spaceId,
    Value<String?>? roleInGroup,
    Value<String>? assignedAt,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      memberId: memberId ?? this.memberId,
      spaceId: spaceId ?? this.spaceId,
      roleInGroup: roleInGroup ?? this.roleInGroup,
      assignedAt: assignedAt ?? this.assignedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (roleInGroup.present) {
      map['role_in_group'] = Variable<String>(roleInGroup.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<String>(assignedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('memberId: $memberId, ')
          ..write('spaceId: $spaceId, ')
          ..write('roleInGroup: $roleInGroup, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedByMeta = const VerificationMeta(
    'recordedBy',
  );
  @override
  late final GeneratedColumn<String> recordedBy = GeneratedColumn<String>(
    'recorded_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<String> recordedAt = GeneratedColumn<String>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    groupId,
    subjectId,
    kind,
    body,
    photoUrl,
    details,
    recordedBy,
    recordedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    } else if (isInserting) {
      context.missing(_detailsMeta);
    }
    if (data.containsKey('recorded_by')) {
      context.handle(
        _recordedByMeta,
        recordedBy.isAcceptableOrUnknown(data['recorded_by']!, _recordedByMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedByMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      recordedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_by'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final String spaceId;
  final String? groupId;
  final String? subjectId;
  final String kind;
  final String? body;
  final String? photoUrl;
  final String details;
  final String recordedBy;
  final String recordedAt;
  final String updatedAt;
  const Entry({
    required this.id,
    required this.spaceId,
    this.groupId,
    this.subjectId,
    required this.kind,
    this.body,
    this.photoUrl,
    required this.details,
    required this.recordedBy,
    required this.recordedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || body != null) {
      map['text'] = Variable<String>(body);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['details'] = Variable<String>(details);
    map['recorded_by'] = Variable<String>(recordedBy);
    map['recorded_at'] = Variable<String>(recordedAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      kind: Value(kind),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      details: Value(details),
      recordedBy: Value(recordedBy),
      recordedAt: Value(recordedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String?>(json['body']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      details: serializer.fromJson<String>(json['details']),
      recordedBy: serializer.fromJson<String>(json['recordedBy']),
      recordedAt: serializer.fromJson<String>(json['recordedAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'groupId': serializer.toJson<String?>(groupId),
      'subjectId': serializer.toJson<String?>(subjectId),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String?>(body),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'details': serializer.toJson<String>(details),
      'recordedBy': serializer.toJson<String>(recordedBy),
      'recordedAt': serializer.toJson<String>(recordedAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Entry copyWith({
    String? id,
    String? spaceId,
    Value<String?> groupId = const Value.absent(),
    Value<String?> subjectId = const Value.absent(),
    String? kind,
    Value<String?> body = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    String? details,
    String? recordedBy,
    String? recordedAt,
    String? updatedAt,
  }) => Entry(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    groupId: groupId.present ? groupId.value : this.groupId,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    kind: kind ?? this.kind,
    body: body.present ? body.value : this.body,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    details: details ?? this.details,
    recordedBy: recordedBy ?? this.recordedBy,
    recordedAt: recordedAt ?? this.recordedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      details: data.details.present ? data.details.value : this.details,
      recordedBy: data.recordedBy.present
          ? data.recordedBy.value
          : this.recordedBy,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('subjectId: $subjectId, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('details: $details, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    groupId,
    subjectId,
    kind,
    body,
    photoUrl,
    details,
    recordedBy,
    recordedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.groupId == this.groupId &&
          other.subjectId == this.subjectId &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.photoUrl == this.photoUrl &&
          other.details == this.details &&
          other.recordedBy == this.recordedBy &&
          other.recordedAt == this.recordedAt &&
          other.updatedAt == this.updatedAt);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> groupId;
  final Value<String?> subjectId;
  final Value<String> kind;
  final Value<String?> body;
  final Value<String?> photoUrl;
  final Value<String> details;
  final Value<String> recordedBy;
  final Value<String> recordedAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.details = const Value.absent(),
    this.recordedBy = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String spaceId,
    this.groupId = const Value.absent(),
    this.subjectId = const Value.absent(),
    required String kind,
    this.body = const Value.absent(),
    this.photoUrl = const Value.absent(),
    required String details,
    required String recordedBy,
    required String recordedAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       kind = Value(kind),
       details = Value(details),
       recordedBy = Value(recordedBy),
       recordedAt = Value(recordedAt),
       updatedAt = Value(updatedAt);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? groupId,
    Expression<String>? subjectId,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<String>? photoUrl,
    Expression<String>? details,
    Expression<String>? recordedBy,
    Expression<String>? recordedAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (groupId != null) 'group_id': groupId,
      if (subjectId != null) 'subject_id': subjectId,
      if (kind != null) 'kind': kind,
      if (body != null) 'text': body,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (details != null) 'details': details,
      if (recordedBy != null) 'recorded_by': recordedBy,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? groupId,
    Value<String?>? subjectId,
    Value<String>? kind,
    Value<String?>? body,
    Value<String?>? photoUrl,
    Value<String>? details,
    Value<String>? recordedBy,
    Value<String>? recordedAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      groupId: groupId ?? this.groupId,
      subjectId: subjectId ?? this.subjectId,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      photoUrl: photoUrl ?? this.photoUrl,
      details: details ?? this.details,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedAt: recordedAt ?? this.recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (recordedBy.present) {
      map['recorded_by'] = Variable<String>(recordedBy.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<String>(recordedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('subjectId: $subjectId, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('details: $details, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GuardiansTable extends Guardians
    with TableInfo<$GuardiansTable, Guardian> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuardiansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationshipMeta = const VerificationMeta(
    'relationship',
  );
  @override
  late final GeneratedColumn<String> relationship = GeneratedColumn<String>(
    'relationship',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorizedForPickupMeta =
      const VerificationMeta('authorizedForPickup');
  @override
  late final GeneratedColumn<int> authorizedForPickup = GeneratedColumn<int>(
    'authorized_for_pickup',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    userId,
    name,
    relationship,
    phone,
    email,
    authorizedForPickup,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guardians';
  @override
  VerificationContext validateIntegrity(
    Insertable<Guardian> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('relationship')) {
      context.handle(
        _relationshipMeta,
        relationship.isAcceptableOrUnknown(
          data['relationship']!,
          _relationshipMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('authorized_for_pickup')) {
      context.handle(
        _authorizedForPickupMeta,
        authorizedForPickup.isAcceptableOrUnknown(
          data['authorized_for_pickup']!,
          _authorizedForPickupMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Guardian map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Guardian(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      relationship: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      authorizedForPickup: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}authorized_for_pickup'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GuardiansTable createAlias(String alias) {
    return $GuardiansTable(attachedDatabase, alias);
  }
}

class Guardian extends DataClass implements Insertable<Guardian> {
  final String id;
  final String spaceId;

  /// Links to auth.users.id once this guardian accepts an invite and
  /// signs into the family app. Null until then — directors add
  /// guardian contact info long before the parent ever logs in.
  final String? userId;
  final String name;
  final String? relationship;
  final String? phone;
  final String? email;
  final int? authorizedForPickup;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  const Guardian({
    required this.id,
    required this.spaceId,
    this.userId,
    required this.name,
    this.relationship,
    this.phone,
    this.email,
    this.authorizedForPickup,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || relationship != null) {
      map['relationship'] = Variable<String>(relationship);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || authorizedForPickup != null) {
      map['authorized_for_pickup'] = Variable<int>(authorizedForPickup);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  GuardiansCompanion toCompanion(bool nullToAbsent) {
    return GuardiansCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      name: Value(name),
      relationship: relationship == null && nullToAbsent
          ? const Value.absent()
          : Value(relationship),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      authorizedForPickup: authorizedForPickup == null && nullToAbsent
          ? const Value.absent()
          : Value(authorizedForPickup),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Guardian.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Guardian(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      userId: serializer.fromJson<String?>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      relationship: serializer.fromJson<String?>(json['relationship']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      authorizedForPickup: serializer.fromJson<int?>(
        json['authorizedForPickup'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'userId': serializer.toJson<String?>(userId),
      'name': serializer.toJson<String>(name),
      'relationship': serializer.toJson<String?>(relationship),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'authorizedForPickup': serializer.toJson<int?>(authorizedForPickup),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Guardian copyWith({
    String? id,
    String? spaceId,
    Value<String?> userId = const Value.absent(),
    String? name,
    Value<String?> relationship = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<int?> authorizedForPickup = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Guardian(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    userId: userId.present ? userId.value : this.userId,
    name: name ?? this.name,
    relationship: relationship.present ? relationship.value : this.relationship,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    authorizedForPickup: authorizedForPickup.present
        ? authorizedForPickup.value
        : this.authorizedForPickup,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Guardian copyWithCompanion(GuardiansCompanion data) {
    return Guardian(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      relationship: data.relationship.present
          ? data.relationship.value
          : this.relationship,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      authorizedForPickup: data.authorizedForPickup.present
          ? data.authorizedForPickup.value
          : this.authorizedForPickup,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Guardian(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('relationship: $relationship, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('authorizedForPickup: $authorizedForPickup, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    userId,
    name,
    relationship,
    phone,
    email,
    authorizedForPickup,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Guardian &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.relationship == this.relationship &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.authorizedForPickup == this.authorizedForPickup &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GuardiansCompanion extends UpdateCompanion<Guardian> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> userId;
  final Value<String> name;
  final Value<String?> relationship;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<int?> authorizedForPickup;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const GuardiansCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.relationship = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.authorizedForPickup = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GuardiansCompanion.insert({
    required String id,
    required String spaceId,
    this.userId = const Value.absent(),
    required String name,
    this.relationship = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.authorizedForPickup = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Guardian> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? relationship,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<int>? authorizedForPickup,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (relationship != null) 'relationship': relationship,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (authorizedForPickup != null)
        'authorized_for_pickup': authorizedForPickup,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GuardiansCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? userId,
    Value<String>? name,
    Value<String?>? relationship,
    Value<String?>? phone,
    Value<String?>? email,
    Value<int?>? authorizedForPickup,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return GuardiansCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      authorizedForPickup: authorizedForPickup ?? this.authorizedForPickup,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (relationship.present) {
      map['relationship'] = Variable<String>(relationship.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (authorizedForPickup.present) {
      map['authorized_for_pickup'] = Variable<int>(authorizedForPickup.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuardiansCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('relationship: $relationship, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('authorizedForPickup: $authorizedForPickup, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubjectGuardiansTable extends SubjectGuardians
    with TableInfo<$SubjectGuardiansTable, SubjectGuardian> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectGuardiansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guardianIdMeta = const VerificationMeta(
    'guardianId',
  );
  @override
  late final GeneratedColumn<String> guardianId = GeneratedColumn<String>(
    'guardian_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<int> isPrimary = GeneratedColumn<int>(
    'is_primary',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectId,
    guardianId,
    spaceId,
    isPrimary,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subject_guardians';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectGuardian> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('guardian_id')) {
      context.handle(
        _guardianIdMeta,
        guardianId.isAcceptableOrUnknown(data['guardian_id']!, _guardianIdMeta),
      );
    } else if (isInserting) {
      context.missing(_guardianIdMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubjectGuardian map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectGuardian(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      guardianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guardian_id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_primary'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SubjectGuardiansTable createAlias(String alias) {
    return $SubjectGuardiansTable(attachedDatabase, alias);
  }
}

class SubjectGuardian extends DataClass implements Insertable<SubjectGuardian> {
  final String id;
  final String subjectId;
  final String guardianId;
  final String spaceId;
  final int? isPrimary;
  final String createdAt;
  const SubjectGuardian({
    required this.id,
    required this.subjectId,
    required this.guardianId,
    required this.spaceId,
    this.isPrimary,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_id'] = Variable<String>(subjectId);
    map['guardian_id'] = Variable<String>(guardianId);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || isPrimary != null) {
      map['is_primary'] = Variable<int>(isPrimary);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  SubjectGuardiansCompanion toCompanion(bool nullToAbsent) {
    return SubjectGuardiansCompanion(
      id: Value(id),
      subjectId: Value(subjectId),
      guardianId: Value(guardianId),
      spaceId: Value(spaceId),
      isPrimary: isPrimary == null && nullToAbsent
          ? const Value.absent()
          : Value(isPrimary),
      createdAt: Value(createdAt),
    );
  }

  factory SubjectGuardian.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectGuardian(
      id: serializer.fromJson<String>(json['id']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      guardianId: serializer.fromJson<String>(json['guardianId']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      isPrimary: serializer.fromJson<int?>(json['isPrimary']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectId': serializer.toJson<String>(subjectId),
      'guardianId': serializer.toJson<String>(guardianId),
      'spaceId': serializer.toJson<String>(spaceId),
      'isPrimary': serializer.toJson<int?>(isPrimary),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  SubjectGuardian copyWith({
    String? id,
    String? subjectId,
    String? guardianId,
    String? spaceId,
    Value<int?> isPrimary = const Value.absent(),
    String? createdAt,
  }) => SubjectGuardian(
    id: id ?? this.id,
    subjectId: subjectId ?? this.subjectId,
    guardianId: guardianId ?? this.guardianId,
    spaceId: spaceId ?? this.spaceId,
    isPrimary: isPrimary.present ? isPrimary.value : this.isPrimary,
    createdAt: createdAt ?? this.createdAt,
  );
  SubjectGuardian copyWithCompanion(SubjectGuardiansCompanion data) {
    return SubjectGuardian(
      id: data.id.present ? data.id.value : this.id,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      guardianId: data.guardianId.present
          ? data.guardianId.value
          : this.guardianId,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectGuardian(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('guardianId: $guardianId, ')
          ..write('spaceId: $spaceId, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectId, guardianId, spaceId, isPrimary, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectGuardian &&
          other.id == this.id &&
          other.subjectId == this.subjectId &&
          other.guardianId == this.guardianId &&
          other.spaceId == this.spaceId &&
          other.isPrimary == this.isPrimary &&
          other.createdAt == this.createdAt);
}

class SubjectGuardiansCompanion extends UpdateCompanion<SubjectGuardian> {
  final Value<String> id;
  final Value<String> subjectId;
  final Value<String> guardianId;
  final Value<String> spaceId;
  final Value<int?> isPrimary;
  final Value<String> createdAt;
  final Value<int> rowid;
  const SubjectGuardiansCompanion({
    this.id = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.guardianId = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectGuardiansCompanion.insert({
    required String id,
    required String subjectId,
    required String guardianId,
    required String spaceId,
    this.isPrimary = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectId = Value(subjectId),
       guardianId = Value(guardianId),
       spaceId = Value(spaceId),
       createdAt = Value(createdAt);
  static Insertable<SubjectGuardian> custom({
    Expression<String>? id,
    Expression<String>? subjectId,
    Expression<String>? guardianId,
    Expression<String>? spaceId,
    Expression<int>? isPrimary,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectId != null) 'subject_id': subjectId,
      if (guardianId != null) 'guardian_id': guardianId,
      if (spaceId != null) 'space_id': spaceId,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectGuardiansCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectId,
    Value<String>? guardianId,
    Value<String>? spaceId,
    Value<int?>? isPrimary,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return SubjectGuardiansCompanion(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      guardianId: guardianId ?? this.guardianId,
      spaceId: spaceId ?? this.spaceId,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (guardianId.present) {
      map['guardian_id'] = Variable<String>(guardianId.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<int>(isPrimary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectGuardiansCompanion(')
          ..write('id: $id, ')
          ..write('subjectId: $subjectId, ')
          ..write('guardianId: $guardianId, ')
          ..write('spaceId: $spaceId, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _licensePlateMeta = const VerificationMeta(
    'licensePlate',
  );
  @override
  late final GeneratedColumn<String> licensePlate = GeneratedColumn<String>(
    'license_plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    name,
    make,
    model,
    year,
    licensePlate,
    color,
    photoUrl,
    notes,
    capabilities,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('make')) {
      context.handle(
        _makeMeta,
        make.isAcceptableOrUnknown(data['make']!, _makeMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('license_plate')) {
      context.handle(
        _licensePlateMeta,
        licensePlate.isAcceptableOrUnknown(
          data['license_plate']!,
          _licensePlateMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      make: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}make'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      licensePlate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_plate'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final String id;
  final String spaceId;
  final String name;
  final String? make;
  final String? model;
  final int? year;
  final String? licensePlate;
  final String? color;
  final String? photoUrl;
  final String? notes;
  final String capabilities;
  final String createdAt;
  final String updatedAt;
  const Vehicle({
    required this.id,
    required this.spaceId,
    required this.name,
    this.make,
    this.model,
    this.year,
    this.licensePlate,
    this.color,
    this.photoUrl,
    this.notes,
    required this.capabilities,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || make != null) {
      map['make'] = Variable<String>(make);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || licensePlate != null) {
      map['license_plate'] = Variable<String>(licensePlate);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['capabilities'] = Variable<String>(capabilities);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      name: Value(name),
      make: make == null && nullToAbsent ? const Value.absent() : Value(make),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      licensePlate: licensePlate == null && nullToAbsent
          ? const Value.absent()
          : Value(licensePlate),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      capabilities: Value(capabilities),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Vehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      name: serializer.fromJson<String>(json['name']),
      make: serializer.fromJson<String?>(json['make']),
      model: serializer.fromJson<String?>(json['model']),
      year: serializer.fromJson<int?>(json['year']),
      licensePlate: serializer.fromJson<String?>(json['licensePlate']),
      color: serializer.fromJson<String?>(json['color']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      notes: serializer.fromJson<String?>(json['notes']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'name': serializer.toJson<String>(name),
      'make': serializer.toJson<String?>(make),
      'model': serializer.toJson<String?>(model),
      'year': serializer.toJson<int?>(year),
      'licensePlate': serializer.toJson<String?>(licensePlate),
      'color': serializer.toJson<String?>(color),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'notes': serializer.toJson<String?>(notes),
      'capabilities': serializer.toJson<String>(capabilities),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Vehicle copyWith({
    String? id,
    String? spaceId,
    String? name,
    Value<String?> make = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> licensePlate = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? capabilities,
    String? createdAt,
    String? updatedAt,
  }) => Vehicle(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    name: name ?? this.name,
    make: make.present ? make.value : this.make,
    model: model.present ? model.value : this.model,
    year: year.present ? year.value : this.year,
    licensePlate: licensePlate.present ? licensePlate.value : this.licensePlate,
    color: color.present ? color.value : this.color,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    notes: notes.present ? notes.value : this.notes,
    capabilities: capabilities ?? this.capabilities,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      name: data.name.present ? data.name.value : this.name,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      year: data.year.present ? data.year.value : this.year,
      licensePlate: data.licensePlate.present
          ? data.licensePlate.value
          : this.licensePlate,
      color: data.color.present ? data.color.value : this.color,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      notes: data.notes.present ? data.notes.value : this.notes,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('name: $name, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('color: $color, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('notes: $notes, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    name,
    make,
    model,
    year,
    licensePlate,
    color,
    photoUrl,
    notes,
    capabilities,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.name == this.name &&
          other.make == this.make &&
          other.model == this.model &&
          other.year == this.year &&
          other.licensePlate == this.licensePlate &&
          other.color == this.color &&
          other.photoUrl == this.photoUrl &&
          other.notes == this.notes &&
          other.capabilities == this.capabilities &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> name;
  final Value<String?> make;
  final Value<String?> model;
  final Value<int?> year;
  final Value<String?> licensePlate;
  final Value<String?> color;
  final Value<String?> photoUrl;
  final Value<String?> notes;
  final Value<String> capabilities;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.licensePlate = const Value.absent(),
    this.color = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.notes = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    required String spaceId,
    required String name,
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.licensePlate = const Value.absent(),
    this.color = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.notes = const Value.absent(),
    required String capabilities,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       name = Value(name),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Vehicle> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? name,
    Expression<String>? make,
    Expression<String>? model,
    Expression<int>? year,
    Expression<String>? licensePlate,
    Expression<String>? color,
    Expression<String>? photoUrl,
    Expression<String>? notes,
    Expression<String>? capabilities,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (name != null) 'name': name,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (licensePlate != null) 'license_plate': licensePlate,
      if (color != null) 'color': color,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (notes != null) 'notes': notes,
      if (capabilities != null) 'capabilities': capabilities,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? name,
    Value<String?>? make,
    Value<String?>? model,
    Value<int?>? year,
    Value<String?>? licensePlate,
    Value<String?>? color,
    Value<String?>? photoUrl,
    Value<String?>? notes,
    Value<String>? capabilities,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      licensePlate: licensePlate ?? this.licensePlate,
      color: color ?? this.color,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      capabilities: capabilities ?? this.capabilities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (licensePlate.present) {
      map['license_plate'] = Variable<String>(licensePlate.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('name: $name, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('color: $color, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('notes: $notes, ')
          ..write('capabilities: $capabilities, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehicleLogsTable extends VehicleLogs
    with TableInfo<$VehicleLogsTable, VehicleLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverMemberIdMeta = const VerificationMeta(
    'driverMemberId',
  );
  @override
  late final GeneratedColumn<String> driverMemberId = GeneratedColumn<String>(
    'driver_member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerMeta = const VerificationMeta(
    'odometer',
  );
  @override
  late final GeneratedColumn<int> odometer = GeneratedColumn<int>(
    'odometer',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelLevelMeta = const VerificationMeta(
    'fuelLevel',
  );
  @override
  late final GeneratedColumn<String> fuelLevel = GeneratedColumn<String>(
    'fuel_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
    'items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyDamageNotesMeta = const VerificationMeta(
    'bodyDamageNotes',
  );
  @override
  late final GeneratedColumn<String> bodyDamageNotes = GeneratedColumn<String>(
    'body_damage_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    vehicleId,
    kind,
    driverMemberId,
    odometer,
    fuelLevel,
    items,
    notes,
    bodyDamageNotes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicle_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('driver_member_id')) {
      context.handle(
        _driverMemberIdMeta,
        driverMemberId.isAcceptableOrUnknown(
          data['driver_member_id']!,
          _driverMemberIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_driverMemberIdMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(
        _odometerMeta,
        odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta),
      );
    }
    if (data.containsKey('fuel_level')) {
      context.handle(
        _fuelLevelMeta,
        fuelLevel.isAcceptableOrUnknown(data['fuel_level']!, _fuelLevelMeta),
      );
    }
    if (data.containsKey('items')) {
      context.handle(
        _itemsMeta,
        items.isAcceptableOrUnknown(data['items']!, _itemsMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('body_damage_notes')) {
      context.handle(
        _bodyDamageNotesMeta,
        bodyDamageNotes.isAcceptableOrUnknown(
          data['body_damage_notes']!,
          _bodyDamageNotesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      driverMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver_member_id'],
      )!,
      odometer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odometer'],
      ),
      fuelLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuel_level'],
      ),
      items: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      bodyDamageNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_damage_notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VehicleLogsTable createAlias(String alias) {
    return $VehicleLogsTable(attachedDatabase, alias);
  }
}

class VehicleLog extends DataClass implements Insertable<VehicleLog> {
  final String id;
  final String spaceId;
  final String vehicleId;
  final String kind;
  final String driverMemberId;
  final int? odometer;
  final String? fuelLevel;
  final String items;
  final String? notes;
  final String? bodyDamageNotes;
  final String createdAt;
  const VehicleLog({
    required this.id,
    required this.spaceId,
    required this.vehicleId,
    required this.kind,
    required this.driverMemberId,
    this.odometer,
    this.fuelLevel,
    required this.items,
    this.notes,
    this.bodyDamageNotes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['kind'] = Variable<String>(kind);
    map['driver_member_id'] = Variable<String>(driverMemberId);
    if (!nullToAbsent || odometer != null) {
      map['odometer'] = Variable<int>(odometer);
    }
    if (!nullToAbsent || fuelLevel != null) {
      map['fuel_level'] = Variable<String>(fuelLevel);
    }
    map['items'] = Variable<String>(items);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || bodyDamageNotes != null) {
      map['body_damage_notes'] = Variable<String>(bodyDamageNotes);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  VehicleLogsCompanion toCompanion(bool nullToAbsent) {
    return VehicleLogsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      vehicleId: Value(vehicleId),
      kind: Value(kind),
      driverMemberId: Value(driverMemberId),
      odometer: odometer == null && nullToAbsent
          ? const Value.absent()
          : Value(odometer),
      fuelLevel: fuelLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelLevel),
      items: Value(items),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      bodyDamageNotes: bodyDamageNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyDamageNotes),
      createdAt: Value(createdAt),
    );
  }

  factory VehicleLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleLog(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      kind: serializer.fromJson<String>(json['kind']),
      driverMemberId: serializer.fromJson<String>(json['driverMemberId']),
      odometer: serializer.fromJson<int?>(json['odometer']),
      fuelLevel: serializer.fromJson<String?>(json['fuelLevel']),
      items: serializer.fromJson<String>(json['items']),
      notes: serializer.fromJson<String?>(json['notes']),
      bodyDamageNotes: serializer.fromJson<String?>(json['bodyDamageNotes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'kind': serializer.toJson<String>(kind),
      'driverMemberId': serializer.toJson<String>(driverMemberId),
      'odometer': serializer.toJson<int?>(odometer),
      'fuelLevel': serializer.toJson<String?>(fuelLevel),
      'items': serializer.toJson<String>(items),
      'notes': serializer.toJson<String?>(notes),
      'bodyDamageNotes': serializer.toJson<String?>(bodyDamageNotes),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  VehicleLog copyWith({
    String? id,
    String? spaceId,
    String? vehicleId,
    String? kind,
    String? driverMemberId,
    Value<int?> odometer = const Value.absent(),
    Value<String?> fuelLevel = const Value.absent(),
    String? items,
    Value<String?> notes = const Value.absent(),
    Value<String?> bodyDamageNotes = const Value.absent(),
    String? createdAt,
  }) => VehicleLog(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    vehicleId: vehicleId ?? this.vehicleId,
    kind: kind ?? this.kind,
    driverMemberId: driverMemberId ?? this.driverMemberId,
    odometer: odometer.present ? odometer.value : this.odometer,
    fuelLevel: fuelLevel.present ? fuelLevel.value : this.fuelLevel,
    items: items ?? this.items,
    notes: notes.present ? notes.value : this.notes,
    bodyDamageNotes: bodyDamageNotes.present
        ? bodyDamageNotes.value
        : this.bodyDamageNotes,
    createdAt: createdAt ?? this.createdAt,
  );
  VehicleLog copyWithCompanion(VehicleLogsCompanion data) {
    return VehicleLog(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      kind: data.kind.present ? data.kind.value : this.kind,
      driverMemberId: data.driverMemberId.present
          ? data.driverMemberId.value
          : this.driverMemberId,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      fuelLevel: data.fuelLevel.present ? data.fuelLevel.value : this.fuelLevel,
      items: data.items.present ? data.items.value : this.items,
      notes: data.notes.present ? data.notes.value : this.notes,
      bodyDamageNotes: data.bodyDamageNotes.present
          ? data.bodyDamageNotes.value
          : this.bodyDamageNotes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleLog(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('kind: $kind, ')
          ..write('driverMemberId: $driverMemberId, ')
          ..write('odometer: $odometer, ')
          ..write('fuelLevel: $fuelLevel, ')
          ..write('items: $items, ')
          ..write('notes: $notes, ')
          ..write('bodyDamageNotes: $bodyDamageNotes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    vehicleId,
    kind,
    driverMemberId,
    odometer,
    fuelLevel,
    items,
    notes,
    bodyDamageNotes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleLog &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.vehicleId == this.vehicleId &&
          other.kind == this.kind &&
          other.driverMemberId == this.driverMemberId &&
          other.odometer == this.odometer &&
          other.fuelLevel == this.fuelLevel &&
          other.items == this.items &&
          other.notes == this.notes &&
          other.bodyDamageNotes == this.bodyDamageNotes &&
          other.createdAt == this.createdAt);
}

class VehicleLogsCompanion extends UpdateCompanion<VehicleLog> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> vehicleId;
  final Value<String> kind;
  final Value<String> driverMemberId;
  final Value<int?> odometer;
  final Value<String?> fuelLevel;
  final Value<String> items;
  final Value<String?> notes;
  final Value<String?> bodyDamageNotes;
  final Value<String> createdAt;
  final Value<int> rowid;
  const VehicleLogsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.kind = const Value.absent(),
    this.driverMemberId = const Value.absent(),
    this.odometer = const Value.absent(),
    this.fuelLevel = const Value.absent(),
    this.items = const Value.absent(),
    this.notes = const Value.absent(),
    this.bodyDamageNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleLogsCompanion.insert({
    required String id,
    required String spaceId,
    required String vehicleId,
    required String kind,
    required String driverMemberId,
    this.odometer = const Value.absent(),
    this.fuelLevel = const Value.absent(),
    required String items,
    this.notes = const Value.absent(),
    this.bodyDamageNotes = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       vehicleId = Value(vehicleId),
       kind = Value(kind),
       driverMemberId = Value(driverMemberId),
       items = Value(items),
       createdAt = Value(createdAt);
  static Insertable<VehicleLog> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? vehicleId,
    Expression<String>? kind,
    Expression<String>? driverMemberId,
    Expression<int>? odometer,
    Expression<String>? fuelLevel,
    Expression<String>? items,
    Expression<String>? notes,
    Expression<String>? bodyDamageNotes,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (kind != null) 'kind': kind,
      if (driverMemberId != null) 'driver_member_id': driverMemberId,
      if (odometer != null) 'odometer': odometer,
      if (fuelLevel != null) 'fuel_level': fuelLevel,
      if (items != null) 'items': items,
      if (notes != null) 'notes': notes,
      if (bodyDamageNotes != null) 'body_damage_notes': bodyDamageNotes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? vehicleId,
    Value<String>? kind,
    Value<String>? driverMemberId,
    Value<int?>? odometer,
    Value<String?>? fuelLevel,
    Value<String>? items,
    Value<String?>? notes,
    Value<String?>? bodyDamageNotes,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return VehicleLogsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      vehicleId: vehicleId ?? this.vehicleId,
      kind: kind ?? this.kind,
      driverMemberId: driverMemberId ?? this.driverMemberId,
      odometer: odometer ?? this.odometer,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      bodyDamageNotes: bodyDamageNotes ?? this.bodyDamageNotes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (driverMemberId.present) {
      map['driver_member_id'] = Variable<String>(driverMemberId.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<int>(odometer.value);
    }
    if (fuelLevel.present) {
      map['fuel_level'] = Variable<String>(fuelLevel.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (bodyDamageNotes.present) {
      map['body_damage_notes'] = Variable<String>(bodyDamageNotes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehicleLogsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('kind: $kind, ')
          ..write('driverMemberId: $driverMemberId, ')
          ..write('odometer: $odometer, ')
          ..write('fuelLevel: $fuelLevel, ')
          ..write('items: $items, ')
          ..write('notes: $notes, ')
          ..write('bodyDamageNotes: $bodyDamageNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemberCertificationsTable extends MemberCertifications
    with TableInfo<$MemberCertificationsTable, MemberCertification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemberCertificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _certKeyMeta = const VerificationMeta(
    'certKey',
  );
  @override
  late final GeneratedColumn<String> certKey = GeneratedColumn<String>(
    'cert_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issuedAtMeta = const VerificationMeta(
    'issuedAt',
  );
  @override
  late final GeneratedColumn<String> issuedAt = GeneratedColumn<String>(
    'issued_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<String> expiresAt = GeneratedColumn<String>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentUrlMeta = const VerificationMeta(
    'documentUrl',
  );
  @override
  late final GeneratedColumn<String> documentUrl = GeneratedColumn<String>(
    'document_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    memberId,
    certKey,
    issuedAt,
    expiresAt,
    notes,
    documentUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'member_certifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemberCertification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('cert_key')) {
      context.handle(
        _certKeyMeta,
        certKey.isAcceptableOrUnknown(data['cert_key']!, _certKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_certKeyMeta);
    }
    if (data.containsKey('issued_at')) {
      context.handle(
        _issuedAtMeta,
        issuedAt.isAcceptableOrUnknown(data['issued_at']!, _issuedAtMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('document_url')) {
      context.handle(
        _documentUrlMeta,
        documentUrl.isAcceptableOrUnknown(
          data['document_url']!,
          _documentUrlMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemberCertification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemberCertification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      certKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cert_key'],
      )!,
      issuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issued_at'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expires_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      documentUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MemberCertificationsTable createAlias(String alias) {
    return $MemberCertificationsTable(attachedDatabase, alias);
  }
}

class MemberCertification extends DataClass
    implements Insertable<MemberCertification> {
  final String id;
  final String spaceId;
  final String memberId;
  final String certKey;
  final String? issuedAt;
  final String? expiresAt;
  final String? notes;
  final String? documentUrl;
  final String createdAt;
  final String updatedAt;
  const MemberCertification({
    required this.id,
    required this.spaceId,
    required this.memberId,
    required this.certKey,
    this.issuedAt,
    this.expiresAt,
    this.notes,
    this.documentUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['member_id'] = Variable<String>(memberId);
    map['cert_key'] = Variable<String>(certKey);
    if (!nullToAbsent || issuedAt != null) {
      map['issued_at'] = Variable<String>(issuedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<String>(expiresAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || documentUrl != null) {
      map['document_url'] = Variable<String>(documentUrl);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  MemberCertificationsCompanion toCompanion(bool nullToAbsent) {
    return MemberCertificationsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      memberId: Value(memberId),
      certKey: Value(certKey),
      issuedAt: issuedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(issuedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      documentUrl: documentUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(documentUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MemberCertification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemberCertification(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      memberId: serializer.fromJson<String>(json['memberId']),
      certKey: serializer.fromJson<String>(json['certKey']),
      issuedAt: serializer.fromJson<String?>(json['issuedAt']),
      expiresAt: serializer.fromJson<String?>(json['expiresAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      documentUrl: serializer.fromJson<String?>(json['documentUrl']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'memberId': serializer.toJson<String>(memberId),
      'certKey': serializer.toJson<String>(certKey),
      'issuedAt': serializer.toJson<String?>(issuedAt),
      'expiresAt': serializer.toJson<String?>(expiresAt),
      'notes': serializer.toJson<String?>(notes),
      'documentUrl': serializer.toJson<String?>(documentUrl),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  MemberCertification copyWith({
    String? id,
    String? spaceId,
    String? memberId,
    String? certKey,
    Value<String?> issuedAt = const Value.absent(),
    Value<String?> expiresAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> documentUrl = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => MemberCertification(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    memberId: memberId ?? this.memberId,
    certKey: certKey ?? this.certKey,
    issuedAt: issuedAt.present ? issuedAt.value : this.issuedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    notes: notes.present ? notes.value : this.notes,
    documentUrl: documentUrl.present ? documentUrl.value : this.documentUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MemberCertification copyWithCompanion(MemberCertificationsCompanion data) {
    return MemberCertification(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      certKey: data.certKey.present ? data.certKey.value : this.certKey,
      issuedAt: data.issuedAt.present ? data.issuedAt.value : this.issuedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      documentUrl: data.documentUrl.present
          ? data.documentUrl.value
          : this.documentUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemberCertification(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('memberId: $memberId, ')
          ..write('certKey: $certKey, ')
          ..write('issuedAt: $issuedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('notes: $notes, ')
          ..write('documentUrl: $documentUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    memberId,
    certKey,
    issuedAt,
    expiresAt,
    notes,
    documentUrl,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemberCertification &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.memberId == this.memberId &&
          other.certKey == this.certKey &&
          other.issuedAt == this.issuedAt &&
          other.expiresAt == this.expiresAt &&
          other.notes == this.notes &&
          other.documentUrl == this.documentUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MemberCertificationsCompanion
    extends UpdateCompanion<MemberCertification> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> memberId;
  final Value<String> certKey;
  final Value<String?> issuedAt;
  final Value<String?> expiresAt;
  final Value<String?> notes;
  final Value<String?> documentUrl;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const MemberCertificationsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.certKey = const Value.absent(),
    this.issuedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.documentUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemberCertificationsCompanion.insert({
    required String id,
    required String spaceId,
    required String memberId,
    required String certKey,
    this.issuedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.documentUrl = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       memberId = Value(memberId),
       certKey = Value(certKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemberCertification> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? memberId,
    Expression<String>? certKey,
    Expression<String>? issuedAt,
    Expression<String>? expiresAt,
    Expression<String>? notes,
    Expression<String>? documentUrl,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (memberId != null) 'member_id': memberId,
      if (certKey != null) 'cert_key': certKey,
      if (issuedAt != null) 'issued_at': issuedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (notes != null) 'notes': notes,
      if (documentUrl != null) 'document_url': documentUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemberCertificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? memberId,
    Value<String>? certKey,
    Value<String?>? issuedAt,
    Value<String?>? expiresAt,
    Value<String?>? notes,
    Value<String?>? documentUrl,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return MemberCertificationsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      memberId: memberId ?? this.memberId,
      certKey: certKey ?? this.certKey,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      notes: notes ?? this.notes,
      documentUrl: documentUrl ?? this.documentUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (certKey.present) {
      map['cert_key'] = Variable<String>(certKey.value);
    }
    if (issuedAt.present) {
      map['issued_at'] = Variable<String>(issuedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<String>(expiresAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (documentUrl.present) {
      map['document_url'] = Variable<String>(documentUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemberCertificationsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('memberId: $memberId, ')
          ..write('certKey: $certKey, ')
          ..write('issuedAt: $issuedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('notes: $notes, ')
          ..write('documentUrl: $documentUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityKindMeta = const VerificationMeta(
    'entityKind',
  );
  @override
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
    'entity_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedByMeta = const VerificationMeta(
    'uploadedBy',
  );
  @override
  late final GeneratedColumn<String> uploadedBy = GeneratedColumn<String>(
    'uploaded_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<String> takenAt = GeneratedColumn<String>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    entityKind,
    entityId,
    url,
    thumbUrl,
    mimeType,
    caption,
    sortOrder,
    uploadedBy,
    takenAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('entity_kind')) {
      context.handle(
        _entityKindMeta,
        entityKind.isAcceptableOrUnknown(data['entity_kind']!, _entityKindMeta),
      );
    } else if (isInserting) {
      context.missing(_entityKindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('uploaded_by')) {
      context.handle(
        _uploadedByMeta,
        uploadedBy.isAcceptableOrUnknown(data['uploaded_by']!, _uploadedByMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      entityKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      uploadedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uploaded_by'],
      ),
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}taken_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String spaceId;
  final String entityKind;
  final String entityId;
  final String url;
  final String? thumbUrl;
  final String mimeType;
  final String? caption;
  final int? sortOrder;
  final String? uploadedBy;
  final String? takenAt;
  final String createdAt;
  final String updatedAt;
  const Attachment({
    required this.id,
    required this.spaceId,
    required this.entityKind,
    required this.entityId,
    required this.url,
    this.thumbUrl,
    required this.mimeType,
    this.caption,
    this.sortOrder,
    this.uploadedBy,
    this.takenAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['entity_kind'] = Variable<String>(entityKind);
    map['entity_id'] = Variable<String>(entityId);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    if (!nullToAbsent || uploadedBy != null) {
      map['uploaded_by'] = Variable<String>(uploadedBy);
    }
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<String>(takenAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      entityKind: Value(entityKind),
      entityId: Value(entityId),
      url: Value(url),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      mimeType: Value(mimeType),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      uploadedBy: uploadedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedBy),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      entityKind: serializer.fromJson<String>(json['entityKind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      url: serializer.fromJson<String>(json['url']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      caption: serializer.fromJson<String?>(json['caption']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      uploadedBy: serializer.fromJson<String?>(json['uploadedBy']),
      takenAt: serializer.fromJson<String?>(json['takenAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'entityKind': serializer.toJson<String>(entityKind),
      'entityId': serializer.toJson<String>(entityId),
      'url': serializer.toJson<String>(url),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'mimeType': serializer.toJson<String>(mimeType),
      'caption': serializer.toJson<String?>(caption),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'uploadedBy': serializer.toJson<String?>(uploadedBy),
      'takenAt': serializer.toJson<String?>(takenAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Attachment copyWith({
    String? id,
    String? spaceId,
    String? entityKind,
    String? entityId,
    String? url,
    Value<String?> thumbUrl = const Value.absent(),
    String? mimeType,
    Value<String?> caption = const Value.absent(),
    Value<int?> sortOrder = const Value.absent(),
    Value<String?> uploadedBy = const Value.absent(),
    Value<String?> takenAt = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Attachment(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    entityKind: entityKind ?? this.entityKind,
    entityId: entityId ?? this.entityId,
    url: url ?? this.url,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    mimeType: mimeType ?? this.mimeType,
    caption: caption.present ? caption.value : this.caption,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    uploadedBy: uploadedBy.present ? uploadedBy.value : this.uploadedBy,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      entityKind: data.entityKind.present
          ? data.entityKind.value
          : this.entityKind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      url: data.url.present ? data.url.value : this.url,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      caption: data.caption.present ? data.caption.value : this.caption,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      uploadedBy: data.uploadedBy.present
          ? data.uploadedBy.value
          : this.uploadedBy,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('url: $url, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('caption: $caption, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('uploadedBy: $uploadedBy, ')
          ..write('takenAt: $takenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    entityKind,
    entityId,
    url,
    thumbUrl,
    mimeType,
    caption,
    sortOrder,
    uploadedBy,
    takenAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.entityKind == this.entityKind &&
          other.entityId == this.entityId &&
          other.url == this.url &&
          other.thumbUrl == this.thumbUrl &&
          other.mimeType == this.mimeType &&
          other.caption == this.caption &&
          other.sortOrder == this.sortOrder &&
          other.uploadedBy == this.uploadedBy &&
          other.takenAt == this.takenAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> entityKind;
  final Value<String> entityId;
  final Value<String> url;
  final Value<String?> thumbUrl;
  final Value<String> mimeType;
  final Value<String?> caption;
  final Value<int?> sortOrder;
  final Value<String?> uploadedBy;
  final Value<String?> takenAt;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.url = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.caption = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.uploadedBy = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String spaceId,
    required String entityKind,
    required String entityId,
    required String url,
    this.thumbUrl = const Value.absent(),
    required String mimeType,
    this.caption = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.uploadedBy = const Value.absent(),
    this.takenAt = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       entityKind = Value(entityKind),
       entityId = Value(entityId),
       url = Value(url),
       mimeType = Value(mimeType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? entityKind,
    Expression<String>? entityId,
    Expression<String>? url,
    Expression<String>? thumbUrl,
    Expression<String>? mimeType,
    Expression<String>? caption,
    Expression<int>? sortOrder,
    Expression<String>? uploadedBy,
    Expression<String>? takenAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (entityKind != null) 'entity_kind': entityKind,
      if (entityId != null) 'entity_id': entityId,
      if (url != null) 'url': url,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (caption != null) 'caption': caption,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (uploadedBy != null) 'uploaded_by': uploadedBy,
      if (takenAt != null) 'taken_at': takenAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? entityKind,
    Value<String>? entityId,
    Value<String>? url,
    Value<String?>? thumbUrl,
    Value<String>? mimeType,
    Value<String?>? caption,
    Value<int?>? sortOrder,
    Value<String?>? uploadedBy,
    Value<String?>? takenAt,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      entityKind: entityKind ?? this.entityKind,
      entityId: entityId ?? this.entityId,
      url: url ?? this.url,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      mimeType: mimeType ?? this.mimeType,
      caption: caption ?? this.caption,
      sortOrder: sortOrder ?? this.sortOrder,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      takenAt: takenAt ?? this.takenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (uploadedBy.present) {
      map['uploaded_by'] = Variable<String>(uploadedBy.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<String>(takenAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('entityKind: $entityKind, ')
          ..write('entityId: $entityId, ')
          ..write('url: $url, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('caption: $caption, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('uploadedBy: $uploadedBy, ')
          ..write('takenAt: $takenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SurveyResponsesTable extends SurveyResponses
    with TableInfo<$SurveyResponsesTable, SurveyResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveyResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedByMeta = const VerificationMeta(
    'recordedBy',
  );
  @override
  late final GeneratedColumn<String> recordedBy = GeneratedColumn<String>(
    'recorded_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answersMeta = const VerificationMeta(
    'answers',
  );
  @override
  late final GeneratedColumn<String> answers = GeneratedColumn<String>(
    'answers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    templateId,
    subjectId,
    status,
    recordedBy,
    answers,
    startedAt,
    completedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'survey_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<SurveyResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('recorded_by')) {
      context.handle(
        _recordedByMeta,
        recordedBy.isAcceptableOrUnknown(data['recorded_by']!, _recordedByMeta),
      );
    }
    if (data.containsKey('answers')) {
      context.handle(
        _answersMeta,
        answers.isAcceptableOrUnknown(data['answers']!, _answersMeta),
      );
    } else if (isInserting) {
      context.missing(_answersMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SurveyResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurveyResponse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      recordedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recorded_by'],
      ),
      answers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SurveyResponsesTable createAlias(String alias) {
    return $SurveyResponsesTable(attachedDatabase, alias);
  }
}

class SurveyResponse extends DataClass implements Insertable<SurveyResponse> {
  final String id;
  final String spaceId;
  final String templateId;
  final String subjectId;
  final String status;
  final String? recordedBy;
  final String answers;
  final String startedAt;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;
  const SurveyResponse({
    required this.id,
    required this.spaceId,
    required this.templateId,
    required this.subjectId,
    required this.status,
    this.recordedBy,
    required this.answers,
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['template_id'] = Variable<String>(templateId);
    map['subject_id'] = Variable<String>(subjectId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || recordedBy != null) {
      map['recorded_by'] = Variable<String>(recordedBy);
    }
    map['answers'] = Variable<String>(answers);
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  SurveyResponsesCompanion toCompanion(bool nullToAbsent) {
    return SurveyResponsesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      templateId: Value(templateId),
      subjectId: Value(subjectId),
      status: Value(status),
      recordedBy: recordedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedBy),
      answers: Value(answers),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SurveyResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurveyResponse(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      templateId: serializer.fromJson<String>(json['templateId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      status: serializer.fromJson<String>(json['status']),
      recordedBy: serializer.fromJson<String?>(json['recordedBy']),
      answers: serializer.fromJson<String>(json['answers']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'templateId': serializer.toJson<String>(templateId),
      'subjectId': serializer.toJson<String>(subjectId),
      'status': serializer.toJson<String>(status),
      'recordedBy': serializer.toJson<String?>(recordedBy),
      'answers': serializer.toJson<String>(answers),
      'startedAt': serializer.toJson<String>(startedAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  SurveyResponse copyWith({
    String? id,
    String? spaceId,
    String? templateId,
    String? subjectId,
    String? status,
    Value<String?> recordedBy = const Value.absent(),
    String? answers,
    String? startedAt,
    Value<String?> completedAt = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => SurveyResponse(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    templateId: templateId ?? this.templateId,
    subjectId: subjectId ?? this.subjectId,
    status: status ?? this.status,
    recordedBy: recordedBy.present ? recordedBy.value : this.recordedBy,
    answers: answers ?? this.answers,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SurveyResponse copyWithCompanion(SurveyResponsesCompanion data) {
    return SurveyResponse(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      status: data.status.present ? data.status.value : this.status,
      recordedBy: data.recordedBy.present
          ? data.recordedBy.value
          : this.recordedBy,
      answers: data.answers.present ? data.answers.value : this.answers,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurveyResponse(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('templateId: $templateId, ')
          ..write('subjectId: $subjectId, ')
          ..write('status: $status, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('answers: $answers, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    templateId,
    subjectId,
    status,
    recordedBy,
    answers,
    startedAt,
    completedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurveyResponse &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.templateId == this.templateId &&
          other.subjectId == this.subjectId &&
          other.status == this.status &&
          other.recordedBy == this.recordedBy &&
          other.answers == this.answers &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SurveyResponsesCompanion extends UpdateCompanion<SurveyResponse> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> templateId;
  final Value<String> subjectId;
  final Value<String> status;
  final Value<String?> recordedBy;
  final Value<String> answers;
  final Value<String> startedAt;
  final Value<String?> completedAt;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const SurveyResponsesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.status = const Value.absent(),
    this.recordedBy = const Value.absent(),
    this.answers = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveyResponsesCompanion.insert({
    required String id,
    required String spaceId,
    required String templateId,
    required String subjectId,
    required String status,
    this.recordedBy = const Value.absent(),
    required String answers,
    required String startedAt,
    this.completedAt = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       templateId = Value(templateId),
       subjectId = Value(subjectId),
       status = Value(status),
       answers = Value(answers),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SurveyResponse> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? templateId,
    Expression<String>? subjectId,
    Expression<String>? status,
    Expression<String>? recordedBy,
    Expression<String>? answers,
    Expression<String>? startedAt,
    Expression<String>? completedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (templateId != null) 'template_id': templateId,
      if (subjectId != null) 'subject_id': subjectId,
      if (status != null) 'status': status,
      if (recordedBy != null) 'recorded_by': recordedBy,
      if (answers != null) 'answers': answers,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveyResponsesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? templateId,
    Value<String>? subjectId,
    Value<String>? status,
    Value<String?>? recordedBy,
    Value<String>? answers,
    Value<String>? startedAt,
    Value<String?>? completedAt,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return SurveyResponsesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      templateId: templateId ?? this.templateId,
      subjectId: subjectId ?? this.subjectId,
      status: status ?? this.status,
      recordedBy: recordedBy ?? this.recordedBy,
      answers: answers ?? this.answers,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (recordedBy.present) {
      map['recorded_by'] = Variable<String>(recordedBy.value);
    }
    if (answers.present) {
      map['answers'] = Variable<String>(answers.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurveyResponsesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('templateId: $templateId, ')
          ..write('subjectId: $subjectId, ')
          ..write('status: $status, ')
          ..write('recordedBy: $recordedBy, ')
          ..write('answers: $answers, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DismissedInsightsTable extends DismissedInsights
    with TableInfo<$DismissedInsightsTable, DismissedInsight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DismissedInsightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _insightIdMeta = const VerificationMeta(
    'insightId',
  );
  @override
  late final GeneratedColumn<String> insightId = GeneratedColumn<String>(
    'insight_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedUntilMeta = const VerificationMeta(
    'dismissedUntil',
  );
  @override
  late final GeneratedColumn<String> dismissedUntil = GeneratedColumn<String>(
    'dismissed_until',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    memberId,
    insightId,
    dismissedUntil,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dismissed_insights';
  @override
  VerificationContext validateIntegrity(
    Insertable<DismissedInsight> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('insight_id')) {
      context.handle(
        _insightIdMeta,
        insightId.isAcceptableOrUnknown(data['insight_id']!, _insightIdMeta),
      );
    } else if (isInserting) {
      context.missing(_insightIdMeta);
    }
    if (data.containsKey('dismissed_until')) {
      context.handle(
        _dismissedUntilMeta,
        dismissedUntil.isAcceptableOrUnknown(
          data['dismissed_until']!,
          _dismissedUntilMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DismissedInsight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DismissedInsight(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      insightId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insight_id'],
      )!,
      dismissedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dismissed_until'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DismissedInsightsTable createAlias(String alias) {
    return $DismissedInsightsTable(attachedDatabase, alias);
  }
}

class DismissedInsight extends DataClass
    implements Insertable<DismissedInsight> {
  final String id;
  final String spaceId;
  final String memberId;
  final String insightId;
  final String? dismissedUntil;
  final String createdAt;
  const DismissedInsight({
    required this.id,
    required this.spaceId,
    required this.memberId,
    required this.insightId,
    this.dismissedUntil,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['member_id'] = Variable<String>(memberId);
    map['insight_id'] = Variable<String>(insightId);
    if (!nullToAbsent || dismissedUntil != null) {
      map['dismissed_until'] = Variable<String>(dismissedUntil);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  DismissedInsightsCompanion toCompanion(bool nullToAbsent) {
    return DismissedInsightsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      memberId: Value(memberId),
      insightId: Value(insightId),
      dismissedUntil: dismissedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedUntil),
      createdAt: Value(createdAt),
    );
  }

  factory DismissedInsight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DismissedInsight(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      memberId: serializer.fromJson<String>(json['memberId']),
      insightId: serializer.fromJson<String>(json['insightId']),
      dismissedUntil: serializer.fromJson<String?>(json['dismissedUntil']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'memberId': serializer.toJson<String>(memberId),
      'insightId': serializer.toJson<String>(insightId),
      'dismissedUntil': serializer.toJson<String?>(dismissedUntil),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  DismissedInsight copyWith({
    String? id,
    String? spaceId,
    String? memberId,
    String? insightId,
    Value<String?> dismissedUntil = const Value.absent(),
    String? createdAt,
  }) => DismissedInsight(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    memberId: memberId ?? this.memberId,
    insightId: insightId ?? this.insightId,
    dismissedUntil: dismissedUntil.present
        ? dismissedUntil.value
        : this.dismissedUntil,
    createdAt: createdAt ?? this.createdAt,
  );
  DismissedInsight copyWithCompanion(DismissedInsightsCompanion data) {
    return DismissedInsight(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      insightId: data.insightId.present ? data.insightId.value : this.insightId,
      dismissedUntil: data.dismissedUntil.present
          ? data.dismissedUntil.value
          : this.dismissedUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DismissedInsight(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('memberId: $memberId, ')
          ..write('insightId: $insightId, ')
          ..write('dismissedUntil: $dismissedUntil, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, spaceId, memberId, insightId, dismissedUntil, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DismissedInsight &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.memberId == this.memberId &&
          other.insightId == this.insightId &&
          other.dismissedUntil == this.dismissedUntil &&
          other.createdAt == this.createdAt);
}

class DismissedInsightsCompanion extends UpdateCompanion<DismissedInsight> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> memberId;
  final Value<String> insightId;
  final Value<String?> dismissedUntil;
  final Value<String> createdAt;
  final Value<int> rowid;
  const DismissedInsightsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.insightId = const Value.absent(),
    this.dismissedUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DismissedInsightsCompanion.insert({
    required String id,
    required String spaceId,
    required String memberId,
    required String insightId,
    this.dismissedUntil = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       memberId = Value(memberId),
       insightId = Value(insightId),
       createdAt = Value(createdAt);
  static Insertable<DismissedInsight> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? memberId,
    Expression<String>? insightId,
    Expression<String>? dismissedUntil,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (memberId != null) 'member_id': memberId,
      if (insightId != null) 'insight_id': insightId,
      if (dismissedUntil != null) 'dismissed_until': dismissedUntil,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DismissedInsightsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? memberId,
    Value<String>? insightId,
    Value<String?>? dismissedUntil,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return DismissedInsightsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      memberId: memberId ?? this.memberId,
      insightId: insightId ?? this.insightId,
      dismissedUntil: dismissedUntil ?? this.dismissedUntil,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (insightId.present) {
      map['insight_id'] = Variable<String>(insightId.value);
    }
    if (dismissedUntil.present) {
      map['dismissed_until'] = Variable<String>(dismissedUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DismissedInsightsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('memberId: $memberId, ')
          ..write('insightId: $insightId, ')
          ..write('dismissedUntil: $dismissedUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CapturesTable extends Captures with TableInfo<$CapturesTable, Capture> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promotedToKindMeta = const VerificationMeta(
    'promotedToKind',
  );
  @override
  late final GeneratedColumn<String> promotedToKind = GeneratedColumn<String>(
    'promoted_to_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _promotedToIdMeta = const VerificationMeta(
    'promotedToId',
  );
  @override
  late final GeneratedColumn<String> promotedToId = GeneratedColumn<String>(
    'promoted_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _promotedSubjectIdMeta = const VerificationMeta(
    'promotedSubjectId',
  );
  @override
  late final GeneratedColumn<String> promotedSubjectId =
      GeneratedColumn<String>(
        'promoted_subject_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<String> processedAt = GeneratedColumn<String>(
    'processed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    authorId,
    body,
    status,
    promotedToKind,
    promotedToId,
    promotedSubjectId,
    processedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'captures';
  @override
  VerificationContext validateIntegrity(
    Insertable<Capture> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('promoted_to_kind')) {
      context.handle(
        _promotedToKindMeta,
        promotedToKind.isAcceptableOrUnknown(
          data['promoted_to_kind']!,
          _promotedToKindMeta,
        ),
      );
    }
    if (data.containsKey('promoted_to_id')) {
      context.handle(
        _promotedToIdMeta,
        promotedToId.isAcceptableOrUnknown(
          data['promoted_to_id']!,
          _promotedToIdMeta,
        ),
      );
    }
    if (data.containsKey('promoted_subject_id')) {
      context.handle(
        _promotedSubjectIdMeta,
        promotedSubjectId.isAcceptableOrUnknown(
          data['promoted_subject_id']!,
          _promotedSubjectIdMeta,
        ),
      );
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Capture map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Capture(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      promotedToKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}promoted_to_kind'],
      ),
      promotedToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}promoted_to_id'],
      ),
      promotedSubjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}promoted_subject_id'],
      ),
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CapturesTable createAlias(String alias) {
    return $CapturesTable(attachedDatabase, alias);
  }
}

class Capture extends DataClass implements Insertable<Capture> {
  final String id;
  final String spaceId;
  final String? authorId;
  final String body;
  final String status;
  final String? promotedToKind;
  final String? promotedToId;
  final String? promotedSubjectId;
  final String? processedAt;
  final String createdAt;
  final String updatedAt;
  const Capture({
    required this.id,
    required this.spaceId,
    this.authorId,
    required this.body,
    required this.status,
    this.promotedToKind,
    this.promotedToId,
    this.promotedSubjectId,
    this.processedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    map['body'] = Variable<String>(body);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || promotedToKind != null) {
      map['promoted_to_kind'] = Variable<String>(promotedToKind);
    }
    if (!nullToAbsent || promotedToId != null) {
      map['promoted_to_id'] = Variable<String>(promotedToId);
    }
    if (!nullToAbsent || promotedSubjectId != null) {
      map['promoted_subject_id'] = Variable<String>(promotedSubjectId);
    }
    if (!nullToAbsent || processedAt != null) {
      map['processed_at'] = Variable<String>(processedAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  CapturesCompanion toCompanion(bool nullToAbsent) {
    return CapturesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      body: Value(body),
      status: Value(status),
      promotedToKind: promotedToKind == null && nullToAbsent
          ? const Value.absent()
          : Value(promotedToKind),
      promotedToId: promotedToId == null && nullToAbsent
          ? const Value.absent()
          : Value(promotedToId),
      promotedSubjectId: promotedSubjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(promotedSubjectId),
      processedAt: processedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Capture.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Capture(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      authorId: serializer.fromJson<String?>(json['authorId']),
      body: serializer.fromJson<String>(json['body']),
      status: serializer.fromJson<String>(json['status']),
      promotedToKind: serializer.fromJson<String?>(json['promotedToKind']),
      promotedToId: serializer.fromJson<String?>(json['promotedToId']),
      promotedSubjectId: serializer.fromJson<String?>(
        json['promotedSubjectId'],
      ),
      processedAt: serializer.fromJson<String?>(json['processedAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'authorId': serializer.toJson<String?>(authorId),
      'body': serializer.toJson<String>(body),
      'status': serializer.toJson<String>(status),
      'promotedToKind': serializer.toJson<String?>(promotedToKind),
      'promotedToId': serializer.toJson<String?>(promotedToId),
      'promotedSubjectId': serializer.toJson<String?>(promotedSubjectId),
      'processedAt': serializer.toJson<String?>(processedAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Capture copyWith({
    String? id,
    String? spaceId,
    Value<String?> authorId = const Value.absent(),
    String? body,
    String? status,
    Value<String?> promotedToKind = const Value.absent(),
    Value<String?> promotedToId = const Value.absent(),
    Value<String?> promotedSubjectId = const Value.absent(),
    Value<String?> processedAt = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Capture(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    authorId: authorId.present ? authorId.value : this.authorId,
    body: body ?? this.body,
    status: status ?? this.status,
    promotedToKind: promotedToKind.present
        ? promotedToKind.value
        : this.promotedToKind,
    promotedToId: promotedToId.present ? promotedToId.value : this.promotedToId,
    promotedSubjectId: promotedSubjectId.present
        ? promotedSubjectId.value
        : this.promotedSubjectId,
    processedAt: processedAt.present ? processedAt.value : this.processedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Capture copyWithCompanion(CapturesCompanion data) {
    return Capture(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      body: data.body.present ? data.body.value : this.body,
      status: data.status.present ? data.status.value : this.status,
      promotedToKind: data.promotedToKind.present
          ? data.promotedToKind.value
          : this.promotedToKind,
      promotedToId: data.promotedToId.present
          ? data.promotedToId.value
          : this.promotedToId,
      promotedSubjectId: data.promotedSubjectId.present
          ? data.promotedSubjectId.value
          : this.promotedSubjectId,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Capture(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('authorId: $authorId, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('promotedToKind: $promotedToKind, ')
          ..write('promotedToId: $promotedToId, ')
          ..write('promotedSubjectId: $promotedSubjectId, ')
          ..write('processedAt: $processedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    authorId,
    body,
    status,
    promotedToKind,
    promotedToId,
    promotedSubjectId,
    processedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Capture &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.authorId == this.authorId &&
          other.body == this.body &&
          other.status == this.status &&
          other.promotedToKind == this.promotedToKind &&
          other.promotedToId == this.promotedToId &&
          other.promotedSubjectId == this.promotedSubjectId &&
          other.processedAt == this.processedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CapturesCompanion extends UpdateCompanion<Capture> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> authorId;
  final Value<String> body;
  final Value<String> status;
  final Value<String?> promotedToKind;
  final Value<String?> promotedToId;
  final Value<String?> promotedSubjectId;
  final Value<String?> processedAt;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const CapturesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.promotedToKind = const Value.absent(),
    this.promotedToId = const Value.absent(),
    this.promotedSubjectId = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CapturesCompanion.insert({
    required String id,
    required String spaceId,
    this.authorId = const Value.absent(),
    required String body,
    required String status,
    this.promotedToKind = const Value.absent(),
    this.promotedToId = const Value.absent(),
    this.promotedSubjectId = const Value.absent(),
    this.processedAt = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       body = Value(body),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Capture> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? authorId,
    Expression<String>? body,
    Expression<String>? status,
    Expression<String>? promotedToKind,
    Expression<String>? promotedToId,
    Expression<String>? promotedSubjectId,
    Expression<String>? processedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (authorId != null) 'author_id': authorId,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (promotedToKind != null) 'promoted_to_kind': promotedToKind,
      if (promotedToId != null) 'promoted_to_id': promotedToId,
      if (promotedSubjectId != null) 'promoted_subject_id': promotedSubjectId,
      if (processedAt != null) 'processed_at': processedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CapturesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? authorId,
    Value<String>? body,
    Value<String>? status,
    Value<String?>? promotedToKind,
    Value<String?>? promotedToId,
    Value<String?>? promotedSubjectId,
    Value<String?>? processedAt,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return CapturesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      authorId: authorId ?? this.authorId,
      body: body ?? this.body,
      status: status ?? this.status,
      promotedToKind: promotedToKind ?? this.promotedToKind,
      promotedToId: promotedToId ?? this.promotedToId,
      promotedSubjectId: promotedSubjectId ?? this.promotedSubjectId,
      processedAt: processedAt ?? this.processedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (promotedToKind.present) {
      map['promoted_to_kind'] = Variable<String>(promotedToKind.value);
    }
    if (promotedToId.present) {
      map['promoted_to_id'] = Variable<String>(promotedToId.value);
    }
    if (promotedSubjectId.present) {
      map['promoted_subject_id'] = Variable<String>(promotedSubjectId.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<String>(processedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapturesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('authorId: $authorId, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('promotedToKind: $promotedToKind, ')
          ..write('promotedToId: $promotedToId, ')
          ..write('promotedSubjectId: $promotedSubjectId, ')
          ..write('processedAt: $processedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<String> dueAt = GeneratedColumn<String>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedByMeta = const VerificationMeta(
    'completedBy',
  );
  @override
  late final GeneratedColumn<String> completedBy = GeneratedColumn<String>(
    'completed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdFromCaptureIdMeta =
      const VerificationMeta('createdFromCaptureId');
  @override
  late final GeneratedColumn<String> createdFromCaptureId =
      GeneratedColumn<String>(
        'created_from_capture_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    authorId,
    subjectId,
    body,
    status,
    dueAt,
    completedBy,
    completedAt,
    createdFromCaptureId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('completed_by')) {
      context.handle(
        _completedByMeta,
        completedBy.isAcceptableOrUnknown(
          data['completed_by']!,
          _completedByMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_from_capture_id')) {
      context.handle(
        _createdFromCaptureIdMeta,
        createdFromCaptureId.isAcceptableOrUnknown(
          data['created_from_capture_id']!,
          _createdFromCaptureIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_at'],
      ),
      completedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_by'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      createdFromCaptureId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_from_capture_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String spaceId;
  final String? authorId;
  final String? subjectId;
  final String body;
  final String status;
  final String? dueAt;
  final String? completedBy;
  final String? completedAt;
  final String? createdFromCaptureId;
  final String createdAt;
  final String updatedAt;
  const Task({
    required this.id,
    required this.spaceId,
    this.authorId,
    this.subjectId,
    required this.body,
    required this.status,
    this.dueAt,
    this.completedBy,
    this.completedAt,
    this.createdFromCaptureId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    map['body'] = Variable<String>(body);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<String>(dueAt);
    }
    if (!nullToAbsent || completedBy != null) {
      map['completed_by'] = Variable<String>(completedBy);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || createdFromCaptureId != null) {
      map['created_from_capture_id'] = Variable<String>(createdFromCaptureId);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      body: Value(body),
      status: Value(status),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      completedBy: completedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(completedBy),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdFromCaptureId: createdFromCaptureId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdFromCaptureId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      authorId: serializer.fromJson<String?>(json['authorId']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      body: serializer.fromJson<String>(json['body']),
      status: serializer.fromJson<String>(json['status']),
      dueAt: serializer.fromJson<String?>(json['dueAt']),
      completedBy: serializer.fromJson<String?>(json['completedBy']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      createdFromCaptureId: serializer.fromJson<String?>(
        json['createdFromCaptureId'],
      ),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'authorId': serializer.toJson<String?>(authorId),
      'subjectId': serializer.toJson<String?>(subjectId),
      'body': serializer.toJson<String>(body),
      'status': serializer.toJson<String>(status),
      'dueAt': serializer.toJson<String?>(dueAt),
      'completedBy': serializer.toJson<String?>(completedBy),
      'completedAt': serializer.toJson<String?>(completedAt),
      'createdFromCaptureId': serializer.toJson<String?>(createdFromCaptureId),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Task copyWith({
    String? id,
    String? spaceId,
    Value<String?> authorId = const Value.absent(),
    Value<String?> subjectId = const Value.absent(),
    String? body,
    String? status,
    Value<String?> dueAt = const Value.absent(),
    Value<String?> completedBy = const Value.absent(),
    Value<String?> completedAt = const Value.absent(),
    Value<String?> createdFromCaptureId = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Task(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    authorId: authorId.present ? authorId.value : this.authorId,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    body: body ?? this.body,
    status: status ?? this.status,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    completedBy: completedBy.present ? completedBy.value : this.completedBy,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdFromCaptureId: createdFromCaptureId.present
        ? createdFromCaptureId.value
        : this.createdFromCaptureId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      body: data.body.present ? data.body.value : this.body,
      status: data.status.present ? data.status.value : this.status,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      completedBy: data.completedBy.present
          ? data.completedBy.value
          : this.completedBy,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdFromCaptureId: data.createdFromCaptureId.present
          ? data.createdFromCaptureId.value
          : this.createdFromCaptureId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('authorId: $authorId, ')
          ..write('subjectId: $subjectId, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('dueAt: $dueAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdFromCaptureId: $createdFromCaptureId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    authorId,
    subjectId,
    body,
    status,
    dueAt,
    completedBy,
    completedAt,
    createdFromCaptureId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.authorId == this.authorId &&
          other.subjectId == this.subjectId &&
          other.body == this.body &&
          other.status == this.status &&
          other.dueAt == this.dueAt &&
          other.completedBy == this.completedBy &&
          other.completedAt == this.completedAt &&
          other.createdFromCaptureId == this.createdFromCaptureId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> authorId;
  final Value<String?> subjectId;
  final Value<String> body;
  final Value<String> status;
  final Value<String?> dueAt;
  final Value<String?> completedBy;
  final Value<String?> completedAt;
  final Value<String?> createdFromCaptureId;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdFromCaptureId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String spaceId,
    this.authorId = const Value.absent(),
    this.subjectId = const Value.absent(),
    required String body,
    required String status,
    this.dueAt = const Value.absent(),
    this.completedBy = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdFromCaptureId = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       body = Value(body),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? authorId,
    Expression<String>? subjectId,
    Expression<String>? body,
    Expression<String>? status,
    Expression<String>? dueAt,
    Expression<String>? completedBy,
    Expression<String>? completedAt,
    Expression<String>? createdFromCaptureId,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (authorId != null) 'author_id': authorId,
      if (subjectId != null) 'subject_id': subjectId,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (dueAt != null) 'due_at': dueAt,
      if (completedBy != null) 'completed_by': completedBy,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdFromCaptureId != null)
        'created_from_capture_id': createdFromCaptureId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? authorId,
    Value<String?>? subjectId,
    Value<String>? body,
    Value<String>? status,
    Value<String?>? dueAt,
    Value<String?>? completedBy,
    Value<String?>? completedAt,
    Value<String?>? createdFromCaptureId,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      authorId: authorId ?? this.authorId,
      subjectId: subjectId ?? this.subjectId,
      body: body ?? this.body,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      createdFromCaptureId: createdFromCaptureId ?? this.createdFromCaptureId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(dueAt.value);
    }
    if (completedBy.present) {
      map['completed_by'] = Variable<String>(completedBy.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (createdFromCaptureId.present) {
      map['created_from_capture_id'] = Variable<String>(
        createdFromCaptureId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('authorId: $authorId, ')
          ..write('subjectId: $subjectId, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('dueAt: $dueAt, ')
          ..write('completedBy: $completedBy, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdFromCaptureId: $createdFromCaptureId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guardianIdMeta = const VerificationMeta(
    'guardianId',
  );
  @override
  late final GeneratedColumn<String> guardianId = GeneratedColumn<String>(
    'guardian_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderKindMeta = const VerificationMeta(
    'senderKind',
  );
  @override
  late final GeneratedColumn<String> senderKind = GeneratedColumn<String>(
    'sender_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMemberIdMeta = const VerificationMeta(
    'senderMemberId',
  );
  @override
  late final GeneratedColumn<String> senderMemberId = GeneratedColumn<String>(
    'sender_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderGuardianIdMeta = const VerificationMeta(
    'senderGuardianId',
  );
  @override
  late final GeneratedColumn<String> senderGuardianId = GeneratedColumn<String>(
    'sender_guardian_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<String> readAt = GeneratedColumn<String>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readByGuardianIdsMeta = const VerificationMeta(
    'readByGuardianIds',
  );
  @override
  late final GeneratedColumn<String> readByGuardianIds =
      GeneratedColumn<String>(
        'read_by_guardian_ids',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    subjectId,
    guardianId,
    senderKind,
    senderMemberId,
    senderGuardianId,
    body,
    readAt,
    readByGuardianIds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('guardian_id')) {
      context.handle(
        _guardianIdMeta,
        guardianId.isAcceptableOrUnknown(data['guardian_id']!, _guardianIdMeta),
      );
    } else if (isInserting) {
      context.missing(_guardianIdMeta);
    }
    if (data.containsKey('sender_kind')) {
      context.handle(
        _senderKindMeta,
        senderKind.isAcceptableOrUnknown(data['sender_kind']!, _senderKindMeta),
      );
    } else if (isInserting) {
      context.missing(_senderKindMeta);
    }
    if (data.containsKey('sender_member_id')) {
      context.handle(
        _senderMemberIdMeta,
        senderMemberId.isAcceptableOrUnknown(
          data['sender_member_id']!,
          _senderMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('sender_guardian_id')) {
      context.handle(
        _senderGuardianIdMeta,
        senderGuardianId.isAcceptableOrUnknown(
          data['sender_guardian_id']!,
          _senderGuardianIdMeta,
        ),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('read_by_guardian_ids')) {
      context.handle(
        _readByGuardianIdsMeta,
        readByGuardianIds.isAcceptableOrUnknown(
          data['read_by_guardian_ids']!,
          _readByGuardianIdsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      guardianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guardian_id'],
      )!,
      senderKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_kind'],
      )!,
      senderMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_member_id'],
      ),
      senderGuardianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_guardian_id'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_at'],
      ),
      readByGuardianIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_by_guardian_ids'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String spaceId;
  final String subjectId;
  final String guardianId;
  final String senderKind;
  final String? senderMemberId;
  final String? senderGuardianId;
  final String body;
  final String? readAt;

  /// JSON-array of guardian UUIDs who've read past this message.
  /// Devon-persona: divorced parents share a kid; per-guardian
  /// read-state lets staff see "Seen by Mom only" vs "Seen by both."
  /// Empty string / null is treated as `'[]'` at the reader site.
  ///
  /// Nullable here because the local SQLite schema (PowerSync-managed)
  /// stores it as TEXT NULL — declaring this as non-nullable in Drift
  /// caused row decoding to throw on every read of a message inserted
  /// before the server's default kicked in, which manifested as
  /// "Could not load this thread" after sending a message (Wave 62).
  final String? readByGuardianIds;
  final String createdAt;
  const Message({
    required this.id,
    required this.spaceId,
    required this.subjectId,
    required this.guardianId,
    required this.senderKind,
    this.senderMemberId,
    this.senderGuardianId,
    required this.body,
    this.readAt,
    this.readByGuardianIds,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['subject_id'] = Variable<String>(subjectId);
    map['guardian_id'] = Variable<String>(guardianId);
    map['sender_kind'] = Variable<String>(senderKind);
    if (!nullToAbsent || senderMemberId != null) {
      map['sender_member_id'] = Variable<String>(senderMemberId);
    }
    if (!nullToAbsent || senderGuardianId != null) {
      map['sender_guardian_id'] = Variable<String>(senderGuardianId);
    }
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<String>(readAt);
    }
    if (!nullToAbsent || readByGuardianIds != null) {
      map['read_by_guardian_ids'] = Variable<String>(readByGuardianIds);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      subjectId: Value(subjectId),
      guardianId: Value(guardianId),
      senderKind: Value(senderKind),
      senderMemberId: senderMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderMemberId),
      senderGuardianId: senderGuardianId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderGuardianId),
      body: Value(body),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      readByGuardianIds: readByGuardianIds == null && nullToAbsent
          ? const Value.absent()
          : Value(readByGuardianIds),
      createdAt: Value(createdAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      guardianId: serializer.fromJson<String>(json['guardianId']),
      senderKind: serializer.fromJson<String>(json['senderKind']),
      senderMemberId: serializer.fromJson<String?>(json['senderMemberId']),
      senderGuardianId: serializer.fromJson<String?>(json['senderGuardianId']),
      body: serializer.fromJson<String>(json['body']),
      readAt: serializer.fromJson<String?>(json['readAt']),
      readByGuardianIds: serializer.fromJson<String?>(
        json['readByGuardianIds'],
      ),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'subjectId': serializer.toJson<String>(subjectId),
      'guardianId': serializer.toJson<String>(guardianId),
      'senderKind': serializer.toJson<String>(senderKind),
      'senderMemberId': serializer.toJson<String?>(senderMemberId),
      'senderGuardianId': serializer.toJson<String?>(senderGuardianId),
      'body': serializer.toJson<String>(body),
      'readAt': serializer.toJson<String?>(readAt),
      'readByGuardianIds': serializer.toJson<String?>(readByGuardianIds),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Message copyWith({
    String? id,
    String? spaceId,
    String? subjectId,
    String? guardianId,
    String? senderKind,
    Value<String?> senderMemberId = const Value.absent(),
    Value<String?> senderGuardianId = const Value.absent(),
    String? body,
    Value<String?> readAt = const Value.absent(),
    Value<String?> readByGuardianIds = const Value.absent(),
    String? createdAt,
  }) => Message(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    subjectId: subjectId ?? this.subjectId,
    guardianId: guardianId ?? this.guardianId,
    senderKind: senderKind ?? this.senderKind,
    senderMemberId: senderMemberId.present
        ? senderMemberId.value
        : this.senderMemberId,
    senderGuardianId: senderGuardianId.present
        ? senderGuardianId.value
        : this.senderGuardianId,
    body: body ?? this.body,
    readAt: readAt.present ? readAt.value : this.readAt,
    readByGuardianIds: readByGuardianIds.present
        ? readByGuardianIds.value
        : this.readByGuardianIds,
    createdAt: createdAt ?? this.createdAt,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      guardianId: data.guardianId.present
          ? data.guardianId.value
          : this.guardianId,
      senderKind: data.senderKind.present
          ? data.senderKind.value
          : this.senderKind,
      senderMemberId: data.senderMemberId.present
          ? data.senderMemberId.value
          : this.senderMemberId,
      senderGuardianId: data.senderGuardianId.present
          ? data.senderGuardianId.value
          : this.senderGuardianId,
      body: data.body.present ? data.body.value : this.body,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      readByGuardianIds: data.readByGuardianIds.present
          ? data.readByGuardianIds.value
          : this.readByGuardianIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('subjectId: $subjectId, ')
          ..write('guardianId: $guardianId, ')
          ..write('senderKind: $senderKind, ')
          ..write('senderMemberId: $senderMemberId, ')
          ..write('senderGuardianId: $senderGuardianId, ')
          ..write('body: $body, ')
          ..write('readAt: $readAt, ')
          ..write('readByGuardianIds: $readByGuardianIds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    subjectId,
    guardianId,
    senderKind,
    senderMemberId,
    senderGuardianId,
    body,
    readAt,
    readByGuardianIds,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.subjectId == this.subjectId &&
          other.guardianId == this.guardianId &&
          other.senderKind == this.senderKind &&
          other.senderMemberId == this.senderMemberId &&
          other.senderGuardianId == this.senderGuardianId &&
          other.body == this.body &&
          other.readAt == this.readAt &&
          other.readByGuardianIds == this.readByGuardianIds &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> subjectId;
  final Value<String> guardianId;
  final Value<String> senderKind;
  final Value<String?> senderMemberId;
  final Value<String?> senderGuardianId;
  final Value<String> body;
  final Value<String?> readAt;
  final Value<String?> readByGuardianIds;
  final Value<String> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.guardianId = const Value.absent(),
    this.senderKind = const Value.absent(),
    this.senderMemberId = const Value.absent(),
    this.senderGuardianId = const Value.absent(),
    this.body = const Value.absent(),
    this.readAt = const Value.absent(),
    this.readByGuardianIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String spaceId,
    required String subjectId,
    required String guardianId,
    required String senderKind,
    this.senderMemberId = const Value.absent(),
    this.senderGuardianId = const Value.absent(),
    required String body,
    this.readAt = const Value.absent(),
    this.readByGuardianIds = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       subjectId = Value(subjectId),
       guardianId = Value(guardianId),
       senderKind = Value(senderKind),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? subjectId,
    Expression<String>? guardianId,
    Expression<String>? senderKind,
    Expression<String>? senderMemberId,
    Expression<String>? senderGuardianId,
    Expression<String>? body,
    Expression<String>? readAt,
    Expression<String>? readByGuardianIds,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (subjectId != null) 'subject_id': subjectId,
      if (guardianId != null) 'guardian_id': guardianId,
      if (senderKind != null) 'sender_kind': senderKind,
      if (senderMemberId != null) 'sender_member_id': senderMemberId,
      if (senderGuardianId != null) 'sender_guardian_id': senderGuardianId,
      if (body != null) 'body': body,
      if (readAt != null) 'read_at': readAt,
      if (readByGuardianIds != null) 'read_by_guardian_ids': readByGuardianIds,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? subjectId,
    Value<String>? guardianId,
    Value<String>? senderKind,
    Value<String?>? senderMemberId,
    Value<String?>? senderGuardianId,
    Value<String>? body,
    Value<String?>? readAt,
    Value<String?>? readByGuardianIds,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      subjectId: subjectId ?? this.subjectId,
      guardianId: guardianId ?? this.guardianId,
      senderKind: senderKind ?? this.senderKind,
      senderMemberId: senderMemberId ?? this.senderMemberId,
      senderGuardianId: senderGuardianId ?? this.senderGuardianId,
      body: body ?? this.body,
      readAt: readAt ?? this.readAt,
      readByGuardianIds: readByGuardianIds ?? this.readByGuardianIds,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (guardianId.present) {
      map['guardian_id'] = Variable<String>(guardianId.value);
    }
    if (senderKind.present) {
      map['sender_kind'] = Variable<String>(senderKind.value);
    }
    if (senderMemberId.present) {
      map['sender_member_id'] = Variable<String>(senderMemberId.value);
    }
    if (senderGuardianId.present) {
      map['sender_guardian_id'] = Variable<String>(senderGuardianId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<String>(readAt.value);
    }
    if (readByGuardianIds.present) {
      map['read_by_guardian_ids'] = Variable<String>(readByGuardianIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('subjectId: $subjectId, ')
          ..write('guardianId: $guardianId, ')
          ..write('senderKind: $senderKind, ')
          ..write('senderMemberId: $senderMemberId, ')
          ..write('senderGuardianId: $senderGuardianId, ')
          ..write('body: $body, ')
          ..write('readAt: $readAt, ')
          ..write('readByGuardianIds: $readByGuardianIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExportsTable extends Exports with TableInfo<$ExportsTable, Export> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateVersionMeta = const VerificationMeta(
    'templateVersion',
  );
  @override
  late final GeneratedColumn<String> templateVersion = GeneratedColumn<String>(
    'template_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<String> generatedAt = GeneratedColumn<String>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<String> sentAt = GeneratedColumn<String>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    authorId,
    templateId,
    templateVersion,
    subjectId,
    groupId,
    status,
    format,
    storagePath,
    snapshotJson,
    note,
    generatedAt,
    sentAt,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exports';
  @override
  VerificationContext validateIntegrity(
    Insertable<Export> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('template_version')) {
      context.handle(
        _templateVersionMeta,
        templateVersion.isAcceptableOrUnknown(
          data['template_version']!,
          _templateVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_templateVersionMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Export map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Export(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      templateVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_version'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      storagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_path'],
      ),
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generated_at'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sent_at'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExportsTable createAlias(String alias) {
    return $ExportsTable(attachedDatabase, alias);
  }
}

class Export extends DataClass implements Insertable<Export> {
  final String id;
  final String spaceId;
  final String? authorId;
  final String templateId;
  final String templateVersion;
  final String? subjectId;
  final String? groupId;
  final String status;
  final String format;
  final String? storagePath;
  final String snapshotJson;
  final String? note;
  final String generatedAt;
  final String? sentAt;
  final String? archivedAt;
  final String createdAt;
  final String updatedAt;
  const Export({
    required this.id,
    required this.spaceId,
    this.authorId,
    required this.templateId,
    required this.templateVersion,
    this.subjectId,
    this.groupId,
    required this.status,
    required this.format,
    this.storagePath,
    required this.snapshotJson,
    this.note,
    required this.generatedAt,
    this.sentAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    map['template_id'] = Variable<String>(templateId);
    map['template_version'] = Variable<String>(templateVersion);
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['status'] = Variable<String>(status);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || storagePath != null) {
      map['storage_path'] = Variable<String>(storagePath);
    }
    map['snapshot_json'] = Variable<String>(snapshotJson);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['generated_at'] = Variable<String>(generatedAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<String>(sentAt);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ExportsCompanion toCompanion(bool nullToAbsent) {
    return ExportsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      templateId: Value(templateId),
      templateVersion: Value(templateVersion),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      status: Value(status),
      format: Value(format),
      storagePath: storagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(storagePath),
      snapshotJson: Value(snapshotJson),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      generatedAt: Value(generatedAt),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Export.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Export(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      authorId: serializer.fromJson<String?>(json['authorId']),
      templateId: serializer.fromJson<String>(json['templateId']),
      templateVersion: serializer.fromJson<String>(json['templateVersion']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      status: serializer.fromJson<String>(json['status']),
      format: serializer.fromJson<String>(json['format']),
      storagePath: serializer.fromJson<String?>(json['storagePath']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
      note: serializer.fromJson<String?>(json['note']),
      generatedAt: serializer.fromJson<String>(json['generatedAt']),
      sentAt: serializer.fromJson<String?>(json['sentAt']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'authorId': serializer.toJson<String?>(authorId),
      'templateId': serializer.toJson<String>(templateId),
      'templateVersion': serializer.toJson<String>(templateVersion),
      'subjectId': serializer.toJson<String?>(subjectId),
      'groupId': serializer.toJson<String?>(groupId),
      'status': serializer.toJson<String>(status),
      'format': serializer.toJson<String>(format),
      'storagePath': serializer.toJson<String?>(storagePath),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
      'note': serializer.toJson<String?>(note),
      'generatedAt': serializer.toJson<String>(generatedAt),
      'sentAt': serializer.toJson<String?>(sentAt),
      'archivedAt': serializer.toJson<String?>(archivedAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Export copyWith({
    String? id,
    String? spaceId,
    Value<String?> authorId = const Value.absent(),
    String? templateId,
    String? templateVersion,
    Value<String?> subjectId = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    String? status,
    String? format,
    Value<String?> storagePath = const Value.absent(),
    String? snapshotJson,
    Value<String?> note = const Value.absent(),
    String? generatedAt,
    Value<String?> sentAt = const Value.absent(),
    Value<String?> archivedAt = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Export(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    authorId: authorId.present ? authorId.value : this.authorId,
    templateId: templateId ?? this.templateId,
    templateVersion: templateVersion ?? this.templateVersion,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    groupId: groupId.present ? groupId.value : this.groupId,
    status: status ?? this.status,
    format: format ?? this.format,
    storagePath: storagePath.present ? storagePath.value : this.storagePath,
    snapshotJson: snapshotJson ?? this.snapshotJson,
    note: note.present ? note.value : this.note,
    generatedAt: generatedAt ?? this.generatedAt,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Export copyWithCompanion(ExportsCompanion data) {
    return Export(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      templateVersion: data.templateVersion.present
          ? data.templateVersion.value
          : this.templateVersion,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      status: data.status.present ? data.status.value : this.status,
      format: data.format.present ? data.format.value : this.format,
      storagePath: data.storagePath.present
          ? data.storagePath.value
          : this.storagePath,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      note: data.note.present ? data.note.value : this.note,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Export(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('authorId: $authorId, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('subjectId: $subjectId, ')
          ..write('groupId: $groupId, ')
          ..write('status: $status, ')
          ..write('format: $format, ')
          ..write('storagePath: $storagePath, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('note: $note, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    authorId,
    templateId,
    templateVersion,
    subjectId,
    groupId,
    status,
    format,
    storagePath,
    snapshotJson,
    note,
    generatedAt,
    sentAt,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Export &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.authorId == this.authorId &&
          other.templateId == this.templateId &&
          other.templateVersion == this.templateVersion &&
          other.subjectId == this.subjectId &&
          other.groupId == this.groupId &&
          other.status == this.status &&
          other.format == this.format &&
          other.storagePath == this.storagePath &&
          other.snapshotJson == this.snapshotJson &&
          other.note == this.note &&
          other.generatedAt == this.generatedAt &&
          other.sentAt == this.sentAt &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExportsCompanion extends UpdateCompanion<Export> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> authorId;
  final Value<String> templateId;
  final Value<String> templateVersion;
  final Value<String?> subjectId;
  final Value<String?> groupId;
  final Value<String> status;
  final Value<String> format;
  final Value<String?> storagePath;
  final Value<String> snapshotJson;
  final Value<String?> note;
  final Value<String> generatedAt;
  final Value<String?> sentAt;
  final Value<String?> archivedAt;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ExportsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.status = const Value.absent(),
    this.format = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.note = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExportsCompanion.insert({
    required String id,
    required String spaceId,
    this.authorId = const Value.absent(),
    required String templateId,
    required String templateVersion,
    this.subjectId = const Value.absent(),
    this.groupId = const Value.absent(),
    required String status,
    required String format,
    this.storagePath = const Value.absent(),
    required String snapshotJson,
    this.note = const Value.absent(),
    required String generatedAt,
    this.sentAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       templateId = Value(templateId),
       templateVersion = Value(templateVersion),
       status = Value(status),
       format = Value(format),
       snapshotJson = Value(snapshotJson),
       generatedAt = Value(generatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Export> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? authorId,
    Expression<String>? templateId,
    Expression<String>? templateVersion,
    Expression<String>? subjectId,
    Expression<String>? groupId,
    Expression<String>? status,
    Expression<String>? format,
    Expression<String>? storagePath,
    Expression<String>? snapshotJson,
    Expression<String>? note,
    Expression<String>? generatedAt,
    Expression<String>? sentAt,
    Expression<String>? archivedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (authorId != null) 'author_id': authorId,
      if (templateId != null) 'template_id': templateId,
      if (templateVersion != null) 'template_version': templateVersion,
      if (subjectId != null) 'subject_id': subjectId,
      if (groupId != null) 'group_id': groupId,
      if (status != null) 'status': status,
      if (format != null) 'format': format,
      if (storagePath != null) 'storage_path': storagePath,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (note != null) 'note': note,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExportsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? authorId,
    Value<String>? templateId,
    Value<String>? templateVersion,
    Value<String?>? subjectId,
    Value<String?>? groupId,
    Value<String>? status,
    Value<String>? format,
    Value<String?>? storagePath,
    Value<String>? snapshotJson,
    Value<String?>? note,
    Value<String>? generatedAt,
    Value<String?>? sentAt,
    Value<String?>? archivedAt,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExportsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      authorId: authorId ?? this.authorId,
      templateId: templateId ?? this.templateId,
      templateVersion: templateVersion ?? this.templateVersion,
      subjectId: subjectId ?? this.subjectId,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      format: format ?? this.format,
      storagePath: storagePath ?? this.storagePath,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      note: note ?? this.note,
      generatedAt: generatedAt ?? this.generatedAt,
      sentAt: sentAt ?? this.sentAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (templateVersion.present) {
      map['template_version'] = Variable<String>(templateVersion.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<String>(generatedAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<String>(sentAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExportsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('authorId: $authorId, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('subjectId: $subjectId, ')
          ..write('groupId: $groupId, ')
          ..write('status: $status, ')
          ..write('format: $format, ')
          ..write('storagePath: $storagePath, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('note: $note, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExportRecipientsTable extends ExportRecipients
    with TableInfo<$ExportRecipientsTable, ExportRecipient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExportRecipientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportIdMeta = const VerificationMeta(
    'exportId',
  );
  @override
  late final GeneratedColumn<String> exportId = GeneratedColumn<String>(
    'export_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guardianIdMeta = const VerificationMeta(
    'guardianId',
  );
  @override
  late final GeneratedColumn<String> guardianId = GeneratedColumn<String>(
    'guardian_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta(
    'memberId',
  );
  @override
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalLabelMeta = const VerificationMeta(
    'externalLabel',
  );
  @override
  late final GeneratedColumn<String> externalLabel = GeneratedColumn<String>(
    'external_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalEmailMeta = const VerificationMeta(
    'externalEmail',
  );
  @override
  late final GeneratedColumn<String> externalEmail = GeneratedColumn<String>(
    'external_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateDetailMeta = const VerificationMeta(
    'stateDetail',
  );
  @override
  late final GeneratedColumn<String> stateDetail = GeneratedColumn<String>(
    'state_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<String> sentAt = GeneratedColumn<String>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<String> readAt = GeneratedColumn<String>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exportId,
    spaceId,
    kind,
    guardianId,
    memberId,
    externalLabel,
    externalEmail,
    channel,
    state,
    stateDetail,
    sentAt,
    readAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'export_recipients';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExportRecipient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('export_id')) {
      context.handle(
        _exportIdMeta,
        exportId.isAcceptableOrUnknown(data['export_id']!, _exportIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exportIdMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('guardian_id')) {
      context.handle(
        _guardianIdMeta,
        guardianId.isAcceptableOrUnknown(data['guardian_id']!, _guardianIdMeta),
      );
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    }
    if (data.containsKey('external_label')) {
      context.handle(
        _externalLabelMeta,
        externalLabel.isAcceptableOrUnknown(
          data['external_label']!,
          _externalLabelMeta,
        ),
      );
    }
    if (data.containsKey('external_email')) {
      context.handle(
        _externalEmailMeta,
        externalEmail.isAcceptableOrUnknown(
          data['external_email']!,
          _externalEmailMeta,
        ),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('state_detail')) {
      context.handle(
        _stateDetailMeta,
        stateDetail.isAcceptableOrUnknown(
          data['state_detail']!,
          _stateDetailMeta,
        ),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExportRecipient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExportRecipient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      exportId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}export_id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      guardianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guardian_id'],
      ),
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      ),
      externalLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_label'],
      ),
      externalEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_email'],
      ),
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      stateDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_detail'],
      ),
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sent_at'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExportRecipientsTable createAlias(String alias) {
    return $ExportRecipientsTable(attachedDatabase, alias);
  }
}

class ExportRecipient extends DataClass implements Insertable<ExportRecipient> {
  final String id;
  final String exportId;
  final String spaceId;
  final String kind;
  final String? guardianId;
  final String? memberId;
  final String? externalLabel;
  final String? externalEmail;
  final String channel;
  final String state;
  final String? stateDetail;
  final String? sentAt;
  final String? readAt;
  final String createdAt;
  const ExportRecipient({
    required this.id,
    required this.exportId,
    required this.spaceId,
    required this.kind,
    this.guardianId,
    this.memberId,
    this.externalLabel,
    this.externalEmail,
    required this.channel,
    required this.state,
    this.stateDetail,
    this.sentAt,
    this.readAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['export_id'] = Variable<String>(exportId);
    map['space_id'] = Variable<String>(spaceId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || guardianId != null) {
      map['guardian_id'] = Variable<String>(guardianId);
    }
    if (!nullToAbsent || memberId != null) {
      map['member_id'] = Variable<String>(memberId);
    }
    if (!nullToAbsent || externalLabel != null) {
      map['external_label'] = Variable<String>(externalLabel);
    }
    if (!nullToAbsent || externalEmail != null) {
      map['external_email'] = Variable<String>(externalEmail);
    }
    map['channel'] = Variable<String>(channel);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || stateDetail != null) {
      map['state_detail'] = Variable<String>(stateDetail);
    }
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<String>(sentAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<String>(readAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ExportRecipientsCompanion toCompanion(bool nullToAbsent) {
    return ExportRecipientsCompanion(
      id: Value(id),
      exportId: Value(exportId),
      spaceId: Value(spaceId),
      kind: Value(kind),
      guardianId: guardianId == null && nullToAbsent
          ? const Value.absent()
          : Value(guardianId),
      memberId: memberId == null && nullToAbsent
          ? const Value.absent()
          : Value(memberId),
      externalLabel: externalLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(externalLabel),
      externalEmail: externalEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(externalEmail),
      channel: Value(channel),
      state: Value(state),
      stateDetail: stateDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(stateDetail),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      createdAt: Value(createdAt),
    );
  }

  factory ExportRecipient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExportRecipient(
      id: serializer.fromJson<String>(json['id']),
      exportId: serializer.fromJson<String>(json['exportId']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      kind: serializer.fromJson<String>(json['kind']),
      guardianId: serializer.fromJson<String?>(json['guardianId']),
      memberId: serializer.fromJson<String?>(json['memberId']),
      externalLabel: serializer.fromJson<String?>(json['externalLabel']),
      externalEmail: serializer.fromJson<String?>(json['externalEmail']),
      channel: serializer.fromJson<String>(json['channel']),
      state: serializer.fromJson<String>(json['state']),
      stateDetail: serializer.fromJson<String?>(json['stateDetail']),
      sentAt: serializer.fromJson<String?>(json['sentAt']),
      readAt: serializer.fromJson<String?>(json['readAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exportId': serializer.toJson<String>(exportId),
      'spaceId': serializer.toJson<String>(spaceId),
      'kind': serializer.toJson<String>(kind),
      'guardianId': serializer.toJson<String?>(guardianId),
      'memberId': serializer.toJson<String?>(memberId),
      'externalLabel': serializer.toJson<String?>(externalLabel),
      'externalEmail': serializer.toJson<String?>(externalEmail),
      'channel': serializer.toJson<String>(channel),
      'state': serializer.toJson<String>(state),
      'stateDetail': serializer.toJson<String?>(stateDetail),
      'sentAt': serializer.toJson<String?>(sentAt),
      'readAt': serializer.toJson<String?>(readAt),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ExportRecipient copyWith({
    String? id,
    String? exportId,
    String? spaceId,
    String? kind,
    Value<String?> guardianId = const Value.absent(),
    Value<String?> memberId = const Value.absent(),
    Value<String?> externalLabel = const Value.absent(),
    Value<String?> externalEmail = const Value.absent(),
    String? channel,
    String? state,
    Value<String?> stateDetail = const Value.absent(),
    Value<String?> sentAt = const Value.absent(),
    Value<String?> readAt = const Value.absent(),
    String? createdAt,
  }) => ExportRecipient(
    id: id ?? this.id,
    exportId: exportId ?? this.exportId,
    spaceId: spaceId ?? this.spaceId,
    kind: kind ?? this.kind,
    guardianId: guardianId.present ? guardianId.value : this.guardianId,
    memberId: memberId.present ? memberId.value : this.memberId,
    externalLabel: externalLabel.present
        ? externalLabel.value
        : this.externalLabel,
    externalEmail: externalEmail.present
        ? externalEmail.value
        : this.externalEmail,
    channel: channel ?? this.channel,
    state: state ?? this.state,
    stateDetail: stateDetail.present ? stateDetail.value : this.stateDetail,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ExportRecipient copyWithCompanion(ExportRecipientsCompanion data) {
    return ExportRecipient(
      id: data.id.present ? data.id.value : this.id,
      exportId: data.exportId.present ? data.exportId.value : this.exportId,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      guardianId: data.guardianId.present
          ? data.guardianId.value
          : this.guardianId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      externalLabel: data.externalLabel.present
          ? data.externalLabel.value
          : this.externalLabel,
      externalEmail: data.externalEmail.present
          ? data.externalEmail.value
          : this.externalEmail,
      channel: data.channel.present ? data.channel.value : this.channel,
      state: data.state.present ? data.state.value : this.state,
      stateDetail: data.stateDetail.present
          ? data.stateDetail.value
          : this.stateDetail,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExportRecipient(')
          ..write('id: $id, ')
          ..write('exportId: $exportId, ')
          ..write('spaceId: $spaceId, ')
          ..write('kind: $kind, ')
          ..write('guardianId: $guardianId, ')
          ..write('memberId: $memberId, ')
          ..write('externalLabel: $externalLabel, ')
          ..write('externalEmail: $externalEmail, ')
          ..write('channel: $channel, ')
          ..write('state: $state, ')
          ..write('stateDetail: $stateDetail, ')
          ..write('sentAt: $sentAt, ')
          ..write('readAt: $readAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    exportId,
    spaceId,
    kind,
    guardianId,
    memberId,
    externalLabel,
    externalEmail,
    channel,
    state,
    stateDetail,
    sentAt,
    readAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExportRecipient &&
          other.id == this.id &&
          other.exportId == this.exportId &&
          other.spaceId == this.spaceId &&
          other.kind == this.kind &&
          other.guardianId == this.guardianId &&
          other.memberId == this.memberId &&
          other.externalLabel == this.externalLabel &&
          other.externalEmail == this.externalEmail &&
          other.channel == this.channel &&
          other.state == this.state &&
          other.stateDetail == this.stateDetail &&
          other.sentAt == this.sentAt &&
          other.readAt == this.readAt &&
          other.createdAt == this.createdAt);
}

class ExportRecipientsCompanion extends UpdateCompanion<ExportRecipient> {
  final Value<String> id;
  final Value<String> exportId;
  final Value<String> spaceId;
  final Value<String> kind;
  final Value<String?> guardianId;
  final Value<String?> memberId;
  final Value<String?> externalLabel;
  final Value<String?> externalEmail;
  final Value<String> channel;
  final Value<String> state;
  final Value<String?> stateDetail;
  final Value<String?> sentAt;
  final Value<String?> readAt;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ExportRecipientsCompanion({
    this.id = const Value.absent(),
    this.exportId = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.guardianId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.externalLabel = const Value.absent(),
    this.externalEmail = const Value.absent(),
    this.channel = const Value.absent(),
    this.state = const Value.absent(),
    this.stateDetail = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExportRecipientsCompanion.insert({
    required String id,
    required String exportId,
    required String spaceId,
    required String kind,
    this.guardianId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.externalLabel = const Value.absent(),
    this.externalEmail = const Value.absent(),
    required String channel,
    required String state,
    this.stateDetail = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.readAt = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       exportId = Value(exportId),
       spaceId = Value(spaceId),
       kind = Value(kind),
       channel = Value(channel),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<ExportRecipient> custom({
    Expression<String>? id,
    Expression<String>? exportId,
    Expression<String>? spaceId,
    Expression<String>? kind,
    Expression<String>? guardianId,
    Expression<String>? memberId,
    Expression<String>? externalLabel,
    Expression<String>? externalEmail,
    Expression<String>? channel,
    Expression<String>? state,
    Expression<String>? stateDetail,
    Expression<String>? sentAt,
    Expression<String>? readAt,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exportId != null) 'export_id': exportId,
      if (spaceId != null) 'space_id': spaceId,
      if (kind != null) 'kind': kind,
      if (guardianId != null) 'guardian_id': guardianId,
      if (memberId != null) 'member_id': memberId,
      if (externalLabel != null) 'external_label': externalLabel,
      if (externalEmail != null) 'external_email': externalEmail,
      if (channel != null) 'channel': channel,
      if (state != null) 'state': state,
      if (stateDetail != null) 'state_detail': stateDetail,
      if (sentAt != null) 'sent_at': sentAt,
      if (readAt != null) 'read_at': readAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExportRecipientsCompanion copyWith({
    Value<String>? id,
    Value<String>? exportId,
    Value<String>? spaceId,
    Value<String>? kind,
    Value<String?>? guardianId,
    Value<String?>? memberId,
    Value<String?>? externalLabel,
    Value<String?>? externalEmail,
    Value<String>? channel,
    Value<String>? state,
    Value<String?>? stateDetail,
    Value<String?>? sentAt,
    Value<String?>? readAt,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ExportRecipientsCompanion(
      id: id ?? this.id,
      exportId: exportId ?? this.exportId,
      spaceId: spaceId ?? this.spaceId,
      kind: kind ?? this.kind,
      guardianId: guardianId ?? this.guardianId,
      memberId: memberId ?? this.memberId,
      externalLabel: externalLabel ?? this.externalLabel,
      externalEmail: externalEmail ?? this.externalEmail,
      channel: channel ?? this.channel,
      state: state ?? this.state,
      stateDetail: stateDetail ?? this.stateDetail,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exportId.present) {
      map['export_id'] = Variable<String>(exportId.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (guardianId.present) {
      map['guardian_id'] = Variable<String>(guardianId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (externalLabel.present) {
      map['external_label'] = Variable<String>(externalLabel.value);
    }
    if (externalEmail.present) {
      map['external_email'] = Variable<String>(externalEmail.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (stateDetail.present) {
      map['state_detail'] = Variable<String>(stateDetail.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<String>(sentAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<String>(readAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExportRecipientsCompanion(')
          ..write('id: $id, ')
          ..write('exportId: $exportId, ')
          ..write('spaceId: $spaceId, ')
          ..write('kind: $kind, ')
          ..write('guardianId: $guardianId, ')
          ..write('memberId: $memberId, ')
          ..write('externalLabel: $externalLabel, ')
          ..write('externalEmail: $externalEmail, ')
          ..write('channel: $channel, ')
          ..write('state: $state, ')
          ..write('stateDetail: $stateDetail, ')
          ..write('sentAt: $sentAt, ')
          ..write('readAt: $readAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, Location> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capacityMeta = const VerificationMeta(
    'capacity',
  );
  @override
  late final GeneratedColumn<int> capacity = GeneratedColumn<int>(
    'capacity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOutdoorMeta = const VerificationMeta(
    'isOutdoor',
  );
  @override
  late final GeneratedColumn<int> isOutdoor = GeneratedColumn<int>(
    'is_outdoor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    name,
    notes,
    capacity,
    isOutdoor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Location> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('capacity')) {
      context.handle(
        _capacityMeta,
        capacity.isAcceptableOrUnknown(data['capacity']!, _capacityMeta),
      );
    }
    if (data.containsKey('is_outdoor')) {
      context.handle(
        _isOutdoorMeta,
        isOutdoor.isAcceptableOrUnknown(data['is_outdoor']!, _isOutdoorMeta),
      );
    } else if (isInserting) {
      context.missing(_isOutdoorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Location map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Location(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity'],
      ),
      isOutdoor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_outdoor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class Location extends DataClass implements Insertable<Location> {
  final String id;
  final String spaceId;
  final String name;
  final String? notes;
  final int? capacity;
  final int isOutdoor;
  final String createdAt;
  final String updatedAt;
  const Location({
    required this.id,
    required this.spaceId,
    required this.name,
    this.notes,
    this.capacity,
    required this.isOutdoor,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || capacity != null) {
      map['capacity'] = Variable<int>(capacity);
    }
    map['is_outdoor'] = Variable<int>(isOutdoor);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      capacity: capacity == null && nullToAbsent
          ? const Value.absent()
          : Value(capacity),
      isOutdoor: Value(isOutdoor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Location.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Location(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      capacity: serializer.fromJson<int?>(json['capacity']),
      isOutdoor: serializer.fromJson<int>(json['isOutdoor']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'capacity': serializer.toJson<int?>(capacity),
      'isOutdoor': serializer.toJson<int>(isOutdoor),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Location copyWith({
    String? id,
    String? spaceId,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<int?> capacity = const Value.absent(),
    int? isOutdoor,
    String? createdAt,
    String? updatedAt,
  }) => Location(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    capacity: capacity.present ? capacity.value : this.capacity,
    isOutdoor: isOutdoor ?? this.isOutdoor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Location copyWithCompanion(LocationsCompanion data) {
    return Location(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      capacity: data.capacity.present ? data.capacity.value : this.capacity,
      isOutdoor: data.isOutdoor.present ? data.isOutdoor.value : this.isOutdoor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Location(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('capacity: $capacity, ')
          ..write('isOutdoor: $isOutdoor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    name,
    notes,
    capacity,
    isOutdoor,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Location &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.capacity == this.capacity &&
          other.isOutdoor == this.isOutdoor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocationsCompanion extends UpdateCompanion<Location> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> name;
  final Value<String?> notes;
  final Value<int?> capacity;
  final Value<int> isOutdoor;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.capacity = const Value.absent(),
    this.isOutdoor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationsCompanion.insert({
    required String id,
    required String spaceId,
    required String name,
    this.notes = const Value.absent(),
    this.capacity = const Value.absent(),
    required int isOutdoor,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       name = Value(name),
       isOutdoor = Value(isOutdoor),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Location> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<int>? capacity,
    Expression<int>? isOutdoor,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (capacity != null) 'capacity': capacity,
      if (isOutdoor != null) 'is_outdoor': isOutdoor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? name,
    Value<String?>? notes,
    Value<int?>? capacity,
    Value<int>? isOutdoor,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      capacity: capacity ?? this.capacity,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (capacity.present) {
      map['capacity'] = Variable<int>(capacity.value);
    }
    if (isOutdoor.present) {
      map['is_outdoor'] = Variable<int>(isOutdoor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('capacity: $capacity, ')
          ..write('isOutdoor: $isOutdoor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, Activity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerMemberIdMeta = const VerificationMeta(
    'ownerMemberId',
  );
  @override
  late final GeneratedColumn<String> ownerMemberId = GeneratedColumn<String>(
    'owner_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultLocationIdMeta = const VerificationMeta(
    'defaultLocationId',
  );
  @override
  late final GeneratedColumn<String> defaultLocationId =
      GeneratedColumn<String>(
        'default_location_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _defaultDurationMinutesMeta =
      const VerificationMeta('defaultDurationMinutes');
  @override
  late final GeneratedColumn<int> defaultDurationMinutes = GeneratedColumn<int>(
    'default_duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suppliesMeta = const VerificationMeta(
    'supplies',
  );
  @override
  late final GeneratedColumn<String> supplies = GeneratedColumn<String>(
    'supplies',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageMinMeta = const VerificationMeta('ageMin');
  @override
  late final GeneratedColumn<int> ageMin = GeneratedColumn<int>(
    'age_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageMaxMeta = const VerificationMeta('ageMax');
  @override
  late final GeneratedColumn<int> ageMax = GeneratedColumn<int>(
    'age_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxCapacityMeta = const VerificationMeta(
    'maxCapacity',
  );
  @override
  late final GeneratedColumn<int> maxCapacity = GeneratedColumn<int>(
    'max_capacity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOutdoorMeta = const VerificationMeta(
    'isOutdoor',
  );
  @override
  late final GeneratedColumn<int> isOutdoor = GeneratedColumn<int>(
    'is_outdoor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indoorAltActivityIdMeta =
      const VerificationMeta('indoorAltActivityId');
  @override
  late final GeneratedColumn<String> indoorAltActivityId =
      GeneratedColumn<String>(
        'indoor_alt_activity_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    ownerMemberId,
    name,
    description,
    defaultLocationId,
    defaultDurationMinutes,
    supplies,
    ageMin,
    ageMax,
    maxCapacity,
    isOutdoor,
    indoorAltActivityId,
    capabilities,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Activity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('owner_member_id')) {
      context.handle(
        _ownerMemberIdMeta,
        ownerMemberId.isAcceptableOrUnknown(
          data['owner_member_id']!,
          _ownerMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('default_location_id')) {
      context.handle(
        _defaultLocationIdMeta,
        defaultLocationId.isAcceptableOrUnknown(
          data['default_location_id']!,
          _defaultLocationIdMeta,
        ),
      );
    }
    if (data.containsKey('default_duration_minutes')) {
      context.handle(
        _defaultDurationMinutesMeta,
        defaultDurationMinutes.isAcceptableOrUnknown(
          data['default_duration_minutes']!,
          _defaultDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('supplies')) {
      context.handle(
        _suppliesMeta,
        supplies.isAcceptableOrUnknown(data['supplies']!, _suppliesMeta),
      );
    }
    if (data.containsKey('age_min')) {
      context.handle(
        _ageMinMeta,
        ageMin.isAcceptableOrUnknown(data['age_min']!, _ageMinMeta),
      );
    }
    if (data.containsKey('age_max')) {
      context.handle(
        _ageMaxMeta,
        ageMax.isAcceptableOrUnknown(data['age_max']!, _ageMaxMeta),
      );
    }
    if (data.containsKey('max_capacity')) {
      context.handle(
        _maxCapacityMeta,
        maxCapacity.isAcceptableOrUnknown(
          data['max_capacity']!,
          _maxCapacityMeta,
        ),
      );
    }
    if (data.containsKey('is_outdoor')) {
      context.handle(
        _isOutdoorMeta,
        isOutdoor.isAcceptableOrUnknown(data['is_outdoor']!, _isOutdoorMeta),
      );
    } else if (isInserting) {
      context.missing(_isOutdoorMeta);
    }
    if (data.containsKey('indoor_alt_activity_id')) {
      context.handle(
        _indoorAltActivityIdMeta,
        indoorAltActivityId.isAcceptableOrUnknown(
          data['indoor_alt_activity_id']!,
          _indoorAltActivityIdMeta,
        ),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Activity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Activity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      ownerMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_member_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      defaultLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_location_id'],
      ),
      defaultDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_duration_minutes'],
      ),
      supplies: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplies'],
      ),
      ageMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_min'],
      ),
      ageMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_max'],
      ),
      maxCapacity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_capacity'],
      ),
      isOutdoor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_outdoor'],
      )!,
      indoorAltActivityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}indoor_alt_activity_id'],
      ),
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class Activity extends DataClass implements Insertable<Activity> {
  final String id;
  final String spaceId;
  final String? ownerMemberId;
  final String name;
  final String? description;
  final String? defaultLocationId;
  final int? defaultDurationMinutes;
  final String? supplies;
  final int? ageMin;
  final int? ageMax;
  final int? maxCapacity;
  final int isOutdoor;
  final String? indoorAltActivityId;
  final String capabilities;
  final String? archivedAt;
  final String createdAt;
  final String updatedAt;
  const Activity({
    required this.id,
    required this.spaceId,
    this.ownerMemberId,
    required this.name,
    this.description,
    this.defaultLocationId,
    this.defaultDurationMinutes,
    this.supplies,
    this.ageMin,
    this.ageMax,
    this.maxCapacity,
    required this.isOutdoor,
    this.indoorAltActivityId,
    required this.capabilities,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    if (!nullToAbsent || ownerMemberId != null) {
      map['owner_member_id'] = Variable<String>(ownerMemberId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || defaultLocationId != null) {
      map['default_location_id'] = Variable<String>(defaultLocationId);
    }
    if (!nullToAbsent || defaultDurationMinutes != null) {
      map['default_duration_minutes'] = Variable<int>(defaultDurationMinutes);
    }
    if (!nullToAbsent || supplies != null) {
      map['supplies'] = Variable<String>(supplies);
    }
    if (!nullToAbsent || ageMin != null) {
      map['age_min'] = Variable<int>(ageMin);
    }
    if (!nullToAbsent || ageMax != null) {
      map['age_max'] = Variable<int>(ageMax);
    }
    if (!nullToAbsent || maxCapacity != null) {
      map['max_capacity'] = Variable<int>(maxCapacity);
    }
    map['is_outdoor'] = Variable<int>(isOutdoor);
    if (!nullToAbsent || indoorAltActivityId != null) {
      map['indoor_alt_activity_id'] = Variable<String>(indoorAltActivityId);
    }
    map['capabilities'] = Variable<String>(capabilities);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      ownerMemberId: ownerMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerMemberId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      defaultLocationId: defaultLocationId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultLocationId),
      defaultDurationMinutes: defaultDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultDurationMinutes),
      supplies: supplies == null && nullToAbsent
          ? const Value.absent()
          : Value(supplies),
      ageMin: ageMin == null && nullToAbsent
          ? const Value.absent()
          : Value(ageMin),
      ageMax: ageMax == null && nullToAbsent
          ? const Value.absent()
          : Value(ageMax),
      maxCapacity: maxCapacity == null && nullToAbsent
          ? const Value.absent()
          : Value(maxCapacity),
      isOutdoor: Value(isOutdoor),
      indoorAltActivityId: indoorAltActivityId == null && nullToAbsent
          ? const Value.absent()
          : Value(indoorAltActivityId),
      capabilities: Value(capabilities),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Activity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Activity(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      ownerMemberId: serializer.fromJson<String?>(json['ownerMemberId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      defaultLocationId: serializer.fromJson<String?>(
        json['defaultLocationId'],
      ),
      defaultDurationMinutes: serializer.fromJson<int?>(
        json['defaultDurationMinutes'],
      ),
      supplies: serializer.fromJson<String?>(json['supplies']),
      ageMin: serializer.fromJson<int?>(json['ageMin']),
      ageMax: serializer.fromJson<int?>(json['ageMax']),
      maxCapacity: serializer.fromJson<int?>(json['maxCapacity']),
      isOutdoor: serializer.fromJson<int>(json['isOutdoor']),
      indoorAltActivityId: serializer.fromJson<String?>(
        json['indoorAltActivityId'],
      ),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      archivedAt: serializer.fromJson<String?>(json['archivedAt']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'ownerMemberId': serializer.toJson<String?>(ownerMemberId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'defaultLocationId': serializer.toJson<String?>(defaultLocationId),
      'defaultDurationMinutes': serializer.toJson<int?>(defaultDurationMinutes),
      'supplies': serializer.toJson<String?>(supplies),
      'ageMin': serializer.toJson<int?>(ageMin),
      'ageMax': serializer.toJson<int?>(ageMax),
      'maxCapacity': serializer.toJson<int?>(maxCapacity),
      'isOutdoor': serializer.toJson<int>(isOutdoor),
      'indoorAltActivityId': serializer.toJson<String?>(indoorAltActivityId),
      'capabilities': serializer.toJson<String>(capabilities),
      'archivedAt': serializer.toJson<String?>(archivedAt),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  Activity copyWith({
    String? id,
    String? spaceId,
    Value<String?> ownerMemberId = const Value.absent(),
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> defaultLocationId = const Value.absent(),
    Value<int?> defaultDurationMinutes = const Value.absent(),
    Value<String?> supplies = const Value.absent(),
    Value<int?> ageMin = const Value.absent(),
    Value<int?> ageMax = const Value.absent(),
    Value<int?> maxCapacity = const Value.absent(),
    int? isOutdoor,
    Value<String?> indoorAltActivityId = const Value.absent(),
    String? capabilities,
    Value<String?> archivedAt = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => Activity(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    ownerMemberId: ownerMemberId.present
        ? ownerMemberId.value
        : this.ownerMemberId,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    defaultLocationId: defaultLocationId.present
        ? defaultLocationId.value
        : this.defaultLocationId,
    defaultDurationMinutes: defaultDurationMinutes.present
        ? defaultDurationMinutes.value
        : this.defaultDurationMinutes,
    supplies: supplies.present ? supplies.value : this.supplies,
    ageMin: ageMin.present ? ageMin.value : this.ageMin,
    ageMax: ageMax.present ? ageMax.value : this.ageMax,
    maxCapacity: maxCapacity.present ? maxCapacity.value : this.maxCapacity,
    isOutdoor: isOutdoor ?? this.isOutdoor,
    indoorAltActivityId: indoorAltActivityId.present
        ? indoorAltActivityId.value
        : this.indoorAltActivityId,
    capabilities: capabilities ?? this.capabilities,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Activity copyWithCompanion(ActivitiesCompanion data) {
    return Activity(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      ownerMemberId: data.ownerMemberId.present
          ? data.ownerMemberId.value
          : this.ownerMemberId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      defaultLocationId: data.defaultLocationId.present
          ? data.defaultLocationId.value
          : this.defaultLocationId,
      defaultDurationMinutes: data.defaultDurationMinutes.present
          ? data.defaultDurationMinutes.value
          : this.defaultDurationMinutes,
      supplies: data.supplies.present ? data.supplies.value : this.supplies,
      ageMin: data.ageMin.present ? data.ageMin.value : this.ageMin,
      ageMax: data.ageMax.present ? data.ageMax.value : this.ageMax,
      maxCapacity: data.maxCapacity.present
          ? data.maxCapacity.value
          : this.maxCapacity,
      isOutdoor: data.isOutdoor.present ? data.isOutdoor.value : this.isOutdoor,
      indoorAltActivityId: data.indoorAltActivityId.present
          ? data.indoorAltActivityId.value
          : this.indoorAltActivityId,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Activity(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('ownerMemberId: $ownerMemberId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('defaultLocationId: $defaultLocationId, ')
          ..write('defaultDurationMinutes: $defaultDurationMinutes, ')
          ..write('supplies: $supplies, ')
          ..write('ageMin: $ageMin, ')
          ..write('ageMax: $ageMax, ')
          ..write('maxCapacity: $maxCapacity, ')
          ..write('isOutdoor: $isOutdoor, ')
          ..write('indoorAltActivityId: $indoorAltActivityId, ')
          ..write('capabilities: $capabilities, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    ownerMemberId,
    name,
    description,
    defaultLocationId,
    defaultDurationMinutes,
    supplies,
    ageMin,
    ageMax,
    maxCapacity,
    isOutdoor,
    indoorAltActivityId,
    capabilities,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Activity &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.ownerMemberId == this.ownerMemberId &&
          other.name == this.name &&
          other.description == this.description &&
          other.defaultLocationId == this.defaultLocationId &&
          other.defaultDurationMinutes == this.defaultDurationMinutes &&
          other.supplies == this.supplies &&
          other.ageMin == this.ageMin &&
          other.ageMax == this.ageMax &&
          other.maxCapacity == this.maxCapacity &&
          other.isOutdoor == this.isOutdoor &&
          other.indoorAltActivityId == this.indoorAltActivityId &&
          other.capabilities == this.capabilities &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ActivitiesCompanion extends UpdateCompanion<Activity> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String?> ownerMemberId;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> defaultLocationId;
  final Value<int?> defaultDurationMinutes;
  final Value<String?> supplies;
  final Value<int?> ageMin;
  final Value<int?> ageMax;
  final Value<int?> maxCapacity;
  final Value<int> isOutdoor;
  final Value<String?> indoorAltActivityId;
  final Value<String> capabilities;
  final Value<String?> archivedAt;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.ownerMemberId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.defaultLocationId = const Value.absent(),
    this.defaultDurationMinutes = const Value.absent(),
    this.supplies = const Value.absent(),
    this.ageMin = const Value.absent(),
    this.ageMax = const Value.absent(),
    this.maxCapacity = const Value.absent(),
    this.isOutdoor = const Value.absent(),
    this.indoorAltActivityId = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    required String id,
    required String spaceId,
    this.ownerMemberId = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.defaultLocationId = const Value.absent(),
    this.defaultDurationMinutes = const Value.absent(),
    this.supplies = const Value.absent(),
    this.ageMin = const Value.absent(),
    this.ageMax = const Value.absent(),
    this.maxCapacity = const Value.absent(),
    required int isOutdoor,
    this.indoorAltActivityId = const Value.absent(),
    required String capabilities,
    this.archivedAt = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       name = Value(name),
       isOutdoor = Value(isOutdoor),
       capabilities = Value(capabilities),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Activity> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? ownerMemberId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? defaultLocationId,
    Expression<int>? defaultDurationMinutes,
    Expression<String>? supplies,
    Expression<int>? ageMin,
    Expression<int>? ageMax,
    Expression<int>? maxCapacity,
    Expression<int>? isOutdoor,
    Expression<String>? indoorAltActivityId,
    Expression<String>? capabilities,
    Expression<String>? archivedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (ownerMemberId != null) 'owner_member_id': ownerMemberId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (defaultLocationId != null) 'default_location_id': defaultLocationId,
      if (defaultDurationMinutes != null)
        'default_duration_minutes': defaultDurationMinutes,
      if (supplies != null) 'supplies': supplies,
      if (ageMin != null) 'age_min': ageMin,
      if (ageMax != null) 'age_max': ageMax,
      if (maxCapacity != null) 'max_capacity': maxCapacity,
      if (isOutdoor != null) 'is_outdoor': isOutdoor,
      if (indoorAltActivityId != null)
        'indoor_alt_activity_id': indoorAltActivityId,
      if (capabilities != null) 'capabilities': capabilities,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String?>? ownerMemberId,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? defaultLocationId,
    Value<int?>? defaultDurationMinutes,
    Value<String?>? supplies,
    Value<int?>? ageMin,
    Value<int?>? ageMax,
    Value<int?>? maxCapacity,
    Value<int>? isOutdoor,
    Value<String?>? indoorAltActivityId,
    Value<String>? capabilities,
    Value<String?>? archivedAt,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      ownerMemberId: ownerMemberId ?? this.ownerMemberId,
      name: name ?? this.name,
      description: description ?? this.description,
      defaultLocationId: defaultLocationId ?? this.defaultLocationId,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      supplies: supplies ?? this.supplies,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      indoorAltActivityId: indoorAltActivityId ?? this.indoorAltActivityId,
      capabilities: capabilities ?? this.capabilities,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (ownerMemberId.present) {
      map['owner_member_id'] = Variable<String>(ownerMemberId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (defaultLocationId.present) {
      map['default_location_id'] = Variable<String>(defaultLocationId.value);
    }
    if (defaultDurationMinutes.present) {
      map['default_duration_minutes'] = Variable<int>(
        defaultDurationMinutes.value,
      );
    }
    if (supplies.present) {
      map['supplies'] = Variable<String>(supplies.value);
    }
    if (ageMin.present) {
      map['age_min'] = Variable<int>(ageMin.value);
    }
    if (ageMax.present) {
      map['age_max'] = Variable<int>(ageMax.value);
    }
    if (maxCapacity.present) {
      map['max_capacity'] = Variable<int>(maxCapacity.value);
    }
    if (isOutdoor.present) {
      map['is_outdoor'] = Variable<int>(isOutdoor.value);
    }
    if (indoorAltActivityId.present) {
      map['indoor_alt_activity_id'] = Variable<String>(
        indoorAltActivityId.value,
      );
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('ownerMemberId: $ownerMemberId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('defaultLocationId: $defaultLocationId, ')
          ..write('defaultDurationMinutes: $defaultDurationMinutes, ')
          ..write('supplies: $supplies, ')
          ..write('ageMin: $ageMin, ')
          ..write('ageMax: $ageMax, ')
          ..write('maxCapacity: $maxCapacity, ')
          ..write('isOutdoor: $isOutdoor, ')
          ..write('indoorAltActivityId: $indoorAltActivityId, ')
          ..write('capabilities: $capabilities, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScheduleBlocksTable extends ScheduleBlocks
    with TableInfo<$ScheduleBlocksTable, ScheduleBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<String> startAt = GeneratedColumn<String>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<String> endAt = GeneratedColumn<String>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityIdMeta = const VerificationMeta(
    'activityId',
  );
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
    'activity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leadMemberIdMeta = const VerificationMeta(
    'leadMemberId',
  );
  @override
  late final GeneratedColumn<String> leadMemberId = GeneratedColumn<String>(
    'lead_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leadSubstituteMemberIdMeta =
      const VerificationMeta('leadSubstituteMemberId');
  @override
  late final GeneratedColumn<String> leadSubstituteMemberId =
      GeneratedColumn<String>(
        'lead_substitute_member_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _locationOverrideIdMeta =
      const VerificationMeta('locationOverrideId');
  @override
  late final GeneratedColumn<String> locationOverrideId =
      GeneratedColumn<String>(
        'location_override_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    groupId,
    date,
    startAt,
    endAt,
    activityId,
    leadMemberId,
    leadSubstituteMemberId,
    locationOverrideId,
    kind,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
        _activityIdMeta,
        activityId.isAcceptableOrUnknown(data['activity_id']!, _activityIdMeta),
      );
    }
    if (data.containsKey('lead_member_id')) {
      context.handle(
        _leadMemberIdMeta,
        leadMemberId.isAcceptableOrUnknown(
          data['lead_member_id']!,
          _leadMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('lead_substitute_member_id')) {
      context.handle(
        _leadSubstituteMemberIdMeta,
        leadSubstituteMemberId.isAcceptableOrUnknown(
          data['lead_substitute_member_id']!,
          _leadSubstituteMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('location_override_id')) {
      context.handle(
        _locationOverrideIdMeta,
        locationOverrideId.isAcceptableOrUnknown(
          data['location_override_id']!,
          _locationOverrideIdMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_at'],
      )!,
      activityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_id'],
      ),
      leadMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lead_member_id'],
      ),
      leadSubstituteMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lead_substitute_member_id'],
      ),
      locationOverrideId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_override_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScheduleBlocksTable createAlias(String alias) {
    return $ScheduleBlocksTable(attachedDatabase, alias);
  }
}

class ScheduleBlock extends DataClass implements Insertable<ScheduleBlock> {
  final String id;
  final String spaceId;
  final String groupId;
  final String date;
  final String startAt;
  final String endAt;
  final String? activityId;
  final String? leadMemberId;

  /// Pat persona — director-set substitute when the planned lead is
  /// absent today. Reads use `COALESCE(substitute, lead)` so the
  /// substitute sees the block in their LeadingTodayCard and the
  /// absent person's card no longer shows it.
  final String? leadSubstituteMemberId;
  final String? locationOverrideId;
  final String kind;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  const ScheduleBlock({
    required this.id,
    required this.spaceId,
    required this.groupId,
    required this.date,
    required this.startAt,
    required this.endAt,
    this.activityId,
    this.leadMemberId,
    this.leadSubstituteMemberId,
    this.locationOverrideId,
    required this.kind,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['group_id'] = Variable<String>(groupId);
    map['date'] = Variable<String>(date);
    map['start_at'] = Variable<String>(startAt);
    map['end_at'] = Variable<String>(endAt);
    if (!nullToAbsent || activityId != null) {
      map['activity_id'] = Variable<String>(activityId);
    }
    if (!nullToAbsent || leadMemberId != null) {
      map['lead_member_id'] = Variable<String>(leadMemberId);
    }
    if (!nullToAbsent || leadSubstituteMemberId != null) {
      map['lead_substitute_member_id'] = Variable<String>(
        leadSubstituteMemberId,
      );
    }
    if (!nullToAbsent || locationOverrideId != null) {
      map['location_override_id'] = Variable<String>(locationOverrideId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ScheduleBlocksCompanion toCompanion(bool nullToAbsent) {
    return ScheduleBlocksCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      groupId: Value(groupId),
      date: Value(date),
      startAt: Value(startAt),
      endAt: Value(endAt),
      activityId: activityId == null && nullToAbsent
          ? const Value.absent()
          : Value(activityId),
      leadMemberId: leadMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(leadMemberId),
      leadSubstituteMemberId: leadSubstituteMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(leadSubstituteMemberId),
      locationOverrideId: locationOverrideId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationOverrideId),
      kind: Value(kind),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScheduleBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleBlock(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      groupId: serializer.fromJson<String>(json['groupId']),
      date: serializer.fromJson<String>(json['date']),
      startAt: serializer.fromJson<String>(json['startAt']),
      endAt: serializer.fromJson<String>(json['endAt']),
      activityId: serializer.fromJson<String?>(json['activityId']),
      leadMemberId: serializer.fromJson<String?>(json['leadMemberId']),
      leadSubstituteMemberId: serializer.fromJson<String?>(
        json['leadSubstituteMemberId'],
      ),
      locationOverrideId: serializer.fromJson<String?>(
        json['locationOverrideId'],
      ),
      kind: serializer.fromJson<String>(json['kind']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'groupId': serializer.toJson<String>(groupId),
      'date': serializer.toJson<String>(date),
      'startAt': serializer.toJson<String>(startAt),
      'endAt': serializer.toJson<String>(endAt),
      'activityId': serializer.toJson<String?>(activityId),
      'leadMemberId': serializer.toJson<String?>(leadMemberId),
      'leadSubstituteMemberId': serializer.toJson<String?>(
        leadSubstituteMemberId,
      ),
      'locationOverrideId': serializer.toJson<String?>(locationOverrideId),
      'kind': serializer.toJson<String>(kind),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  ScheduleBlock copyWith({
    String? id,
    String? spaceId,
    String? groupId,
    String? date,
    String? startAt,
    String? endAt,
    Value<String?> activityId = const Value.absent(),
    Value<String?> leadMemberId = const Value.absent(),
    Value<String?> leadSubstituteMemberId = const Value.absent(),
    Value<String?> locationOverrideId = const Value.absent(),
    String? kind,
    Value<String?> notes = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => ScheduleBlock(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    groupId: groupId ?? this.groupId,
    date: date ?? this.date,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    activityId: activityId.present ? activityId.value : this.activityId,
    leadMemberId: leadMemberId.present ? leadMemberId.value : this.leadMemberId,
    leadSubstituteMemberId: leadSubstituteMemberId.present
        ? leadSubstituteMemberId.value
        : this.leadSubstituteMemberId,
    locationOverrideId: locationOverrideId.present
        ? locationOverrideId.value
        : this.locationOverrideId,
    kind: kind ?? this.kind,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScheduleBlock copyWithCompanion(ScheduleBlocksCompanion data) {
    return ScheduleBlock(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      date: data.date.present ? data.date.value : this.date,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      activityId: data.activityId.present
          ? data.activityId.value
          : this.activityId,
      leadMemberId: data.leadMemberId.present
          ? data.leadMemberId.value
          : this.leadMemberId,
      leadSubstituteMemberId: data.leadSubstituteMemberId.present
          ? data.leadSubstituteMemberId.value
          : this.leadSubstituteMemberId,
      locationOverrideId: data.locationOverrideId.present
          ? data.locationOverrideId.value
          : this.locationOverrideId,
      kind: data.kind.present ? data.kind.value : this.kind,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleBlock(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('date: $date, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('activityId: $activityId, ')
          ..write('leadMemberId: $leadMemberId, ')
          ..write('leadSubstituteMemberId: $leadSubstituteMemberId, ')
          ..write('locationOverrideId: $locationOverrideId, ')
          ..write('kind: $kind, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    groupId,
    date,
    startAt,
    endAt,
    activityId,
    leadMemberId,
    leadSubstituteMemberId,
    locationOverrideId,
    kind,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleBlock &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.groupId == this.groupId &&
          other.date == this.date &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.activityId == this.activityId &&
          other.leadMemberId == this.leadMemberId &&
          other.leadSubstituteMemberId == this.leadSubstituteMemberId &&
          other.locationOverrideId == this.locationOverrideId &&
          other.kind == this.kind &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScheduleBlocksCompanion extends UpdateCompanion<ScheduleBlock> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> groupId;
  final Value<String> date;
  final Value<String> startAt;
  final Value<String> endAt;
  final Value<String?> activityId;
  final Value<String?> leadMemberId;
  final Value<String?> leadSubstituteMemberId;
  final Value<String?> locationOverrideId;
  final Value<String> kind;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ScheduleBlocksCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.date = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.activityId = const Value.absent(),
    this.leadMemberId = const Value.absent(),
    this.leadSubstituteMemberId = const Value.absent(),
    this.locationOverrideId = const Value.absent(),
    this.kind = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleBlocksCompanion.insert({
    required String id,
    required String spaceId,
    required String groupId,
    required String date,
    required String startAt,
    required String endAt,
    this.activityId = const Value.absent(),
    this.leadMemberId = const Value.absent(),
    this.leadSubstituteMemberId = const Value.absent(),
    this.locationOverrideId = const Value.absent(),
    required String kind,
    this.notes = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       groupId = Value(groupId),
       date = Value(date),
       startAt = Value(startAt),
       endAt = Value(endAt),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ScheduleBlock> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? groupId,
    Expression<String>? date,
    Expression<String>? startAt,
    Expression<String>? endAt,
    Expression<String>? activityId,
    Expression<String>? leadMemberId,
    Expression<String>? leadSubstituteMemberId,
    Expression<String>? locationOverrideId,
    Expression<String>? kind,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (groupId != null) 'group_id': groupId,
      if (date != null) 'date': date,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (activityId != null) 'activity_id': activityId,
      if (leadMemberId != null) 'lead_member_id': leadMemberId,
      if (leadSubstituteMemberId != null)
        'lead_substitute_member_id': leadSubstituteMemberId,
      if (locationOverrideId != null)
        'location_override_id': locationOverrideId,
      if (kind != null) 'kind': kind,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleBlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? groupId,
    Value<String>? date,
    Value<String>? startAt,
    Value<String>? endAt,
    Value<String?>? activityId,
    Value<String?>? leadMemberId,
    Value<String?>? leadSubstituteMemberId,
    Value<String?>? locationOverrideId,
    Value<String>? kind,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return ScheduleBlocksCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      groupId: groupId ?? this.groupId,
      date: date ?? this.date,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      activityId: activityId ?? this.activityId,
      leadMemberId: leadMemberId ?? this.leadMemberId,
      leadSubstituteMemberId:
          leadSubstituteMemberId ?? this.leadSubstituteMemberId,
      locationOverrideId: locationOverrideId ?? this.locationOverrideId,
      kind: kind ?? this.kind,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<String>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<String>(endAt.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (leadMemberId.present) {
      map['lead_member_id'] = Variable<String>(leadMemberId.value);
    }
    if (leadSubstituteMemberId.present) {
      map['lead_substitute_member_id'] = Variable<String>(
        leadSubstituteMemberId.value,
      );
    }
    if (locationOverrideId.present) {
      map['location_override_id'] = Variable<String>(locationOverrideId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleBlocksCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('groupId: $groupId, ')
          ..write('date: $date, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('activityId: $activityId, ')
          ..write('leadMemberId: $leadMemberId, ')
          ..write('leadSubstituteMemberId: $leadSubstituteMemberId, ')
          ..write('locationOverrideId: $locationOverrideId, ')
          ..write('kind: $kind, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripLogisticsTable extends TripLogistics
    with TableInfo<$TripLogisticsTable, TripLogistic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripLogisticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleBlockIdMeta = const VerificationMeta(
    'scheduleBlockId',
  );
  @override
  late final GeneratedColumn<String> scheduleBlockId = GeneratedColumn<String>(
    'schedule_block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationAddressMeta =
      const VerificationMeta('destinationAddress');
  @override
  late final GeneratedColumn<String> destinationAddress =
      GeneratedColumn<String>(
        'destination_address',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _departureAtMeta = const VerificationMeta(
    'departureAt',
  );
  @override
  late final GeneratedColumn<String> departureAt = GeneratedColumn<String>(
    'departure_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _returnAtMeta = const VerificationMeta(
    'returnAt',
  );
  @override
  late final GeneratedColumn<String> returnAt = GeneratedColumn<String>(
    'return_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresPermissionSlipMeta =
      const VerificationMeta('requiresPermissionSlip');
  @override
  late final GeneratedColumn<int> requiresPermissionSlip = GeneratedColumn<int>(
    'requires_permission_slip',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    scheduleBlockId,
    destination,
    destinationAddress,
    departureAt,
    returnAt,
    requiresPermissionSlip,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_logistics';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripLogistic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('schedule_block_id')) {
      context.handle(
        _scheduleBlockIdMeta,
        scheduleBlockId.isAcceptableOrUnknown(
          data['schedule_block_id']!,
          _scheduleBlockIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleBlockIdMeta);
    }
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationMeta);
    }
    if (data.containsKey('destination_address')) {
      context.handle(
        _destinationAddressMeta,
        destinationAddress.isAcceptableOrUnknown(
          data['destination_address']!,
          _destinationAddressMeta,
        ),
      );
    }
    if (data.containsKey('departure_at')) {
      context.handle(
        _departureAtMeta,
        departureAt.isAcceptableOrUnknown(
          data['departure_at']!,
          _departureAtMeta,
        ),
      );
    }
    if (data.containsKey('return_at')) {
      context.handle(
        _returnAtMeta,
        returnAt.isAcceptableOrUnknown(data['return_at']!, _returnAtMeta),
      );
    }
    if (data.containsKey('requires_permission_slip')) {
      context.handle(
        _requiresPermissionSlipMeta,
        requiresPermissionSlip.isAcceptableOrUnknown(
          data['requires_permission_slip']!,
          _requiresPermissionSlipMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requiresPermissionSlipMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripLogistic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripLogistic(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      scheduleBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_block_id'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      destinationAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_address'],
      ),
      departureAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}departure_at'],
      ),
      returnAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}return_at'],
      ),
      requiresPermissionSlip: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requires_permission_slip'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TripLogisticsTable createAlias(String alias) {
    return $TripLogisticsTable(attachedDatabase, alias);
  }
}

class TripLogistic extends DataClass implements Insertable<TripLogistic> {
  final String id;
  final String spaceId;
  final String scheduleBlockId;
  final String destination;
  final String? destinationAddress;
  final String? departureAt;
  final String? returnAt;
  final int requiresPermissionSlip;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  const TripLogistic({
    required this.id,
    required this.spaceId,
    required this.scheduleBlockId,
    required this.destination,
    this.destinationAddress,
    this.departureAt,
    this.returnAt,
    required this.requiresPermissionSlip,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['schedule_block_id'] = Variable<String>(scheduleBlockId);
    map['destination'] = Variable<String>(destination);
    if (!nullToAbsent || destinationAddress != null) {
      map['destination_address'] = Variable<String>(destinationAddress);
    }
    if (!nullToAbsent || departureAt != null) {
      map['departure_at'] = Variable<String>(departureAt);
    }
    if (!nullToAbsent || returnAt != null) {
      map['return_at'] = Variable<String>(returnAt);
    }
    map['requires_permission_slip'] = Variable<int>(requiresPermissionSlip);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  TripLogisticsCompanion toCompanion(bool nullToAbsent) {
    return TripLogisticsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      scheduleBlockId: Value(scheduleBlockId),
      destination: Value(destination),
      destinationAddress: destinationAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(destinationAddress),
      departureAt: departureAt == null && nullToAbsent
          ? const Value.absent()
          : Value(departureAt),
      returnAt: returnAt == null && nullToAbsent
          ? const Value.absent()
          : Value(returnAt),
      requiresPermissionSlip: Value(requiresPermissionSlip),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TripLogistic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripLogistic(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      scheduleBlockId: serializer.fromJson<String>(json['scheduleBlockId']),
      destination: serializer.fromJson<String>(json['destination']),
      destinationAddress: serializer.fromJson<String?>(
        json['destinationAddress'],
      ),
      departureAt: serializer.fromJson<String?>(json['departureAt']),
      returnAt: serializer.fromJson<String?>(json['returnAt']),
      requiresPermissionSlip: serializer.fromJson<int>(
        json['requiresPermissionSlip'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'scheduleBlockId': serializer.toJson<String>(scheduleBlockId),
      'destination': serializer.toJson<String>(destination),
      'destinationAddress': serializer.toJson<String?>(destinationAddress),
      'departureAt': serializer.toJson<String?>(departureAt),
      'returnAt': serializer.toJson<String?>(returnAt),
      'requiresPermissionSlip': serializer.toJson<int>(requiresPermissionSlip),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  TripLogistic copyWith({
    String? id,
    String? spaceId,
    String? scheduleBlockId,
    String? destination,
    Value<String?> destinationAddress = const Value.absent(),
    Value<String?> departureAt = const Value.absent(),
    Value<String?> returnAt = const Value.absent(),
    int? requiresPermissionSlip,
    Value<String?> notes = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => TripLogistic(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    scheduleBlockId: scheduleBlockId ?? this.scheduleBlockId,
    destination: destination ?? this.destination,
    destinationAddress: destinationAddress.present
        ? destinationAddress.value
        : this.destinationAddress,
    departureAt: departureAt.present ? departureAt.value : this.departureAt,
    returnAt: returnAt.present ? returnAt.value : this.returnAt,
    requiresPermissionSlip:
        requiresPermissionSlip ?? this.requiresPermissionSlip,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TripLogistic copyWithCompanion(TripLogisticsCompanion data) {
    return TripLogistic(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      scheduleBlockId: data.scheduleBlockId.present
          ? data.scheduleBlockId.value
          : this.scheduleBlockId,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      destinationAddress: data.destinationAddress.present
          ? data.destinationAddress.value
          : this.destinationAddress,
      departureAt: data.departureAt.present
          ? data.departureAt.value
          : this.departureAt,
      returnAt: data.returnAt.present ? data.returnAt.value : this.returnAt,
      requiresPermissionSlip: data.requiresPermissionSlip.present
          ? data.requiresPermissionSlip.value
          : this.requiresPermissionSlip,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripLogistic(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('scheduleBlockId: $scheduleBlockId, ')
          ..write('destination: $destination, ')
          ..write('destinationAddress: $destinationAddress, ')
          ..write('departureAt: $departureAt, ')
          ..write('returnAt: $returnAt, ')
          ..write('requiresPermissionSlip: $requiresPermissionSlip, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    scheduleBlockId,
    destination,
    destinationAddress,
    departureAt,
    returnAt,
    requiresPermissionSlip,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripLogistic &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.scheduleBlockId == this.scheduleBlockId &&
          other.destination == this.destination &&
          other.destinationAddress == this.destinationAddress &&
          other.departureAt == this.departureAt &&
          other.returnAt == this.returnAt &&
          other.requiresPermissionSlip == this.requiresPermissionSlip &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TripLogisticsCompanion extends UpdateCompanion<TripLogistic> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> scheduleBlockId;
  final Value<String> destination;
  final Value<String?> destinationAddress;
  final Value<String?> departureAt;
  final Value<String?> returnAt;
  final Value<int> requiresPermissionSlip;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const TripLogisticsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.scheduleBlockId = const Value.absent(),
    this.destination = const Value.absent(),
    this.destinationAddress = const Value.absent(),
    this.departureAt = const Value.absent(),
    this.returnAt = const Value.absent(),
    this.requiresPermissionSlip = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripLogisticsCompanion.insert({
    required String id,
    required String spaceId,
    required String scheduleBlockId,
    required String destination,
    this.destinationAddress = const Value.absent(),
    this.departureAt = const Value.absent(),
    this.returnAt = const Value.absent(),
    required int requiresPermissionSlip,
    this.notes = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       scheduleBlockId = Value(scheduleBlockId),
       destination = Value(destination),
       requiresPermissionSlip = Value(requiresPermissionSlip),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TripLogistic> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? scheduleBlockId,
    Expression<String>? destination,
    Expression<String>? destinationAddress,
    Expression<String>? departureAt,
    Expression<String>? returnAt,
    Expression<int>? requiresPermissionSlip,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (scheduleBlockId != null) 'schedule_block_id': scheduleBlockId,
      if (destination != null) 'destination': destination,
      if (destinationAddress != null) 'destination_address': destinationAddress,
      if (departureAt != null) 'departure_at': departureAt,
      if (returnAt != null) 'return_at': returnAt,
      if (requiresPermissionSlip != null)
        'requires_permission_slip': requiresPermissionSlip,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripLogisticsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? scheduleBlockId,
    Value<String>? destination,
    Value<String?>? destinationAddress,
    Value<String?>? departureAt,
    Value<String?>? returnAt,
    Value<int>? requiresPermissionSlip,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return TripLogisticsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      scheduleBlockId: scheduleBlockId ?? this.scheduleBlockId,
      destination: destination ?? this.destination,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      departureAt: departureAt ?? this.departureAt,
      returnAt: returnAt ?? this.returnAt,
      requiresPermissionSlip:
          requiresPermissionSlip ?? this.requiresPermissionSlip,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (scheduleBlockId.present) {
      map['schedule_block_id'] = Variable<String>(scheduleBlockId.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (destinationAddress.present) {
      map['destination_address'] = Variable<String>(destinationAddress.value);
    }
    if (departureAt.present) {
      map['departure_at'] = Variable<String>(departureAt.value);
    }
    if (returnAt.present) {
      map['return_at'] = Variable<String>(returnAt.value);
    }
    if (requiresPermissionSlip.present) {
      map['requires_permission_slip'] = Variable<int>(
        requiresPermissionSlip.value,
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripLogisticsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('scheduleBlockId: $scheduleBlockId, ')
          ..write('destination: $destination, ')
          ..write('destinationAddress: $destinationAddress, ')
          ..write('departureAt: $departureAt, ')
          ..write('returnAt: $returnAt, ')
          ..write('requiresPermissionSlip: $requiresPermissionSlip, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripVehiclesTable extends TripVehicles
    with TableInfo<$TripVehiclesTable, TripVehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripVehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripLogisticsIdMeta = const VerificationMeta(
    'tripLogisticsId',
  );
  @override
  late final GeneratedColumn<String> tripLogisticsId = GeneratedColumn<String>(
    'trip_logistics_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverMemberIdMeta = const VerificationMeta(
    'driverMemberId',
  );
  @override
  late final GeneratedColumn<String> driverMemberId = GeneratedColumn<String>(
    'driver_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manifestMeta = const VerificationMeta(
    'manifest',
  );
  @override
  late final GeneratedColumn<String> manifest = GeneratedColumn<String>(
    'manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    tripLogisticsId,
    vehicleId,
    driverMemberId,
    manifest,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripVehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('trip_logistics_id')) {
      context.handle(
        _tripLogisticsIdMeta,
        tripLogisticsId.isAcceptableOrUnknown(
          data['trip_logistics_id']!,
          _tripLogisticsIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tripLogisticsIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('driver_member_id')) {
      context.handle(
        _driverMemberIdMeta,
        driverMemberId.isAcceptableOrUnknown(
          data['driver_member_id']!,
          _driverMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('manifest')) {
      context.handle(
        _manifestMeta,
        manifest.isAcceptableOrUnknown(data['manifest']!, _manifestMeta),
      );
    } else if (isInserting) {
      context.missing(_manifestMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripVehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripVehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      tripLogisticsId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_logistics_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      driverMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver_member_id'],
      ),
      manifest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TripVehiclesTable createAlias(String alias) {
    return $TripVehiclesTable(attachedDatabase, alias);
  }
}

class TripVehicle extends DataClass implements Insertable<TripVehicle> {
  final String id;
  final String spaceId;
  final String tripLogisticsId;
  final String vehicleId;
  final String? driverMemberId;
  final String manifest;
  final String createdAt;
  final String updatedAt;
  const TripVehicle({
    required this.id,
    required this.spaceId,
    required this.tripLogisticsId,
    required this.vehicleId,
    this.driverMemberId,
    required this.manifest,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['trip_logistics_id'] = Variable<String>(tripLogisticsId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || driverMemberId != null) {
      map['driver_member_id'] = Variable<String>(driverMemberId);
    }
    map['manifest'] = Variable<String>(manifest);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  TripVehiclesCompanion toCompanion(bool nullToAbsent) {
    return TripVehiclesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      tripLogisticsId: Value(tripLogisticsId),
      vehicleId: Value(vehicleId),
      driverMemberId: driverMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(driverMemberId),
      manifest: Value(manifest),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TripVehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripVehicle(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      tripLogisticsId: serializer.fromJson<String>(json['tripLogisticsId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      driverMemberId: serializer.fromJson<String?>(json['driverMemberId']),
      manifest: serializer.fromJson<String>(json['manifest']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'tripLogisticsId': serializer.toJson<String>(tripLogisticsId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'driverMemberId': serializer.toJson<String?>(driverMemberId),
      'manifest': serializer.toJson<String>(manifest),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  TripVehicle copyWith({
    String? id,
    String? spaceId,
    String? tripLogisticsId,
    String? vehicleId,
    Value<String?> driverMemberId = const Value.absent(),
    String? manifest,
    String? createdAt,
    String? updatedAt,
  }) => TripVehicle(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    tripLogisticsId: tripLogisticsId ?? this.tripLogisticsId,
    vehicleId: vehicleId ?? this.vehicleId,
    driverMemberId: driverMemberId.present
        ? driverMemberId.value
        : this.driverMemberId,
    manifest: manifest ?? this.manifest,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TripVehicle copyWithCompanion(TripVehiclesCompanion data) {
    return TripVehicle(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      tripLogisticsId: data.tripLogisticsId.present
          ? data.tripLogisticsId.value
          : this.tripLogisticsId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      driverMemberId: data.driverMemberId.present
          ? data.driverMemberId.value
          : this.driverMemberId,
      manifest: data.manifest.present ? data.manifest.value : this.manifest,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripVehicle(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('tripLogisticsId: $tripLogisticsId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('driverMemberId: $driverMemberId, ')
          ..write('manifest: $manifest, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    tripLogisticsId,
    vehicleId,
    driverMemberId,
    manifest,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripVehicle &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.tripLogisticsId == this.tripLogisticsId &&
          other.vehicleId == this.vehicleId &&
          other.driverMemberId == this.driverMemberId &&
          other.manifest == this.manifest &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TripVehiclesCompanion extends UpdateCompanion<TripVehicle> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> tripLogisticsId;
  final Value<String> vehicleId;
  final Value<String?> driverMemberId;
  final Value<String> manifest;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const TripVehiclesCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.tripLogisticsId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.driverMemberId = const Value.absent(),
    this.manifest = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripVehiclesCompanion.insert({
    required String id,
    required String spaceId,
    required String tripLogisticsId,
    required String vehicleId,
    this.driverMemberId = const Value.absent(),
    required String manifest,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       tripLogisticsId = Value(tripLogisticsId),
       vehicleId = Value(vehicleId),
       manifest = Value(manifest),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TripVehicle> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? tripLogisticsId,
    Expression<String>? vehicleId,
    Expression<String>? driverMemberId,
    Expression<String>? manifest,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (tripLogisticsId != null) 'trip_logistics_id': tripLogisticsId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (driverMemberId != null) 'driver_member_id': driverMemberId,
      if (manifest != null) 'manifest': manifest,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripVehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? tripLogisticsId,
    Value<String>? vehicleId,
    Value<String?>? driverMemberId,
    Value<String>? manifest,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return TripVehiclesCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      tripLogisticsId: tripLogisticsId ?? this.tripLogisticsId,
      vehicleId: vehicleId ?? this.vehicleId,
      driverMemberId: driverMemberId ?? this.driverMemberId,
      manifest: manifest ?? this.manifest,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (tripLogisticsId.present) {
      map['trip_logistics_id'] = Variable<String>(tripLogisticsId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (driverMemberId.present) {
      map['driver_member_id'] = Variable<String>(driverMemberId.value);
    }
    if (manifest.present) {
      map['manifest'] = Variable<String>(manifest.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripVehiclesCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('tripLogisticsId: $tripLogisticsId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('driverMemberId: $driverMemberId, ')
          ..write('manifest: $manifest, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PermissionSlipsTable extends PermissionSlips
    with TableInfo<$PermissionSlipsTable, PermissionSlip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PermissionSlipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripLogisticsIdMeta = const VerificationMeta(
    'tripLogisticsId',
  );
  @override
  late final GeneratedColumn<String> tripLogisticsId = GeneratedColumn<String>(
    'trip_logistics_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signerGuardianIdMeta = const VerificationMeta(
    'signerGuardianId',
  );
  @override
  late final GeneratedColumn<String> signerGuardianId = GeneratedColumn<String>(
    'signer_guardian_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signerNameMeta = const VerificationMeta(
    'signerName',
  );
  @override
  late final GeneratedColumn<String> signerName = GeneratedColumn<String>(
    'signer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signedAtMeta = const VerificationMeta(
    'signedAt',
  );
  @override
  late final GeneratedColumn<String> signedAt = GeneratedColumn<String>(
    'signed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    subjectId,
    tripLogisticsId,
    signerGuardianId,
    signerName,
    signedAt,
    sourceUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'permission_slips';
  @override
  VerificationContext validateIntegrity(
    Insertable<PermissionSlip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('trip_logistics_id')) {
      context.handle(
        _tripLogisticsIdMeta,
        tripLogisticsId.isAcceptableOrUnknown(
          data['trip_logistics_id']!,
          _tripLogisticsIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tripLogisticsIdMeta);
    }
    if (data.containsKey('signer_guardian_id')) {
      context.handle(
        _signerGuardianIdMeta,
        signerGuardianId.isAcceptableOrUnknown(
          data['signer_guardian_id']!,
          _signerGuardianIdMeta,
        ),
      );
    }
    if (data.containsKey('signer_name')) {
      context.handle(
        _signerNameMeta,
        signerName.isAcceptableOrUnknown(data['signer_name']!, _signerNameMeta),
      );
    }
    if (data.containsKey('signed_at')) {
      context.handle(
        _signedAtMeta,
        signedAt.isAcceptableOrUnknown(data['signed_at']!, _signedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_signedAtMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PermissionSlip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PermissionSlip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      tripLogisticsId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_logistics_id'],
      )!,
      signerGuardianId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_guardian_id'],
      ),
      signerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_name'],
      ),
      signedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signed_at'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PermissionSlipsTable createAlias(String alias) {
    return $PermissionSlipsTable(attachedDatabase, alias);
  }
}

class PermissionSlip extends DataClass implements Insertable<PermissionSlip> {
  final String id;
  final String spaceId;
  final String subjectId;
  final String tripLogisticsId;
  final String? signerGuardianId;
  final String? signerName;
  final String signedAt;
  final String? sourceUrl;
  final String createdAt;
  final String updatedAt;
  const PermissionSlip({
    required this.id,
    required this.spaceId,
    required this.subjectId,
    required this.tripLogisticsId,
    this.signerGuardianId,
    this.signerName,
    required this.signedAt,
    this.sourceUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['subject_id'] = Variable<String>(subjectId);
    map['trip_logistics_id'] = Variable<String>(tripLogisticsId);
    if (!nullToAbsent || signerGuardianId != null) {
      map['signer_guardian_id'] = Variable<String>(signerGuardianId);
    }
    if (!nullToAbsent || signerName != null) {
      map['signer_name'] = Variable<String>(signerName);
    }
    map['signed_at'] = Variable<String>(signedAt);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  PermissionSlipsCompanion toCompanion(bool nullToAbsent) {
    return PermissionSlipsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      subjectId: Value(subjectId),
      tripLogisticsId: Value(tripLogisticsId),
      signerGuardianId: signerGuardianId == null && nullToAbsent
          ? const Value.absent()
          : Value(signerGuardianId),
      signerName: signerName == null && nullToAbsent
          ? const Value.absent()
          : Value(signerName),
      signedAt: Value(signedAt),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PermissionSlip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PermissionSlip(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      tripLogisticsId: serializer.fromJson<String>(json['tripLogisticsId']),
      signerGuardianId: serializer.fromJson<String?>(json['signerGuardianId']),
      signerName: serializer.fromJson<String?>(json['signerName']),
      signedAt: serializer.fromJson<String>(json['signedAt']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'subjectId': serializer.toJson<String>(subjectId),
      'tripLogisticsId': serializer.toJson<String>(tripLogisticsId),
      'signerGuardianId': serializer.toJson<String?>(signerGuardianId),
      'signerName': serializer.toJson<String?>(signerName),
      'signedAt': serializer.toJson<String>(signedAt),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  PermissionSlip copyWith({
    String? id,
    String? spaceId,
    String? subjectId,
    String? tripLogisticsId,
    Value<String?> signerGuardianId = const Value.absent(),
    Value<String?> signerName = const Value.absent(),
    String? signedAt,
    Value<String?> sourceUrl = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => PermissionSlip(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    subjectId: subjectId ?? this.subjectId,
    tripLogisticsId: tripLogisticsId ?? this.tripLogisticsId,
    signerGuardianId: signerGuardianId.present
        ? signerGuardianId.value
        : this.signerGuardianId,
    signerName: signerName.present ? signerName.value : this.signerName,
    signedAt: signedAt ?? this.signedAt,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PermissionSlip copyWithCompanion(PermissionSlipsCompanion data) {
    return PermissionSlip(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      tripLogisticsId: data.tripLogisticsId.present
          ? data.tripLogisticsId.value
          : this.tripLogisticsId,
      signerGuardianId: data.signerGuardianId.present
          ? data.signerGuardianId.value
          : this.signerGuardianId,
      signerName: data.signerName.present
          ? data.signerName.value
          : this.signerName,
      signedAt: data.signedAt.present ? data.signedAt.value : this.signedAt,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PermissionSlip(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('subjectId: $subjectId, ')
          ..write('tripLogisticsId: $tripLogisticsId, ')
          ..write('signerGuardianId: $signerGuardianId, ')
          ..write('signerName: $signerName, ')
          ..write('signedAt: $signedAt, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    subjectId,
    tripLogisticsId,
    signerGuardianId,
    signerName,
    signedAt,
    sourceUrl,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionSlip &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.subjectId == this.subjectId &&
          other.tripLogisticsId == this.tripLogisticsId &&
          other.signerGuardianId == this.signerGuardianId &&
          other.signerName == this.signerName &&
          other.signedAt == this.signedAt &&
          other.sourceUrl == this.sourceUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PermissionSlipsCompanion extends UpdateCompanion<PermissionSlip> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> subjectId;
  final Value<String> tripLogisticsId;
  final Value<String?> signerGuardianId;
  final Value<String?> signerName;
  final Value<String> signedAt;
  final Value<String?> sourceUrl;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const PermissionSlipsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.tripLogisticsId = const Value.absent(),
    this.signerGuardianId = const Value.absent(),
    this.signerName = const Value.absent(),
    this.signedAt = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PermissionSlipsCompanion.insert({
    required String id,
    required String spaceId,
    required String subjectId,
    required String tripLogisticsId,
    this.signerGuardianId = const Value.absent(),
    this.signerName = const Value.absent(),
    required String signedAt,
    this.sourceUrl = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       subjectId = Value(subjectId),
       tripLogisticsId = Value(tripLogisticsId),
       signedAt = Value(signedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PermissionSlip> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? subjectId,
    Expression<String>? tripLogisticsId,
    Expression<String>? signerGuardianId,
    Expression<String>? signerName,
    Expression<String>? signedAt,
    Expression<String>? sourceUrl,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (subjectId != null) 'subject_id': subjectId,
      if (tripLogisticsId != null) 'trip_logistics_id': tripLogisticsId,
      if (signerGuardianId != null) 'signer_guardian_id': signerGuardianId,
      if (signerName != null) 'signer_name': signerName,
      if (signedAt != null) 'signed_at': signedAt,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PermissionSlipsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? subjectId,
    Value<String>? tripLogisticsId,
    Value<String?>? signerGuardianId,
    Value<String?>? signerName,
    Value<String>? signedAt,
    Value<String?>? sourceUrl,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return PermissionSlipsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      subjectId: subjectId ?? this.subjectId,
      tripLogisticsId: tripLogisticsId ?? this.tripLogisticsId,
      signerGuardianId: signerGuardianId ?? this.signerGuardianId,
      signerName: signerName ?? this.signerName,
      signedAt: signedAt ?? this.signedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (tripLogisticsId.present) {
      map['trip_logistics_id'] = Variable<String>(tripLogisticsId.value);
    }
    if (signerGuardianId.present) {
      map['signer_guardian_id'] = Variable<String>(signerGuardianId.value);
    }
    if (signerName.present) {
      map['signer_name'] = Variable<String>(signerName.value);
    }
    if (signedAt.present) {
      map['signed_at'] = Variable<String>(signedAt.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PermissionSlipsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('subjectId: $subjectId, ')
          ..write('tripLogisticsId: $tripLogisticsId, ')
          ..write('signerGuardianId: $signerGuardianId, ')
          ..write('signerName: $signerName, ')
          ..write('signedAt: $signedAt, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeadcountsTable extends Headcounts
    with TableInfo<$HeadcountsTable, Headcount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeadcountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleBlockIdMeta = const VerificationMeta(
    'scheduleBlockId',
  );
  @override
  late final GeneratedColumn<String> scheduleBlockId = GeneratedColumn<String>(
    'schedule_block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkpointLabelMeta = const VerificationMeta(
    'checkpointLabel',
  );
  @override
  late final GeneratedColumn<String> checkpointLabel = GeneratedColumn<String>(
    'checkpoint_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedCountMeta = const VerificationMeta(
    'expectedCount',
  );
  @override
  late final GeneratedColumn<int> expectedCount = GeneratedColumn<int>(
    'expected_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _takenByMemberIdMeta = const VerificationMeta(
    'takenByMemberId',
  );
  @override
  late final GeneratedColumn<String> takenByMemberId = GeneratedColumn<String>(
    'taken_by_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<String> takenAt = GeneratedColumn<String>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    spaceId,
    scheduleBlockId,
    checkpointLabel,
    count,
    expectedCount,
    takenByMemberId,
    takenAt,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'headcounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Headcount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('schedule_block_id')) {
      context.handle(
        _scheduleBlockIdMeta,
        scheduleBlockId.isAcceptableOrUnknown(
          data['schedule_block_id']!,
          _scheduleBlockIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleBlockIdMeta);
    }
    if (data.containsKey('checkpoint_label')) {
      context.handle(
        _checkpointLabelMeta,
        checkpointLabel.isAcceptableOrUnknown(
          data['checkpoint_label']!,
          _checkpointLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkpointLabelMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('expected_count')) {
      context.handle(
        _expectedCountMeta,
        expectedCount.isAcceptableOrUnknown(
          data['expected_count']!,
          _expectedCountMeta,
        ),
      );
    }
    if (data.containsKey('taken_by_member_id')) {
      context.handle(
        _takenByMemberIdMeta,
        takenByMemberId.isAcceptableOrUnknown(
          data['taken_by_member_id']!,
          _takenByMemberIdMeta,
        ),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Headcount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Headcount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      scheduleBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_block_id'],
      )!,
      checkpointLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint_label'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      expectedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_count'],
      ),
      takenByMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}taken_by_member_id'],
      ),
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}taken_at'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HeadcountsTable createAlias(String alias) {
    return $HeadcountsTable(attachedDatabase, alias);
  }
}

class Headcount extends DataClass implements Insertable<Headcount> {
  final String id;
  final String spaceId;
  final String scheduleBlockId;
  final String checkpointLabel;
  final int count;
  final int? expectedCount;
  final String? takenByMemberId;
  final String takenAt;
  final String? notes;
  final String createdAt;
  const Headcount({
    required this.id,
    required this.spaceId,
    required this.scheduleBlockId,
    required this.checkpointLabel,
    required this.count,
    this.expectedCount,
    this.takenByMemberId,
    required this.takenAt,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['space_id'] = Variable<String>(spaceId);
    map['schedule_block_id'] = Variable<String>(scheduleBlockId);
    map['checkpoint_label'] = Variable<String>(checkpointLabel);
    map['count'] = Variable<int>(count);
    if (!nullToAbsent || expectedCount != null) {
      map['expected_count'] = Variable<int>(expectedCount);
    }
    if (!nullToAbsent || takenByMemberId != null) {
      map['taken_by_member_id'] = Variable<String>(takenByMemberId);
    }
    map['taken_at'] = Variable<String>(takenAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  HeadcountsCompanion toCompanion(bool nullToAbsent) {
    return HeadcountsCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      scheduleBlockId: Value(scheduleBlockId),
      checkpointLabel: Value(checkpointLabel),
      count: Value(count),
      expectedCount: expectedCount == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCount),
      takenByMemberId: takenByMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(takenByMemberId),
      takenAt: Value(takenAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Headcount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Headcount(
      id: serializer.fromJson<String>(json['id']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      scheduleBlockId: serializer.fromJson<String>(json['scheduleBlockId']),
      checkpointLabel: serializer.fromJson<String>(json['checkpointLabel']),
      count: serializer.fromJson<int>(json['count']),
      expectedCount: serializer.fromJson<int?>(json['expectedCount']),
      takenByMemberId: serializer.fromJson<String?>(json['takenByMemberId']),
      takenAt: serializer.fromJson<String>(json['takenAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'spaceId': serializer.toJson<String>(spaceId),
      'scheduleBlockId': serializer.toJson<String>(scheduleBlockId),
      'checkpointLabel': serializer.toJson<String>(checkpointLabel),
      'count': serializer.toJson<int>(count),
      'expectedCount': serializer.toJson<int?>(expectedCount),
      'takenByMemberId': serializer.toJson<String?>(takenByMemberId),
      'takenAt': serializer.toJson<String>(takenAt),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Headcount copyWith({
    String? id,
    String? spaceId,
    String? scheduleBlockId,
    String? checkpointLabel,
    int? count,
    Value<int?> expectedCount = const Value.absent(),
    Value<String?> takenByMemberId = const Value.absent(),
    String? takenAt,
    Value<String?> notes = const Value.absent(),
    String? createdAt,
  }) => Headcount(
    id: id ?? this.id,
    spaceId: spaceId ?? this.spaceId,
    scheduleBlockId: scheduleBlockId ?? this.scheduleBlockId,
    checkpointLabel: checkpointLabel ?? this.checkpointLabel,
    count: count ?? this.count,
    expectedCount: expectedCount.present
        ? expectedCount.value
        : this.expectedCount,
    takenByMemberId: takenByMemberId.present
        ? takenByMemberId.value
        : this.takenByMemberId,
    takenAt: takenAt ?? this.takenAt,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  Headcount copyWithCompanion(HeadcountsCompanion data) {
    return Headcount(
      id: data.id.present ? data.id.value : this.id,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      scheduleBlockId: data.scheduleBlockId.present
          ? data.scheduleBlockId.value
          : this.scheduleBlockId,
      checkpointLabel: data.checkpointLabel.present
          ? data.checkpointLabel.value
          : this.checkpointLabel,
      count: data.count.present ? data.count.value : this.count,
      expectedCount: data.expectedCount.present
          ? data.expectedCount.value
          : this.expectedCount,
      takenByMemberId: data.takenByMemberId.present
          ? data.takenByMemberId.value
          : this.takenByMemberId,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Headcount(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('scheduleBlockId: $scheduleBlockId, ')
          ..write('checkpointLabel: $checkpointLabel, ')
          ..write('count: $count, ')
          ..write('expectedCount: $expectedCount, ')
          ..write('takenByMemberId: $takenByMemberId, ')
          ..write('takenAt: $takenAt, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    spaceId,
    scheduleBlockId,
    checkpointLabel,
    count,
    expectedCount,
    takenByMemberId,
    takenAt,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Headcount &&
          other.id == this.id &&
          other.spaceId == this.spaceId &&
          other.scheduleBlockId == this.scheduleBlockId &&
          other.checkpointLabel == this.checkpointLabel &&
          other.count == this.count &&
          other.expectedCount == this.expectedCount &&
          other.takenByMemberId == this.takenByMemberId &&
          other.takenAt == this.takenAt &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class HeadcountsCompanion extends UpdateCompanion<Headcount> {
  final Value<String> id;
  final Value<String> spaceId;
  final Value<String> scheduleBlockId;
  final Value<String> checkpointLabel;
  final Value<int> count;
  final Value<int?> expectedCount;
  final Value<String?> takenByMemberId;
  final Value<String> takenAt;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<int> rowid;
  const HeadcountsCompanion({
    this.id = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.scheduleBlockId = const Value.absent(),
    this.checkpointLabel = const Value.absent(),
    this.count = const Value.absent(),
    this.expectedCount = const Value.absent(),
    this.takenByMemberId = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeadcountsCompanion.insert({
    required String id,
    required String spaceId,
    required String scheduleBlockId,
    required String checkpointLabel,
    required int count,
    this.expectedCount = const Value.absent(),
    this.takenByMemberId = const Value.absent(),
    required String takenAt,
    this.notes = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       spaceId = Value(spaceId),
       scheduleBlockId = Value(scheduleBlockId),
       checkpointLabel = Value(checkpointLabel),
       count = Value(count),
       takenAt = Value(takenAt),
       createdAt = Value(createdAt);
  static Insertable<Headcount> custom({
    Expression<String>? id,
    Expression<String>? spaceId,
    Expression<String>? scheduleBlockId,
    Expression<String>? checkpointLabel,
    Expression<int>? count,
    Expression<int>? expectedCount,
    Expression<String>? takenByMemberId,
    Expression<String>? takenAt,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spaceId != null) 'space_id': spaceId,
      if (scheduleBlockId != null) 'schedule_block_id': scheduleBlockId,
      if (checkpointLabel != null) 'checkpoint_label': checkpointLabel,
      if (count != null) 'count': count,
      if (expectedCount != null) 'expected_count': expectedCount,
      if (takenByMemberId != null) 'taken_by_member_id': takenByMemberId,
      if (takenAt != null) 'taken_at': takenAt,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeadcountsCompanion copyWith({
    Value<String>? id,
    Value<String>? spaceId,
    Value<String>? scheduleBlockId,
    Value<String>? checkpointLabel,
    Value<int>? count,
    Value<int?>? expectedCount,
    Value<String?>? takenByMemberId,
    Value<String>? takenAt,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return HeadcountsCompanion(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      scheduleBlockId: scheduleBlockId ?? this.scheduleBlockId,
      checkpointLabel: checkpointLabel ?? this.checkpointLabel,
      count: count ?? this.count,
      expectedCount: expectedCount ?? this.expectedCount,
      takenByMemberId: takenByMemberId ?? this.takenByMemberId,
      takenAt: takenAt ?? this.takenAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (scheduleBlockId.present) {
      map['schedule_block_id'] = Variable<String>(scheduleBlockId.value);
    }
    if (checkpointLabel.present) {
      map['checkpoint_label'] = Variable<String>(checkpointLabel.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (expectedCount.present) {
      map['expected_count'] = Variable<int>(expectedCount.value);
    }
    if (takenByMemberId.present) {
      map['taken_by_member_id'] = Variable<String>(takenByMemberId.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<String>(takenAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeadcountsCompanion(')
          ..write('id: $id, ')
          ..write('spaceId: $spaceId, ')
          ..write('scheduleBlockId: $scheduleBlockId, ')
          ..write('checkpointLabel: $checkpointLabel, ')
          ..write('count: $count, ')
          ..write('expectedCount: $expectedCount, ')
          ..write('takenByMemberId: $takenByMemberId, ')
          ..write('takenAt: $takenAt, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpacesTable spaces = $SpacesTable(this);
  late final $MembersTable members = $MembersTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $SubjectsTable subjects = $SubjectsTable(this);
  late final $AttendanceRecordsTable attendanceRecords =
      $AttendanceRecordsTable(this);
  late final $InvitesTable invites = $InvitesTable(this);
  late final $GroupMembersTable groupMembers = $GroupMembersTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $GuardiansTable guardians = $GuardiansTable(this);
  late final $SubjectGuardiansTable subjectGuardians = $SubjectGuardiansTable(
    this,
  );
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $VehicleLogsTable vehicleLogs = $VehicleLogsTable(this);
  late final $MemberCertificationsTable memberCertifications =
      $MemberCertificationsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $SurveyResponsesTable surveyResponses = $SurveyResponsesTable(
    this,
  );
  late final $DismissedInsightsTable dismissedInsights =
      $DismissedInsightsTable(this);
  late final $CapturesTable captures = $CapturesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ExportsTable exports = $ExportsTable(this);
  late final $ExportRecipientsTable exportRecipients = $ExportRecipientsTable(
    this,
  );
  late final $LocationsTable locations = $LocationsTable(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $ScheduleBlocksTable scheduleBlocks = $ScheduleBlocksTable(this);
  late final $TripLogisticsTable tripLogistics = $TripLogisticsTable(this);
  late final $TripVehiclesTable tripVehicles = $TripVehiclesTable(this);
  late final $PermissionSlipsTable permissionSlips = $PermissionSlipsTable(
    this,
  );
  late final $HeadcountsTable headcounts = $HeadcountsTable(this);
  late final AttachmentsDao attachmentsDao = AttachmentsDao(
    this as AppDatabase,
  );
  late final AttendanceDao attendanceDao = AttendanceDao(this as AppDatabase);
  late final CapturesDao capturesDao = CapturesDao(this as AppDatabase);
  late final CertificationsDao certificationsDao = CertificationsDao(
    this as AppDatabase,
  );
  late final DismissedInsightsDao dismissedInsightsDao = DismissedInsightsDao(
    this as AppDatabase,
  );
  late final EntriesDao entriesDao = EntriesDao(this as AppDatabase);
  late final ExportsDao exportsDao = ExportsDao(this as AppDatabase);
  late final GroupMembersDao groupMembersDao = GroupMembersDao(
    this as AppDatabase,
  );
  late final GroupsDao groupsDao = GroupsDao(this as AppDatabase);
  late final GuardiansDao guardiansDao = GuardiansDao(this as AppDatabase);
  late final InvitesDao invitesDao = InvitesDao(this as AppDatabase);
  late final MembersDao membersDao = MembersDao(this as AppDatabase);
  late final MessagesDao messagesDao = MessagesDao(this as AppDatabase);
  late final SpacesDao spacesDao = SpacesDao(this as AppDatabase);
  late final SubjectsDao subjectsDao = SubjectsDao(this as AppDatabase);
  late final SurveysDao surveysDao = SurveysDao(this as AppDatabase);
  late final TasksDao tasksDao = TasksDao(this as AppDatabase);
  late final VehiclesDao vehiclesDao = VehiclesDao(this as AppDatabase);
  late final LocationsDao locationsDao = LocationsDao(this as AppDatabase);
  late final ActivitiesDao activitiesDao = ActivitiesDao(this as AppDatabase);
  late final ScheduleDao scheduleDao = ScheduleDao(this as AppDatabase);
  late final TripsDao tripsDao = TripsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    spaces,
    members,
    groups,
    subjects,
    attendanceRecords,
    invites,
    groupMembers,
    entries,
    guardians,
    subjectGuardians,
    vehicles,
    vehicleLogs,
    memberCertifications,
    attachments,
    surveyResponses,
    dismissedInsights,
    captures,
    tasks,
    messages,
    exports,
    exportRecipients,
    locations,
    activities,
    scheduleBlocks,
    tripLogistics,
    tripVehicles,
    permissionSlips,
    headcounts,
  ];
}

typedef $$SpacesTableCreateCompanionBuilder =
    SpacesCompanion Function({
      required String id,
      required String name,
      Value<String?> slug,
      required String settings,
      required String capabilities,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$SpacesTableUpdateCompanionBuilder =
    SpacesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> slug,
      Value<String> settings,
      Value<String> capabilities,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$SpacesTableFilterComposer
    extends Composer<_$AppDatabase, $SpacesTable> {
  $$SpacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settings => $composableBuilder(
    column: $table.settings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpacesTableOrderingComposer
    extends Composer<_$AppDatabase, $SpacesTable> {
  $$SpacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settings => $composableBuilder(
    column: $table.settings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpacesTable> {
  $$SpacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get settings =>
      $composableBuilder(column: $table.settings, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SpacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpacesTable,
          Space,
          $$SpacesTableFilterComposer,
          $$SpacesTableOrderingComposer,
          $$SpacesTableAnnotationComposer,
          $$SpacesTableCreateCompanionBuilder,
          $$SpacesTableUpdateCompanionBuilder,
          (Space, BaseReferences<_$AppDatabase, $SpacesTable, Space>),
          Space,
          PrefetchHooks Function()
        > {
  $$SpacesTableTableManager(_$AppDatabase db, $SpacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<String> settings = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpacesCompanion(
                id: id,
                name: name,
                slug: slug,
                settings: settings,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> slug = const Value.absent(),
                required String settings,
                required String capabilities,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SpacesCompanion.insert(
                id: id,
                name: name,
                slug: slug,
                settings: settings,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpacesTable,
      Space,
      $$SpacesTableFilterComposer,
      $$SpacesTableOrderingComposer,
      $$SpacesTableAnnotationComposer,
      $$SpacesTableCreateCompanionBuilder,
      $$SpacesTableUpdateCompanionBuilder,
      (Space, BaseReferences<_$AppDatabase, $SpacesTable, Space>),
      Space,
      PrefetchHooks Function()
    >;
typedef $$MembersTableCreateCompanionBuilder =
    MembersCompanion Function({
      required String id,
      Value<String?> spaceId,
      required String displayName,
      required String role,
      Value<String?> avatarUrl,
      required String capabilities,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$MembersTableUpdateCompanionBuilder =
    MembersCompanion Function({
      Value<String> id,
      Value<String?> spaceId,
      Value<String> displayName,
      Value<String> role,
      Value<String?> avatarUrl,
      Value<String> capabilities,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$MembersTableFilterComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MembersTableOrderingComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MembersTable> {
  $$MembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MembersTable,
          Member,
          $$MembersTableFilterComposer,
          $$MembersTableOrderingComposer,
          $$MembersTableAnnotationComposer,
          $$MembersTableCreateCompanionBuilder,
          $$MembersTableUpdateCompanionBuilder,
          (Member, BaseReferences<_$AppDatabase, $MembersTable, Member>),
          Member,
          PrefetchHooks Function()
        > {
  $$MembersTableTableManager(_$AppDatabase db, $MembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> spaceId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion(
                id: id,
                spaceId: spaceId,
                displayName: displayName,
                role: role,
                avatarUrl: avatarUrl,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> spaceId = const Value.absent(),
                required String displayName,
                required String role,
                Value<String?> avatarUrl = const Value.absent(),
                required String capabilities,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MembersCompanion.insert(
                id: id,
                spaceId: spaceId,
                displayName: displayName,
                role: role,
                avatarUrl: avatarUrl,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MembersTable,
      Member,
      $$MembersTableFilterComposer,
      $$MembersTableOrderingComposer,
      $$MembersTableAnnotationComposer,
      $$MembersTableCreateCompanionBuilder,
      $$MembersTableUpdateCompanionBuilder,
      (Member, BaseReferences<_$AppDatabase, $MembersTable, Member>),
      Member,
      PrefetchHooks Function()
    >;
typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      required String id,
      required String spaceId,
      required String name,
      Value<String?> ageRange,
      Value<String?> color,
      required String capabilities,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> name,
      Value<String?> ageRange,
      Value<String?> color,
      Value<String> capabilities,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ageRange => $composableBuilder(
    column: $table.ageRange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageRange => $composableBuilder(
    column: $table.ageRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ageRange =>
      $composableBuilder(column: $table.ageRange, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
          Group,
          PrefetchHooks Function()
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> ageRange = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                spaceId: spaceId,
                name: name,
                ageRange: ageRange,
                color: color,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String name,
                Value<String?> ageRange = const Value.absent(),
                Value<String?> color = const Value.absent(),
                required String capabilities,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                spaceId: spaceId,
                name: name,
                ageRange: ageRange,
                color: color,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
      Group,
      PrefetchHooks Function()
    >;
typedef $$SubjectsTableCreateCompanionBuilder =
    SubjectsCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> groupId,
      required String firstName,
      required String lastName,
      Value<String?> dob,
      Value<String?> photoUrl,
      Value<String?> allergies,
      Value<String?> notes,
      required String capabilities,
      Value<String?> dropoffWindowStart,
      Value<String?> dropoffWindowEnd,
      Value<String?> pickupWindowStart,
      Value<String?> pickupWindowEnd,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$SubjectsTableUpdateCompanionBuilder =
    SubjectsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> groupId,
      Value<String> firstName,
      Value<String> lastName,
      Value<String?> dob,
      Value<String?> photoUrl,
      Value<String?> allergies,
      Value<String?> notes,
      Value<String> capabilities,
      Value<String?> dropoffWindowStart,
      Value<String?> dropoffWindowEnd,
      Value<String?> pickupWindowStart,
      Value<String?> pickupWindowEnd,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$SubjectsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dob => $composableBuilder(
    column: $table.dob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allergies => $composableBuilder(
    column: $table.allergies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dropoffWindowStart => $composableBuilder(
    column: $table.dropoffWindowStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dropoffWindowEnd => $composableBuilder(
    column: $table.dropoffWindowEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pickupWindowStart => $composableBuilder(
    column: $table.pickupWindowStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pickupWindowEnd => $composableBuilder(
    column: $table.pickupWindowEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dob => $composableBuilder(
    column: $table.dob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allergies => $composableBuilder(
    column: $table.allergies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dropoffWindowStart => $composableBuilder(
    column: $table.dropoffWindowStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dropoffWindowEnd => $composableBuilder(
    column: $table.dropoffWindowEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pickupWindowStart => $composableBuilder(
    column: $table.pickupWindowStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pickupWindowEnd => $composableBuilder(
    column: $table.pickupWindowEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectsTable> {
  $$SubjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get dob =>
      $composableBuilder(column: $table.dob, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get allergies =>
      $composableBuilder(column: $table.allergies, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dropoffWindowStart => $composableBuilder(
    column: $table.dropoffWindowStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dropoffWindowEnd => $composableBuilder(
    column: $table.dropoffWindowEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pickupWindowStart => $composableBuilder(
    column: $table.pickupWindowStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pickupWindowEnd => $composableBuilder(
    column: $table.pickupWindowEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SubjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectsTable,
          Subject,
          $$SubjectsTableFilterComposer,
          $$SubjectsTableOrderingComposer,
          $$SubjectsTableAnnotationComposer,
          $$SubjectsTableCreateCompanionBuilder,
          $$SubjectsTableUpdateCompanionBuilder,
          (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
          Subject,
          PrefetchHooks Function()
        > {
  $$SubjectsTableTableManager(_$AppDatabase db, $SubjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String?> dob = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String?> allergies = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String?> dropoffWindowStart = const Value.absent(),
                Value<String?> dropoffWindowEnd = const Value.absent(),
                Value<String?> pickupWindowStart = const Value.absent(),
                Value<String?> pickupWindowEnd = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                firstName: firstName,
                lastName: lastName,
                dob: dob,
                photoUrl: photoUrl,
                allergies: allergies,
                notes: notes,
                capabilities: capabilities,
                dropoffWindowStart: dropoffWindowStart,
                dropoffWindowEnd: dropoffWindowEnd,
                pickupWindowStart: pickupWindowStart,
                pickupWindowEnd: pickupWindowEnd,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> groupId = const Value.absent(),
                required String firstName,
                required String lastName,
                Value<String?> dob = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String?> allergies = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String capabilities,
                Value<String?> dropoffWindowStart = const Value.absent(),
                Value<String?> dropoffWindowEnd = const Value.absent(),
                Value<String?> pickupWindowStart = const Value.absent(),
                Value<String?> pickupWindowEnd = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SubjectsCompanion.insert(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                firstName: firstName,
                lastName: lastName,
                dob: dob,
                photoUrl: photoUrl,
                allergies: allergies,
                notes: notes,
                capabilities: capabilities,
                dropoffWindowStart: dropoffWindowStart,
                dropoffWindowEnd: dropoffWindowEnd,
                pickupWindowStart: pickupWindowStart,
                pickupWindowEnd: pickupWindowEnd,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectsTable,
      Subject,
      $$SubjectsTableFilterComposer,
      $$SubjectsTableOrderingComposer,
      $$SubjectsTableAnnotationComposer,
      $$SubjectsTableCreateCompanionBuilder,
      $$SubjectsTableUpdateCompanionBuilder,
      (Subject, BaseReferences<_$AppDatabase, $SubjectsTable, Subject>),
      Subject,
      PrefetchHooks Function()
    >;
typedef $$AttendanceRecordsTableCreateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> groupId,
      required String subjectId,
      required String date,
      required String status,
      Value<String?> notes,
      required String recordedBy,
      required String recordedAt,
      required String updatedAt,
      Value<String?> lastUpdatedBy,
      Value<int> rowid,
    });
typedef $$AttendanceRecordsTableUpdateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> groupId,
      Value<String> subjectId,
      Value<String> date,
      Value<String> status,
      Value<String?> notes,
      Value<String> recordedBy,
      Value<String> recordedAt,
      Value<String> updatedAt,
      Value<String?> lastUpdatedBy,
      Value<int> rowid,
    });

class $$AttendanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUpdatedBy => $composableBuilder(
    column: $table.lastUpdatedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttendanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUpdatedBy => $composableBuilder(
    column: $table.lastUpdatedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttendanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get lastUpdatedBy => $composableBuilder(
    column: $table.lastUpdatedBy,
    builder: (column) => column,
  );
}

class $$AttendanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceRecordsTable,
          AttendanceRecord,
          $$AttendanceRecordsTableFilterComposer,
          $$AttendanceRecordsTableOrderingComposer,
          $$AttendanceRecordsTableAnnotationComposer,
          $$AttendanceRecordsTableCreateCompanionBuilder,
          $$AttendanceRecordsTableUpdateCompanionBuilder,
          (
            AttendanceRecord,
            BaseReferences<
              _$AppDatabase,
              $AttendanceRecordsTable,
              AttendanceRecord
            >,
          ),
          AttendanceRecord,
          PrefetchHooks Function()
        > {
  $$AttendanceRecordsTableTableManager(
    _$AppDatabase db,
    $AttendanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> recordedBy = const Value.absent(),
                Value<String> recordedAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> lastUpdatedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttendanceRecordsCompanion(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                subjectId: subjectId,
                date: date,
                status: status,
                notes: notes,
                recordedBy: recordedBy,
                recordedAt: recordedAt,
                updatedAt: updatedAt,
                lastUpdatedBy: lastUpdatedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> groupId = const Value.absent(),
                required String subjectId,
                required String date,
                required String status,
                Value<String?> notes = const Value.absent(),
                required String recordedBy,
                required String recordedAt,
                required String updatedAt,
                Value<String?> lastUpdatedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttendanceRecordsCompanion.insert(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                subjectId: subjectId,
                date: date,
                status: status,
                notes: notes,
                recordedBy: recordedBy,
                recordedAt: recordedAt,
                updatedAt: updatedAt,
                lastUpdatedBy: lastUpdatedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttendanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceRecordsTable,
      AttendanceRecord,
      $$AttendanceRecordsTableFilterComposer,
      $$AttendanceRecordsTableOrderingComposer,
      $$AttendanceRecordsTableAnnotationComposer,
      $$AttendanceRecordsTableCreateCompanionBuilder,
      $$AttendanceRecordsTableUpdateCompanionBuilder,
      (
        AttendanceRecord,
        BaseReferences<
          _$AppDatabase,
          $AttendanceRecordsTable,
          AttendanceRecord
        >,
      ),
      AttendanceRecord,
      PrefetchHooks Function()
    >;
typedef $$InvitesTableCreateCompanionBuilder =
    InvitesCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> email,
      Value<String?> code,
      required String role,
      Value<String?> subjectId,
      required String capabilities,
      Value<String?> createdBy,
      required String createdAt,
      Value<String?> expiresAt,
      Value<String?> acceptedAt,
      Value<String?> acceptedBy,
      Value<int> rowid,
    });
typedef $$InvitesTableUpdateCompanionBuilder =
    InvitesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> email,
      Value<String?> code,
      Value<String> role,
      Value<String?> subjectId,
      Value<String> capabilities,
      Value<String?> createdBy,
      Value<String> createdAt,
      Value<String?> expiresAt,
      Value<String?> acceptedAt,
      Value<String?> acceptedBy,
      Value<int> rowid,
    });

class $$InvitesTableFilterComposer
    extends Composer<_$AppDatabase, $InvitesTable> {
  $$InvitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptedBy => $composableBuilder(
    column: $table.acceptedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvitesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvitesTable> {
  $$InvitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptedBy => $composableBuilder(
    column: $table.acceptedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvitesTable> {
  $$InvitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acceptedBy => $composableBuilder(
    column: $table.acceptedBy,
    builder: (column) => column,
  );
}

class $$InvitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvitesTable,
          Invite,
          $$InvitesTableFilterComposer,
          $$InvitesTableOrderingComposer,
          $$InvitesTableAnnotationComposer,
          $$InvitesTableCreateCompanionBuilder,
          $$InvitesTableUpdateCompanionBuilder,
          (Invite, BaseReferences<_$AppDatabase, $InvitesTable, Invite>),
          Invite,
          PrefetchHooks Function()
        > {
  $$InvitesTableTableManager(_$AppDatabase db, $InvitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> expiresAt = const Value.absent(),
                Value<String?> acceptedAt = const Value.absent(),
                Value<String?> acceptedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvitesCompanion(
                id: id,
                spaceId: spaceId,
                email: email,
                code: code,
                role: role,
                subjectId: subjectId,
                capabilities: capabilities,
                createdBy: createdBy,
                createdAt: createdAt,
                expiresAt: expiresAt,
                acceptedAt: acceptedAt,
                acceptedBy: acceptedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> email = const Value.absent(),
                Value<String?> code = const Value.absent(),
                required String role,
                Value<String?> subjectId = const Value.absent(),
                required String capabilities,
                Value<String?> createdBy = const Value.absent(),
                required String createdAt,
                Value<String?> expiresAt = const Value.absent(),
                Value<String?> acceptedAt = const Value.absent(),
                Value<String?> acceptedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvitesCompanion.insert(
                id: id,
                spaceId: spaceId,
                email: email,
                code: code,
                role: role,
                subjectId: subjectId,
                capabilities: capabilities,
                createdBy: createdBy,
                createdAt: createdAt,
                expiresAt: expiresAt,
                acceptedAt: acceptedAt,
                acceptedBy: acceptedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvitesTable,
      Invite,
      $$InvitesTableFilterComposer,
      $$InvitesTableOrderingComposer,
      $$InvitesTableAnnotationComposer,
      $$InvitesTableCreateCompanionBuilder,
      $$InvitesTableUpdateCompanionBuilder,
      (Invite, BaseReferences<_$AppDatabase, $InvitesTable, Invite>),
      Invite,
      PrefetchHooks Function()
    >;
typedef $$GroupMembersTableCreateCompanionBuilder =
    GroupMembersCompanion Function({
      required String id,
      required String groupId,
      required String memberId,
      required String spaceId,
      Value<String?> roleInGroup,
      required String assignedAt,
      Value<int> rowid,
    });
typedef $$GroupMembersTableUpdateCompanionBuilder =
    GroupMembersCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> memberId,
      Value<String> spaceId,
      Value<String?> roleInGroup,
      Value<String> assignedAt,
      Value<int> rowid,
    });

class $$GroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleInGroup => $composableBuilder(
    column: $table.roleInGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignedAt => $composableBuilder(
    column: $table.assignedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleInGroup => $composableBuilder(
    column: $table.roleInGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignedAt => $composableBuilder(
    column: $table.assignedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get roleInGroup => $composableBuilder(
    column: $table.roleInGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assignedAt => $composableBuilder(
    column: $table.assignedAt,
    builder: (column) => column,
  );
}

class $$GroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMembersTable,
          GroupMember,
          $$GroupMembersTableFilterComposer,
          $$GroupMembersTableOrderingComposer,
          $$GroupMembersTableAnnotationComposer,
          $$GroupMembersTableCreateCompanionBuilder,
          $$GroupMembersTableUpdateCompanionBuilder,
          (
            GroupMember,
            BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMember>,
          ),
          GroupMember,
          PrefetchHooks Function()
        > {
  $$GroupMembersTableTableManager(_$AppDatabase db, $GroupMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> roleInGroup = const Value.absent(),
                Value<String> assignedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                id: id,
                groupId: groupId,
                memberId: memberId,
                spaceId: spaceId,
                roleInGroup: roleInGroup,
                assignedAt: assignedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String memberId,
                required String spaceId,
                Value<String?> roleInGroup = const Value.absent(),
                required String assignedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                id: id,
                groupId: groupId,
                memberId: memberId,
                spaceId: spaceId,
                roleInGroup: roleInGroup,
                assignedAt: assignedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMembersTable,
      GroupMember,
      $$GroupMembersTableFilterComposer,
      $$GroupMembersTableOrderingComposer,
      $$GroupMembersTableAnnotationComposer,
      $$GroupMembersTableCreateCompanionBuilder,
      $$GroupMembersTableUpdateCompanionBuilder,
      (
        GroupMember,
        BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMember>,
      ),
      GroupMember,
      PrefetchHooks Function()
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> groupId,
      Value<String?> subjectId,
      required String kind,
      Value<String?> body,
      Value<String?> photoUrl,
      required String details,
      required String recordedBy,
      required String recordedAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> groupId,
      Value<String?> subjectId,
      Value<String> kind,
      Value<String?> body,
      Value<String?> photoUrl,
      Value<String> details,
      Value<String> recordedBy,
      Value<String> recordedAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
          Entry,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<String> recordedBy = const Value.absent(),
                Value<String> recordedAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                subjectId: subjectId,
                kind: kind,
                body: body,
                photoUrl: photoUrl,
                details: details,
                recordedBy: recordedBy,
                recordedAt: recordedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> groupId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                required String kind,
                Value<String?> body = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                required String details,
                required String recordedBy,
                required String recordedAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                subjectId: subjectId,
                kind: kind,
                body: body,
                photoUrl: photoUrl,
                details: details,
                recordedBy: recordedBy,
                recordedAt: recordedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
      Entry,
      PrefetchHooks Function()
    >;
typedef $$GuardiansTableCreateCompanionBuilder =
    GuardiansCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> userId,
      required String name,
      Value<String?> relationship,
      Value<String?> phone,
      Value<String?> email,
      Value<int?> authorizedForPickup,
      Value<String?> notes,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$GuardiansTableUpdateCompanionBuilder =
    GuardiansCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> userId,
      Value<String> name,
      Value<String?> relationship,
      Value<String?> phone,
      Value<String?> email,
      Value<int?> authorizedForPickup,
      Value<String?> notes,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$GuardiansTableFilterComposer
    extends Composer<_$AppDatabase, $GuardiansTable> {
  $$GuardiansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authorizedForPickup => $composableBuilder(
    column: $table.authorizedForPickup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuardiansTableOrderingComposer
    extends Composer<_$AppDatabase, $GuardiansTable> {
  $$GuardiansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authorizedForPickup => $composableBuilder(
    column: $table.authorizedForPickup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuardiansTableAnnotationComposer
    extends Composer<_$AppDatabase, $GuardiansTable> {
  $$GuardiansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get authorizedForPickup => $composableBuilder(
    column: $table.authorizedForPickup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GuardiansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GuardiansTable,
          Guardian,
          $$GuardiansTableFilterComposer,
          $$GuardiansTableOrderingComposer,
          $$GuardiansTableAnnotationComposer,
          $$GuardiansTableCreateCompanionBuilder,
          $$GuardiansTableUpdateCompanionBuilder,
          (Guardian, BaseReferences<_$AppDatabase, $GuardiansTable, Guardian>),
          Guardian,
          PrefetchHooks Function()
        > {
  $$GuardiansTableTableManager(_$AppDatabase db, $GuardiansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuardiansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuardiansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuardiansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> relationship = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int?> authorizedForPickup = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuardiansCompanion(
                id: id,
                spaceId: spaceId,
                userId: userId,
                name: name,
                relationship: relationship,
                phone: phone,
                email: email,
                authorizedForPickup: authorizedForPickup,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> userId = const Value.absent(),
                required String name,
                Value<String?> relationship = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int?> authorizedForPickup = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GuardiansCompanion.insert(
                id: id,
                spaceId: spaceId,
                userId: userId,
                name: name,
                relationship: relationship,
                phone: phone,
                email: email,
                authorizedForPickup: authorizedForPickup,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuardiansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GuardiansTable,
      Guardian,
      $$GuardiansTableFilterComposer,
      $$GuardiansTableOrderingComposer,
      $$GuardiansTableAnnotationComposer,
      $$GuardiansTableCreateCompanionBuilder,
      $$GuardiansTableUpdateCompanionBuilder,
      (Guardian, BaseReferences<_$AppDatabase, $GuardiansTable, Guardian>),
      Guardian,
      PrefetchHooks Function()
    >;
typedef $$SubjectGuardiansTableCreateCompanionBuilder =
    SubjectGuardiansCompanion Function({
      required String id,
      required String subjectId,
      required String guardianId,
      required String spaceId,
      Value<int?> isPrimary,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$SubjectGuardiansTableUpdateCompanionBuilder =
    SubjectGuardiansCompanion Function({
      Value<String> id,
      Value<String> subjectId,
      Value<String> guardianId,
      Value<String> spaceId,
      Value<int?> isPrimary,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$SubjectGuardiansTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectGuardiansTable> {
  $$SubjectGuardiansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubjectGuardiansTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectGuardiansTable> {
  $$SubjectGuardiansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubjectGuardiansTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectGuardiansTable> {
  $$SubjectGuardiansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<int> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SubjectGuardiansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectGuardiansTable,
          SubjectGuardian,
          $$SubjectGuardiansTableFilterComposer,
          $$SubjectGuardiansTableOrderingComposer,
          $$SubjectGuardiansTableAnnotationComposer,
          $$SubjectGuardiansTableCreateCompanionBuilder,
          $$SubjectGuardiansTableUpdateCompanionBuilder,
          (
            SubjectGuardian,
            BaseReferences<
              _$AppDatabase,
              $SubjectGuardiansTable,
              SubjectGuardian
            >,
          ),
          SubjectGuardian,
          PrefetchHooks Function()
        > {
  $$SubjectGuardiansTableTableManager(
    _$AppDatabase db,
    $SubjectGuardiansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectGuardiansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectGuardiansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectGuardiansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> guardianId = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<int?> isPrimary = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectGuardiansCompanion(
                id: id,
                subjectId: subjectId,
                guardianId: guardianId,
                spaceId: spaceId,
                isPrimary: isPrimary,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectId,
                required String guardianId,
                required String spaceId,
                Value<int?> isPrimary = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SubjectGuardiansCompanion.insert(
                id: id,
                subjectId: subjectId,
                guardianId: guardianId,
                spaceId: spaceId,
                isPrimary: isPrimary,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubjectGuardiansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectGuardiansTable,
      SubjectGuardian,
      $$SubjectGuardiansTableFilterComposer,
      $$SubjectGuardiansTableOrderingComposer,
      $$SubjectGuardiansTableAnnotationComposer,
      $$SubjectGuardiansTableCreateCompanionBuilder,
      $$SubjectGuardiansTableUpdateCompanionBuilder,
      (
        SubjectGuardian,
        BaseReferences<_$AppDatabase, $SubjectGuardiansTable, SubjectGuardian>,
      ),
      SubjectGuardian,
      PrefetchHooks Function()
    >;
typedef $$VehiclesTableCreateCompanionBuilder =
    VehiclesCompanion Function({
      required String id,
      required String spaceId,
      required String name,
      Value<String?> make,
      Value<String?> model,
      Value<int?> year,
      Value<String?> licensePlate,
      Value<String?> color,
      Value<String?> photoUrl,
      Value<String?> notes,
      required String capabilities,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$VehiclesTableUpdateCompanionBuilder =
    VehiclesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> name,
      Value<String?> make,
      Value<String?> model,
      Value<int?> year,
      Value<String?> licensePlate,
      Value<String?> color,
      Value<String?> photoUrl,
      Value<String?> notes,
      Value<String> capabilities,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          Vehicle,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (Vehicle, BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>),
          Vehicle,
          PrefetchHooks Function()
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> licensePlate = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                spaceId: spaceId,
                name: name,
                make: make,
                model: model,
                year: year,
                licensePlate: licensePlate,
                color: color,
                photoUrl: photoUrl,
                notes: notes,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String name,
                Value<String?> make = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> licensePlate = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String capabilities,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                spaceId: spaceId,
                name: name,
                make: make,
                model: model,
                year: year,
                licensePlate: licensePlate,
                color: color,
                photoUrl: photoUrl,
                notes: notes,
                capabilities: capabilities,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      Vehicle,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (Vehicle, BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>),
      Vehicle,
      PrefetchHooks Function()
    >;
typedef $$VehicleLogsTableCreateCompanionBuilder =
    VehicleLogsCompanion Function({
      required String id,
      required String spaceId,
      required String vehicleId,
      required String kind,
      required String driverMemberId,
      Value<int?> odometer,
      Value<String?> fuelLevel,
      required String items,
      Value<String?> notes,
      Value<String?> bodyDamageNotes,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$VehicleLogsTableUpdateCompanionBuilder =
    VehicleLogsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> vehicleId,
      Value<String> kind,
      Value<String> driverMemberId,
      Value<int?> odometer,
      Value<String?> fuelLevel,
      Value<String> items,
      Value<String?> notes,
      Value<String?> bodyDamageNotes,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$VehicleLogsTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleLogsTable> {
  $$VehicleLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driverMemberId => $composableBuilder(
    column: $table.driverMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuelLevel => $composableBuilder(
    column: $table.fuelLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyDamageNotes => $composableBuilder(
    column: $table.bodyDamageNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VehicleLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleLogsTable> {
  $$VehicleLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driverMemberId => $composableBuilder(
    column: $table.driverMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get odometer => $composableBuilder(
    column: $table.odometer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelLevel => $composableBuilder(
    column: $table.fuelLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get items => $composableBuilder(
    column: $table.items,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyDamageNotes => $composableBuilder(
    column: $table.bodyDamageNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehicleLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleLogsTable> {
  $$VehicleLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get driverMemberId => $composableBuilder(
    column: $table.driverMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);

  GeneratedColumn<String> get fuelLevel =>
      $composableBuilder(column: $table.fuelLevel, builder: (column) => column);

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get bodyDamageNotes => $composableBuilder(
    column: $table.bodyDamageNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$VehicleLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehicleLogsTable,
          VehicleLog,
          $$VehicleLogsTableFilterComposer,
          $$VehicleLogsTableOrderingComposer,
          $$VehicleLogsTableAnnotationComposer,
          $$VehicleLogsTableCreateCompanionBuilder,
          $$VehicleLogsTableUpdateCompanionBuilder,
          (
            VehicleLog,
            BaseReferences<_$AppDatabase, $VehicleLogsTable, VehicleLog>,
          ),
          VehicleLog,
          PrefetchHooks Function()
        > {
  $$VehicleLogsTableTableManager(_$AppDatabase db, $VehicleLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehicleLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> driverMemberId = const Value.absent(),
                Value<int?> odometer = const Value.absent(),
                Value<String?> fuelLevel = const Value.absent(),
                Value<String> items = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> bodyDamageNotes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleLogsCompanion(
                id: id,
                spaceId: spaceId,
                vehicleId: vehicleId,
                kind: kind,
                driverMemberId: driverMemberId,
                odometer: odometer,
                fuelLevel: fuelLevel,
                items: items,
                notes: notes,
                bodyDamageNotes: bodyDamageNotes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String vehicleId,
                required String kind,
                required String driverMemberId,
                Value<int?> odometer = const Value.absent(),
                Value<String?> fuelLevel = const Value.absent(),
                required String items,
                Value<String?> notes = const Value.absent(),
                Value<String?> bodyDamageNotes = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VehicleLogsCompanion.insert(
                id: id,
                spaceId: spaceId,
                vehicleId: vehicleId,
                kind: kind,
                driverMemberId: driverMemberId,
                odometer: odometer,
                fuelLevel: fuelLevel,
                items: items,
                notes: notes,
                bodyDamageNotes: bodyDamageNotes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehicleLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehicleLogsTable,
      VehicleLog,
      $$VehicleLogsTableFilterComposer,
      $$VehicleLogsTableOrderingComposer,
      $$VehicleLogsTableAnnotationComposer,
      $$VehicleLogsTableCreateCompanionBuilder,
      $$VehicleLogsTableUpdateCompanionBuilder,
      (
        VehicleLog,
        BaseReferences<_$AppDatabase, $VehicleLogsTable, VehicleLog>,
      ),
      VehicleLog,
      PrefetchHooks Function()
    >;
typedef $$MemberCertificationsTableCreateCompanionBuilder =
    MemberCertificationsCompanion Function({
      required String id,
      required String spaceId,
      required String memberId,
      required String certKey,
      Value<String?> issuedAt,
      Value<String?> expiresAt,
      Value<String?> notes,
      Value<String?> documentUrl,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$MemberCertificationsTableUpdateCompanionBuilder =
    MemberCertificationsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> memberId,
      Value<String> certKey,
      Value<String?> issuedAt,
      Value<String?> expiresAt,
      Value<String?> notes,
      Value<String?> documentUrl,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$MemberCertificationsTableFilterComposer
    extends Composer<_$AppDatabase, $MemberCertificationsTable> {
  $$MemberCertificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get certKey => $composableBuilder(
    column: $table.certKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuedAt => $composableBuilder(
    column: $table.issuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentUrl => $composableBuilder(
    column: $table.documentUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemberCertificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemberCertificationsTable> {
  $$MemberCertificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get certKey => $composableBuilder(
    column: $table.certKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuedAt => $composableBuilder(
    column: $table.issuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentUrl => $composableBuilder(
    column: $table.documentUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemberCertificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemberCertificationsTable> {
  $$MemberCertificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get certKey =>
      $composableBuilder(column: $table.certKey, builder: (column) => column);

  GeneratedColumn<String> get issuedAt =>
      $composableBuilder(column: $table.issuedAt, builder: (column) => column);

  GeneratedColumn<String> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get documentUrl => $composableBuilder(
    column: $table.documentUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MemberCertificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemberCertificationsTable,
          MemberCertification,
          $$MemberCertificationsTableFilterComposer,
          $$MemberCertificationsTableOrderingComposer,
          $$MemberCertificationsTableAnnotationComposer,
          $$MemberCertificationsTableCreateCompanionBuilder,
          $$MemberCertificationsTableUpdateCompanionBuilder,
          (
            MemberCertification,
            BaseReferences<
              _$AppDatabase,
              $MemberCertificationsTable,
              MemberCertification
            >,
          ),
          MemberCertification,
          PrefetchHooks Function()
        > {
  $$MemberCertificationsTableTableManager(
    _$AppDatabase db,
    $MemberCertificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemberCertificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemberCertificationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MemberCertificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<String> certKey = const Value.absent(),
                Value<String?> issuedAt = const Value.absent(),
                Value<String?> expiresAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> documentUrl = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemberCertificationsCompanion(
                id: id,
                spaceId: spaceId,
                memberId: memberId,
                certKey: certKey,
                issuedAt: issuedAt,
                expiresAt: expiresAt,
                notes: notes,
                documentUrl: documentUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String memberId,
                required String certKey,
                Value<String?> issuedAt = const Value.absent(),
                Value<String?> expiresAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> documentUrl = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemberCertificationsCompanion.insert(
                id: id,
                spaceId: spaceId,
                memberId: memberId,
                certKey: certKey,
                issuedAt: issuedAt,
                expiresAt: expiresAt,
                notes: notes,
                documentUrl: documentUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemberCertificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemberCertificationsTable,
      MemberCertification,
      $$MemberCertificationsTableFilterComposer,
      $$MemberCertificationsTableOrderingComposer,
      $$MemberCertificationsTableAnnotationComposer,
      $$MemberCertificationsTableCreateCompanionBuilder,
      $$MemberCertificationsTableUpdateCompanionBuilder,
      (
        MemberCertification,
        BaseReferences<
          _$AppDatabase,
          $MemberCertificationsTable,
          MemberCertification
        >,
      ),
      MemberCertification,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      required String spaceId,
      required String entityKind,
      required String entityId,
      required String url,
      Value<String?> thumbUrl,
      required String mimeType,
      Value<String?> caption,
      Value<int?> sortOrder,
      Value<String?> uploadedBy,
      Value<String?> takenAt,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> entityKind,
      Value<String> entityId,
      Value<String> url,
      Value<String?> thumbUrl,
      Value<String> mimeType,
      Value<String?> caption,
      Value<int?> sortOrder,
      Value<String?> uploadedBy,
      Value<String?> takenAt,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadedBy => $composableBuilder(
    column: $table.uploadedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadedBy => $composableBuilder(
    column: $table.uploadedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get entityKind => $composableBuilder(
    column: $table.entityKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get uploadedBy => $composableBuilder(
    column: $table.uploadedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            Attachment,
            BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
          ),
          Attachment,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> entityKind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<String?> uploadedBy = const Value.absent(),
                Value<String?> takenAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                spaceId: spaceId,
                entityKind: entityKind,
                entityId: entityId,
                url: url,
                thumbUrl: thumbUrl,
                mimeType: mimeType,
                caption: caption,
                sortOrder: sortOrder,
                uploadedBy: uploadedBy,
                takenAt: takenAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String entityKind,
                required String entityId,
                required String url,
                Value<String?> thumbUrl = const Value.absent(),
                required String mimeType,
                Value<String?> caption = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<String?> uploadedBy = const Value.absent(),
                Value<String?> takenAt = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                spaceId: spaceId,
                entityKind: entityKind,
                entityId: entityId,
                url: url,
                thumbUrl: thumbUrl,
                mimeType: mimeType,
                caption: caption,
                sortOrder: sortOrder,
                uploadedBy: uploadedBy,
                takenAt: takenAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        Attachment,
        BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment>,
      ),
      Attachment,
      PrefetchHooks Function()
    >;
typedef $$SurveyResponsesTableCreateCompanionBuilder =
    SurveyResponsesCompanion Function({
      required String id,
      required String spaceId,
      required String templateId,
      required String subjectId,
      required String status,
      Value<String?> recordedBy,
      required String answers,
      required String startedAt,
      Value<String?> completedAt,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$SurveyResponsesTableUpdateCompanionBuilder =
    SurveyResponsesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> templateId,
      Value<String> subjectId,
      Value<String> status,
      Value<String?> recordedBy,
      Value<String> answers,
      Value<String> startedAt,
      Value<String?> completedAt,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$SurveyResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $SurveyResponsesTable> {
  $$SurveyResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SurveyResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $SurveyResponsesTable> {
  $$SurveyResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SurveyResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurveyResponsesTable> {
  $$SurveyResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get recordedBy => $composableBuilder(
    column: $table.recordedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answers =>
      $composableBuilder(column: $table.answers, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SurveyResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SurveyResponsesTable,
          SurveyResponse,
          $$SurveyResponsesTableFilterComposer,
          $$SurveyResponsesTableOrderingComposer,
          $$SurveyResponsesTableAnnotationComposer,
          $$SurveyResponsesTableCreateCompanionBuilder,
          $$SurveyResponsesTableUpdateCompanionBuilder,
          (
            SurveyResponse,
            BaseReferences<
              _$AppDatabase,
              $SurveyResponsesTable,
              SurveyResponse
            >,
          ),
          SurveyResponse,
          PrefetchHooks Function()
        > {
  $$SurveyResponsesTableTableManager(
    _$AppDatabase db,
    $SurveyResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveyResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveyResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveyResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> recordedBy = const Value.absent(),
                Value<String> answers = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurveyResponsesCompanion(
                id: id,
                spaceId: spaceId,
                templateId: templateId,
                subjectId: subjectId,
                status: status,
                recordedBy: recordedBy,
                answers: answers,
                startedAt: startedAt,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String templateId,
                required String subjectId,
                required String status,
                Value<String?> recordedBy = const Value.absent(),
                required String answers,
                required String startedAt,
                Value<String?> completedAt = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SurveyResponsesCompanion.insert(
                id: id,
                spaceId: spaceId,
                templateId: templateId,
                subjectId: subjectId,
                status: status,
                recordedBy: recordedBy,
                answers: answers,
                startedAt: startedAt,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SurveyResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SurveyResponsesTable,
      SurveyResponse,
      $$SurveyResponsesTableFilterComposer,
      $$SurveyResponsesTableOrderingComposer,
      $$SurveyResponsesTableAnnotationComposer,
      $$SurveyResponsesTableCreateCompanionBuilder,
      $$SurveyResponsesTableUpdateCompanionBuilder,
      (
        SurveyResponse,
        BaseReferences<_$AppDatabase, $SurveyResponsesTable, SurveyResponse>,
      ),
      SurveyResponse,
      PrefetchHooks Function()
    >;
typedef $$DismissedInsightsTableCreateCompanionBuilder =
    DismissedInsightsCompanion Function({
      required String id,
      required String spaceId,
      required String memberId,
      required String insightId,
      Value<String?> dismissedUntil,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$DismissedInsightsTableUpdateCompanionBuilder =
    DismissedInsightsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> memberId,
      Value<String> insightId,
      Value<String?> dismissedUntil,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$DismissedInsightsTableFilterComposer
    extends Composer<_$AppDatabase, $DismissedInsightsTable> {
  $$DismissedInsightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insightId => $composableBuilder(
    column: $table.insightId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dismissedUntil => $composableBuilder(
    column: $table.dismissedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DismissedInsightsTableOrderingComposer
    extends Composer<_$AppDatabase, $DismissedInsightsTable> {
  $$DismissedInsightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insightId => $composableBuilder(
    column: $table.insightId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dismissedUntil => $composableBuilder(
    column: $table.dismissedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DismissedInsightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DismissedInsightsTable> {
  $$DismissedInsightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get insightId =>
      $composableBuilder(column: $table.insightId, builder: (column) => column);

  GeneratedColumn<String> get dismissedUntil => $composableBuilder(
    column: $table.dismissedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DismissedInsightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DismissedInsightsTable,
          DismissedInsight,
          $$DismissedInsightsTableFilterComposer,
          $$DismissedInsightsTableOrderingComposer,
          $$DismissedInsightsTableAnnotationComposer,
          $$DismissedInsightsTableCreateCompanionBuilder,
          $$DismissedInsightsTableUpdateCompanionBuilder,
          (
            DismissedInsight,
            BaseReferences<
              _$AppDatabase,
              $DismissedInsightsTable,
              DismissedInsight
            >,
          ),
          DismissedInsight,
          PrefetchHooks Function()
        > {
  $$DismissedInsightsTableTableManager(
    _$AppDatabase db,
    $DismissedInsightsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DismissedInsightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DismissedInsightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DismissedInsightsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<String> insightId = const Value.absent(),
                Value<String?> dismissedUntil = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DismissedInsightsCompanion(
                id: id,
                spaceId: spaceId,
                memberId: memberId,
                insightId: insightId,
                dismissedUntil: dismissedUntil,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String memberId,
                required String insightId,
                Value<String?> dismissedUntil = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DismissedInsightsCompanion.insert(
                id: id,
                spaceId: spaceId,
                memberId: memberId,
                insightId: insightId,
                dismissedUntil: dismissedUntil,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DismissedInsightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DismissedInsightsTable,
      DismissedInsight,
      $$DismissedInsightsTableFilterComposer,
      $$DismissedInsightsTableOrderingComposer,
      $$DismissedInsightsTableAnnotationComposer,
      $$DismissedInsightsTableCreateCompanionBuilder,
      $$DismissedInsightsTableUpdateCompanionBuilder,
      (
        DismissedInsight,
        BaseReferences<
          _$AppDatabase,
          $DismissedInsightsTable,
          DismissedInsight
        >,
      ),
      DismissedInsight,
      PrefetchHooks Function()
    >;
typedef $$CapturesTableCreateCompanionBuilder =
    CapturesCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> authorId,
      required String body,
      required String status,
      Value<String?> promotedToKind,
      Value<String?> promotedToId,
      Value<String?> promotedSubjectId,
      Value<String?> processedAt,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$CapturesTableUpdateCompanionBuilder =
    CapturesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> authorId,
      Value<String> body,
      Value<String> status,
      Value<String?> promotedToKind,
      Value<String?> promotedToId,
      Value<String?> promotedSubjectId,
      Value<String?> processedAt,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$CapturesTableFilterComposer
    extends Composer<_$AppDatabase, $CapturesTable> {
  $$CapturesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promotedToKind => $composableBuilder(
    column: $table.promotedToKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promotedToId => $composableBuilder(
    column: $table.promotedToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promotedSubjectId => $composableBuilder(
    column: $table.promotedSubjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CapturesTableOrderingComposer
    extends Composer<_$AppDatabase, $CapturesTable> {
  $$CapturesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promotedToKind => $composableBuilder(
    column: $table.promotedToKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promotedToId => $composableBuilder(
    column: $table.promotedToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promotedSubjectId => $composableBuilder(
    column: $table.promotedSubjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CapturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapturesTable> {
  $$CapturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get promotedToKind => $composableBuilder(
    column: $table.promotedToKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promotedToId => $composableBuilder(
    column: $table.promotedToId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promotedSubjectId => $composableBuilder(
    column: $table.promotedSubjectId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CapturesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapturesTable,
          Capture,
          $$CapturesTableFilterComposer,
          $$CapturesTableOrderingComposer,
          $$CapturesTableAnnotationComposer,
          $$CapturesTableCreateCompanionBuilder,
          $$CapturesTableUpdateCompanionBuilder,
          (Capture, BaseReferences<_$AppDatabase, $CapturesTable, Capture>),
          Capture,
          PrefetchHooks Function()
        > {
  $$CapturesTableTableManager(_$AppDatabase db, $CapturesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> promotedToKind = const Value.absent(),
                Value<String?> promotedToId = const Value.absent(),
                Value<String?> promotedSubjectId = const Value.absent(),
                Value<String?> processedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapturesCompanion(
                id: id,
                spaceId: spaceId,
                authorId: authorId,
                body: body,
                status: status,
                promotedToKind: promotedToKind,
                promotedToId: promotedToId,
                promotedSubjectId: promotedSubjectId,
                processedAt: processedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> authorId = const Value.absent(),
                required String body,
                required String status,
                Value<String?> promotedToKind = const Value.absent(),
                Value<String?> promotedToId = const Value.absent(),
                Value<String?> promotedSubjectId = const Value.absent(),
                Value<String?> processedAt = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CapturesCompanion.insert(
                id: id,
                spaceId: spaceId,
                authorId: authorId,
                body: body,
                status: status,
                promotedToKind: promotedToKind,
                promotedToId: promotedToId,
                promotedSubjectId: promotedSubjectId,
                processedAt: processedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CapturesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapturesTable,
      Capture,
      $$CapturesTableFilterComposer,
      $$CapturesTableOrderingComposer,
      $$CapturesTableAnnotationComposer,
      $$CapturesTableCreateCompanionBuilder,
      $$CapturesTableUpdateCompanionBuilder,
      (Capture, BaseReferences<_$AppDatabase, $CapturesTable, Capture>),
      Capture,
      PrefetchHooks Function()
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> authorId,
      Value<String?> subjectId,
      required String body,
      required String status,
      Value<String?> dueAt,
      Value<String?> completedBy,
      Value<String?> completedAt,
      Value<String?> createdFromCaptureId,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> authorId,
      Value<String?> subjectId,
      Value<String> body,
      Value<String> status,
      Value<String?> dueAt,
      Value<String?> completedBy,
      Value<String?> completedAt,
      Value<String?> createdFromCaptureId,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdFromCaptureId => $composableBuilder(
    column: $table.createdFromCaptureId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdFromCaptureId => $composableBuilder(
    column: $table.createdFromCaptureId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get completedBy => $composableBuilder(
    column: $table.completedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdFromCaptureId => $composableBuilder(
    column: $table.createdFromCaptureId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> createdFromCaptureId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                spaceId: spaceId,
                authorId: authorId,
                subjectId: subjectId,
                body: body,
                status: status,
                dueAt: dueAt,
                completedBy: completedBy,
                completedAt: completedAt,
                createdFromCaptureId: createdFromCaptureId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> authorId = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                required String body,
                required String status,
                Value<String?> dueAt = const Value.absent(),
                Value<String?> completedBy = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> createdFromCaptureId = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                spaceId: spaceId,
                authorId: authorId,
                subjectId: subjectId,
                body: body,
                status: status,
                dueAt: dueAt,
                completedBy: completedBy,
                completedAt: completedAt,
                createdFromCaptureId: createdFromCaptureId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String spaceId,
      required String subjectId,
      required String guardianId,
      required String senderKind,
      Value<String?> senderMemberId,
      Value<String?> senderGuardianId,
      required String body,
      Value<String?> readAt,
      Value<String?> readByGuardianIds,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> subjectId,
      Value<String> guardianId,
      Value<String> senderKind,
      Value<String?> senderMemberId,
      Value<String?> senderGuardianId,
      Value<String> body,
      Value<String?> readAt,
      Value<String?> readByGuardianIds,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderKind => $composableBuilder(
    column: $table.senderKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderMemberId => $composableBuilder(
    column: $table.senderMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderGuardianId => $composableBuilder(
    column: $table.senderGuardianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readByGuardianIds => $composableBuilder(
    column: $table.readByGuardianIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderKind => $composableBuilder(
    column: $table.senderKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderMemberId => $composableBuilder(
    column: $table.senderMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderGuardianId => $composableBuilder(
    column: $table.senderGuardianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readByGuardianIds => $composableBuilder(
    column: $table.readByGuardianIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderKind => $composableBuilder(
    column: $table.senderKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderMemberId => $composableBuilder(
    column: $table.senderMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderGuardianId => $composableBuilder(
    column: $table.senderGuardianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<String> get readByGuardianIds => $composableBuilder(
    column: $table.readByGuardianIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> guardianId = const Value.absent(),
                Value<String> senderKind = const Value.absent(),
                Value<String?> senderMemberId = const Value.absent(),
                Value<String?> senderGuardianId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                Value<String?> readByGuardianIds = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                spaceId: spaceId,
                subjectId: subjectId,
                guardianId: guardianId,
                senderKind: senderKind,
                senderMemberId: senderMemberId,
                senderGuardianId: senderGuardianId,
                body: body,
                readAt: readAt,
                readByGuardianIds: readByGuardianIds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String subjectId,
                required String guardianId,
                required String senderKind,
                Value<String?> senderMemberId = const Value.absent(),
                Value<String?> senderGuardianId = const Value.absent(),
                required String body,
                Value<String?> readAt = const Value.absent(),
                Value<String?> readByGuardianIds = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                spaceId: spaceId,
                subjectId: subjectId,
                guardianId: guardianId,
                senderKind: senderKind,
                senderMemberId: senderMemberId,
                senderGuardianId: senderGuardianId,
                body: body,
                readAt: readAt,
                readByGuardianIds: readByGuardianIds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$ExportsTableCreateCompanionBuilder =
    ExportsCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> authorId,
      required String templateId,
      required String templateVersion,
      Value<String?> subjectId,
      Value<String?> groupId,
      required String status,
      required String format,
      Value<String?> storagePath,
      required String snapshotJson,
      Value<String?> note,
      required String generatedAt,
      Value<String?> sentAt,
      Value<String?> archivedAt,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$ExportsTableUpdateCompanionBuilder =
    ExportsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> authorId,
      Value<String> templateId,
      Value<String> templateVersion,
      Value<String?> subjectId,
      Value<String?> groupId,
      Value<String> status,
      Value<String> format,
      Value<String?> storagePath,
      Value<String> snapshotJson,
      Value<String?> note,
      Value<String> generatedAt,
      Value<String?> sentAt,
      Value<String?> archivedAt,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$ExportsTableFilterComposer
    extends Composer<_$AppDatabase, $ExportsTable> {
  $$ExportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExportsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExportsTable> {
  $$ExportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExportsTable> {
  $$ExportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get templateVersion => $composableBuilder(
    column: $table.templateVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExportsTable,
          Export,
          $$ExportsTableFilterComposer,
          $$ExportsTableOrderingComposer,
          $$ExportsTableAnnotationComposer,
          $$ExportsTableCreateCompanionBuilder,
          $$ExportsTableUpdateCompanionBuilder,
          (Export, BaseReferences<_$AppDatabase, $ExportsTable, Export>),
          Export,
          PrefetchHooks Function()
        > {
  $$ExportsTableTableManager(_$AppDatabase db, $ExportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> templateVersion = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> storagePath = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> generatedAt = const Value.absent(),
                Value<String?> sentAt = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExportsCompanion(
                id: id,
                spaceId: spaceId,
                authorId: authorId,
                templateId: templateId,
                templateVersion: templateVersion,
                subjectId: subjectId,
                groupId: groupId,
                status: status,
                format: format,
                storagePath: storagePath,
                snapshotJson: snapshotJson,
                note: note,
                generatedAt: generatedAt,
                sentAt: sentAt,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> authorId = const Value.absent(),
                required String templateId,
                required String templateVersion,
                Value<String?> subjectId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                required String status,
                required String format,
                Value<String?> storagePath = const Value.absent(),
                required String snapshotJson,
                Value<String?> note = const Value.absent(),
                required String generatedAt,
                Value<String?> sentAt = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExportsCompanion.insert(
                id: id,
                spaceId: spaceId,
                authorId: authorId,
                templateId: templateId,
                templateVersion: templateVersion,
                subjectId: subjectId,
                groupId: groupId,
                status: status,
                format: format,
                storagePath: storagePath,
                snapshotJson: snapshotJson,
                note: note,
                generatedAt: generatedAt,
                sentAt: sentAt,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExportsTable,
      Export,
      $$ExportsTableFilterComposer,
      $$ExportsTableOrderingComposer,
      $$ExportsTableAnnotationComposer,
      $$ExportsTableCreateCompanionBuilder,
      $$ExportsTableUpdateCompanionBuilder,
      (Export, BaseReferences<_$AppDatabase, $ExportsTable, Export>),
      Export,
      PrefetchHooks Function()
    >;
typedef $$ExportRecipientsTableCreateCompanionBuilder =
    ExportRecipientsCompanion Function({
      required String id,
      required String exportId,
      required String spaceId,
      required String kind,
      Value<String?> guardianId,
      Value<String?> memberId,
      Value<String?> externalLabel,
      Value<String?> externalEmail,
      required String channel,
      required String state,
      Value<String?> stateDetail,
      Value<String?> sentAt,
      Value<String?> readAt,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ExportRecipientsTableUpdateCompanionBuilder =
    ExportRecipientsCompanion Function({
      Value<String> id,
      Value<String> exportId,
      Value<String> spaceId,
      Value<String> kind,
      Value<String?> guardianId,
      Value<String?> memberId,
      Value<String?> externalLabel,
      Value<String?> externalEmail,
      Value<String> channel,
      Value<String> state,
      Value<String?> stateDetail,
      Value<String?> sentAt,
      Value<String?> readAt,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$ExportRecipientsTableFilterComposer
    extends Composer<_$AppDatabase, $ExportRecipientsTable> {
  $$ExportRecipientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exportId => $composableBuilder(
    column: $table.exportId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalLabel => $composableBuilder(
    column: $table.externalLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalEmail => $composableBuilder(
    column: $table.externalEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateDetail => $composableBuilder(
    column: $table.stateDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExportRecipientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExportRecipientsTable> {
  $$ExportRecipientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exportId => $composableBuilder(
    column: $table.exportId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberId => $composableBuilder(
    column: $table.memberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalLabel => $composableBuilder(
    column: $table.externalLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalEmail => $composableBuilder(
    column: $table.externalEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateDetail => $composableBuilder(
    column: $table.stateDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExportRecipientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExportRecipientsTable> {
  $$ExportRecipientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get exportId =>
      $composableBuilder(column: $table.exportId, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get guardianId => $composableBuilder(
    column: $table.guardianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get externalLabel => $composableBuilder(
    column: $table.externalLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalEmail => $composableBuilder(
    column: $table.externalEmail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get stateDetail => $composableBuilder(
    column: $table.stateDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<String> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExportRecipientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExportRecipientsTable,
          ExportRecipient,
          $$ExportRecipientsTableFilterComposer,
          $$ExportRecipientsTableOrderingComposer,
          $$ExportRecipientsTableAnnotationComposer,
          $$ExportRecipientsTableCreateCompanionBuilder,
          $$ExportRecipientsTableUpdateCompanionBuilder,
          (
            ExportRecipient,
            BaseReferences<
              _$AppDatabase,
              $ExportRecipientsTable,
              ExportRecipient
            >,
          ),
          ExportRecipient,
          PrefetchHooks Function()
        > {
  $$ExportRecipientsTableTableManager(
    _$AppDatabase db,
    $ExportRecipientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExportRecipientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExportRecipientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExportRecipientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> exportId = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> guardianId = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> externalLabel = const Value.absent(),
                Value<String?> externalEmail = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> stateDetail = const Value.absent(),
                Value<String?> sentAt = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExportRecipientsCompanion(
                id: id,
                exportId: exportId,
                spaceId: spaceId,
                kind: kind,
                guardianId: guardianId,
                memberId: memberId,
                externalLabel: externalLabel,
                externalEmail: externalEmail,
                channel: channel,
                state: state,
                stateDetail: stateDetail,
                sentAt: sentAt,
                readAt: readAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String exportId,
                required String spaceId,
                required String kind,
                Value<String?> guardianId = const Value.absent(),
                Value<String?> memberId = const Value.absent(),
                Value<String?> externalLabel = const Value.absent(),
                Value<String?> externalEmail = const Value.absent(),
                required String channel,
                required String state,
                Value<String?> stateDetail = const Value.absent(),
                Value<String?> sentAt = const Value.absent(),
                Value<String?> readAt = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExportRecipientsCompanion.insert(
                id: id,
                exportId: exportId,
                spaceId: spaceId,
                kind: kind,
                guardianId: guardianId,
                memberId: memberId,
                externalLabel: externalLabel,
                externalEmail: externalEmail,
                channel: channel,
                state: state,
                stateDetail: stateDetail,
                sentAt: sentAt,
                readAt: readAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExportRecipientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExportRecipientsTable,
      ExportRecipient,
      $$ExportRecipientsTableFilterComposer,
      $$ExportRecipientsTableOrderingComposer,
      $$ExportRecipientsTableAnnotationComposer,
      $$ExportRecipientsTableCreateCompanionBuilder,
      $$ExportRecipientsTableUpdateCompanionBuilder,
      (
        ExportRecipient,
        BaseReferences<_$AppDatabase, $ExportRecipientsTable, ExportRecipient>,
      ),
      ExportRecipient,
      PrefetchHooks Function()
    >;
typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      required String id,
      required String spaceId,
      required String name,
      Value<String?> notes,
      Value<int?> capacity,
      required int isOutdoor,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> name,
      Value<String?> notes,
      Value<int?> capacity,
      Value<int> isOutdoor,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$LocationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isOutdoor => $composableBuilder(
    column: $table.isOutdoor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isOutdoor => $composableBuilder(
    column: $table.isOutdoor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get capacity =>
      $composableBuilder(column: $table.capacity, builder: (column) => column);

  GeneratedColumn<int> get isOutdoor =>
      $composableBuilder(column: $table.isOutdoor, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationsTable,
          Location,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (Location, BaseReferences<_$AppDatabase, $LocationsTable, Location>),
          Location,
          PrefetchHooks Function()
        > {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> capacity = const Value.absent(),
                Value<int> isOutdoor = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                spaceId: spaceId,
                name: name,
                notes: notes,
                capacity: capacity,
                isOutdoor: isOutdoor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<int?> capacity = const Value.absent(),
                required int isOutdoor,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion.insert(
                id: id,
                spaceId: spaceId,
                name: name,
                notes: notes,
                capacity: capacity,
                isOutdoor: isOutdoor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationsTable,
      Location,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (Location, BaseReferences<_$AppDatabase, $LocationsTable, Location>),
      Location,
      PrefetchHooks Function()
    >;
typedef $$ActivitiesTableCreateCompanionBuilder =
    ActivitiesCompanion Function({
      required String id,
      required String spaceId,
      Value<String?> ownerMemberId,
      required String name,
      Value<String?> description,
      Value<String?> defaultLocationId,
      Value<int?> defaultDurationMinutes,
      Value<String?> supplies,
      Value<int?> ageMin,
      Value<int?> ageMax,
      Value<int?> maxCapacity,
      required int isOutdoor,
      Value<String?> indoorAltActivityId,
      required String capabilities,
      Value<String?> archivedAt,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$ActivitiesTableUpdateCompanionBuilder =
    ActivitiesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String?> ownerMemberId,
      Value<String> name,
      Value<String?> description,
      Value<String?> defaultLocationId,
      Value<int?> defaultDurationMinutes,
      Value<String?> supplies,
      Value<int?> ageMin,
      Value<int?> ageMax,
      Value<int?> maxCapacity,
      Value<int> isOutdoor,
      Value<String?> indoorAltActivityId,
      Value<String> capabilities,
      Value<String?> archivedAt,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$ActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerMemberId => $composableBuilder(
    column: $table.ownerMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultLocationId => $composableBuilder(
    column: $table.defaultLocationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultDurationMinutes => $composableBuilder(
    column: $table.defaultDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplies => $composableBuilder(
    column: $table.supplies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageMin => $composableBuilder(
    column: $table.ageMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageMax => $composableBuilder(
    column: $table.ageMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxCapacity => $composableBuilder(
    column: $table.maxCapacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isOutdoor => $composableBuilder(
    column: $table.isOutdoor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indoorAltActivityId => $composableBuilder(
    column: $table.indoorAltActivityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerMemberId => $composableBuilder(
    column: $table.ownerMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultLocationId => $composableBuilder(
    column: $table.defaultLocationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultDurationMinutes => $composableBuilder(
    column: $table.defaultDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplies => $composableBuilder(
    column: $table.supplies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageMin => $composableBuilder(
    column: $table.ageMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageMax => $composableBuilder(
    column: $table.ageMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxCapacity => $composableBuilder(
    column: $table.maxCapacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isOutdoor => $composableBuilder(
    column: $table.isOutdoor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indoorAltActivityId => $composableBuilder(
    column: $table.indoorAltActivityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get ownerMemberId => $composableBuilder(
    column: $table.ownerMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultLocationId => $composableBuilder(
    column: $table.defaultLocationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultDurationMinutes => $composableBuilder(
    column: $table.defaultDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supplies =>
      $composableBuilder(column: $table.supplies, builder: (column) => column);

  GeneratedColumn<int> get ageMin =>
      $composableBuilder(column: $table.ageMin, builder: (column) => column);

  GeneratedColumn<int> get ageMax =>
      $composableBuilder(column: $table.ageMax, builder: (column) => column);

  GeneratedColumn<int> get maxCapacity => $composableBuilder(
    column: $table.maxCapacity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isOutdoor =>
      $composableBuilder(column: $table.isOutdoor, builder: (column) => column);

  GeneratedColumn<String> get indoorAltActivityId => $composableBuilder(
    column: $table.indoorAltActivityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivitiesTable,
          Activity,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (Activity, BaseReferences<_$AppDatabase, $ActivitiesTable, Activity>),
          Activity,
          PrefetchHooks Function()
        > {
  $$ActivitiesTableTableManager(_$AppDatabase db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String?> ownerMemberId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> defaultLocationId = const Value.absent(),
                Value<int?> defaultDurationMinutes = const Value.absent(),
                Value<String?> supplies = const Value.absent(),
                Value<int?> ageMin = const Value.absent(),
                Value<int?> ageMax = const Value.absent(),
                Value<int?> maxCapacity = const Value.absent(),
                Value<int> isOutdoor = const Value.absent(),
                Value<String?> indoorAltActivityId = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                spaceId: spaceId,
                ownerMemberId: ownerMemberId,
                name: name,
                description: description,
                defaultLocationId: defaultLocationId,
                defaultDurationMinutes: defaultDurationMinutes,
                supplies: supplies,
                ageMin: ageMin,
                ageMax: ageMax,
                maxCapacity: maxCapacity,
                isOutdoor: isOutdoor,
                indoorAltActivityId: indoorAltActivityId,
                capabilities: capabilities,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                Value<String?> ownerMemberId = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> defaultLocationId = const Value.absent(),
                Value<int?> defaultDurationMinutes = const Value.absent(),
                Value<String?> supplies = const Value.absent(),
                Value<int?> ageMin = const Value.absent(),
                Value<int?> ageMax = const Value.absent(),
                Value<int?> maxCapacity = const Value.absent(),
                required int isOutdoor,
                Value<String?> indoorAltActivityId = const Value.absent(),
                required String capabilities,
                Value<String?> archivedAt = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                spaceId: spaceId,
                ownerMemberId: ownerMemberId,
                name: name,
                description: description,
                defaultLocationId: defaultLocationId,
                defaultDurationMinutes: defaultDurationMinutes,
                supplies: supplies,
                ageMin: ageMin,
                ageMax: ageMax,
                maxCapacity: maxCapacity,
                isOutdoor: isOutdoor,
                indoorAltActivityId: indoorAltActivityId,
                capabilities: capabilities,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivitiesTable,
      Activity,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (Activity, BaseReferences<_$AppDatabase, $ActivitiesTable, Activity>),
      Activity,
      PrefetchHooks Function()
    >;
typedef $$ScheduleBlocksTableCreateCompanionBuilder =
    ScheduleBlocksCompanion Function({
      required String id,
      required String spaceId,
      required String groupId,
      required String date,
      required String startAt,
      required String endAt,
      Value<String?> activityId,
      Value<String?> leadMemberId,
      Value<String?> leadSubstituteMemberId,
      Value<String?> locationOverrideId,
      required String kind,
      Value<String?> notes,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$ScheduleBlocksTableUpdateCompanionBuilder =
    ScheduleBlocksCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> groupId,
      Value<String> date,
      Value<String> startAt,
      Value<String> endAt,
      Value<String?> activityId,
      Value<String?> leadMemberId,
      Value<String?> leadSubstituteMemberId,
      Value<String?> locationOverrideId,
      Value<String> kind,
      Value<String?> notes,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$ScheduleBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleBlocksTable> {
  $$ScheduleBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leadMemberId => $composableBuilder(
    column: $table.leadMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leadSubstituteMemberId => $composableBuilder(
    column: $table.leadSubstituteMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationOverrideId => $composableBuilder(
    column: $table.locationOverrideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduleBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleBlocksTable> {
  $$ScheduleBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leadMemberId => $composableBuilder(
    column: $table.leadMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leadSubstituteMemberId => $composableBuilder(
    column: $table.leadSubstituteMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationOverrideId => $composableBuilder(
    column: $table.locationOverrideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleBlocksTable> {
  $$ScheduleBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<String> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
    column: $table.activityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leadMemberId => $composableBuilder(
    column: $table.leadMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leadSubstituteMemberId => $composableBuilder(
    column: $table.leadSubstituteMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationOverrideId => $composableBuilder(
    column: $table.locationOverrideId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScheduleBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleBlocksTable,
          ScheduleBlock,
          $$ScheduleBlocksTableFilterComposer,
          $$ScheduleBlocksTableOrderingComposer,
          $$ScheduleBlocksTableAnnotationComposer,
          $$ScheduleBlocksTableCreateCompanionBuilder,
          $$ScheduleBlocksTableUpdateCompanionBuilder,
          (
            ScheduleBlock,
            BaseReferences<_$AppDatabase, $ScheduleBlocksTable, ScheduleBlock>,
          ),
          ScheduleBlock,
          PrefetchHooks Function()
        > {
  $$ScheduleBlocksTableTableManager(
    _$AppDatabase db,
    $ScheduleBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> startAt = const Value.absent(),
                Value<String> endAt = const Value.absent(),
                Value<String?> activityId = const Value.absent(),
                Value<String?> leadMemberId = const Value.absent(),
                Value<String?> leadSubstituteMemberId = const Value.absent(),
                Value<String?> locationOverrideId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleBlocksCompanion(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                date: date,
                startAt: startAt,
                endAt: endAt,
                activityId: activityId,
                leadMemberId: leadMemberId,
                leadSubstituteMemberId: leadSubstituteMemberId,
                locationOverrideId: locationOverrideId,
                kind: kind,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String groupId,
                required String date,
                required String startAt,
                required String endAt,
                Value<String?> activityId = const Value.absent(),
                Value<String?> leadMemberId = const Value.absent(),
                Value<String?> leadSubstituteMemberId = const Value.absent(),
                Value<String?> locationOverrideId = const Value.absent(),
                required String kind,
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ScheduleBlocksCompanion.insert(
                id: id,
                spaceId: spaceId,
                groupId: groupId,
                date: date,
                startAt: startAt,
                endAt: endAt,
                activityId: activityId,
                leadMemberId: leadMemberId,
                leadSubstituteMemberId: leadSubstituteMemberId,
                locationOverrideId: locationOverrideId,
                kind: kind,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduleBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleBlocksTable,
      ScheduleBlock,
      $$ScheduleBlocksTableFilterComposer,
      $$ScheduleBlocksTableOrderingComposer,
      $$ScheduleBlocksTableAnnotationComposer,
      $$ScheduleBlocksTableCreateCompanionBuilder,
      $$ScheduleBlocksTableUpdateCompanionBuilder,
      (
        ScheduleBlock,
        BaseReferences<_$AppDatabase, $ScheduleBlocksTable, ScheduleBlock>,
      ),
      ScheduleBlock,
      PrefetchHooks Function()
    >;
typedef $$TripLogisticsTableCreateCompanionBuilder =
    TripLogisticsCompanion Function({
      required String id,
      required String spaceId,
      required String scheduleBlockId,
      required String destination,
      Value<String?> destinationAddress,
      Value<String?> departureAt,
      Value<String?> returnAt,
      required int requiresPermissionSlip,
      Value<String?> notes,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$TripLogisticsTableUpdateCompanionBuilder =
    TripLogisticsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> scheduleBlockId,
      Value<String> destination,
      Value<String?> destinationAddress,
      Value<String?> departureAt,
      Value<String?> returnAt,
      Value<int> requiresPermissionSlip,
      Value<String?> notes,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$TripLogisticsTableFilterComposer
    extends Composer<_$AppDatabase, $TripLogisticsTable> {
  $$TripLogisticsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleBlockId => $composableBuilder(
    column: $table.scheduleBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationAddress => $composableBuilder(
    column: $table.destinationAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get departureAt => $composableBuilder(
    column: $table.departureAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get returnAt => $composableBuilder(
    column: $table.returnAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiresPermissionSlip => $composableBuilder(
    column: $table.requiresPermissionSlip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TripLogisticsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripLogisticsTable> {
  $$TripLogisticsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleBlockId => $composableBuilder(
    column: $table.scheduleBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationAddress => $composableBuilder(
    column: $table.destinationAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get departureAt => $composableBuilder(
    column: $table.departureAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get returnAt => $composableBuilder(
    column: $table.returnAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiresPermissionSlip => $composableBuilder(
    column: $table.requiresPermissionSlip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripLogisticsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripLogisticsTable> {
  $$TripLogisticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get scheduleBlockId => $composableBuilder(
    column: $table.scheduleBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationAddress => $composableBuilder(
    column: $table.destinationAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get departureAt => $composableBuilder(
    column: $table.departureAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get returnAt =>
      $composableBuilder(column: $table.returnAt, builder: (column) => column);

  GeneratedColumn<int> get requiresPermissionSlip => $composableBuilder(
    column: $table.requiresPermissionSlip,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TripLogisticsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripLogisticsTable,
          TripLogistic,
          $$TripLogisticsTableFilterComposer,
          $$TripLogisticsTableOrderingComposer,
          $$TripLogisticsTableAnnotationComposer,
          $$TripLogisticsTableCreateCompanionBuilder,
          $$TripLogisticsTableUpdateCompanionBuilder,
          (
            TripLogistic,
            BaseReferences<_$AppDatabase, $TripLogisticsTable, TripLogistic>,
          ),
          TripLogistic,
          PrefetchHooks Function()
        > {
  $$TripLogisticsTableTableManager(_$AppDatabase db, $TripLogisticsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripLogisticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripLogisticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripLogisticsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> scheduleBlockId = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<String?> destinationAddress = const Value.absent(),
                Value<String?> departureAt = const Value.absent(),
                Value<String?> returnAt = const Value.absent(),
                Value<int> requiresPermissionSlip = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripLogisticsCompanion(
                id: id,
                spaceId: spaceId,
                scheduleBlockId: scheduleBlockId,
                destination: destination,
                destinationAddress: destinationAddress,
                departureAt: departureAt,
                returnAt: returnAt,
                requiresPermissionSlip: requiresPermissionSlip,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String scheduleBlockId,
                required String destination,
                Value<String?> destinationAddress = const Value.absent(),
                Value<String?> departureAt = const Value.absent(),
                Value<String?> returnAt = const Value.absent(),
                required int requiresPermissionSlip,
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TripLogisticsCompanion.insert(
                id: id,
                spaceId: spaceId,
                scheduleBlockId: scheduleBlockId,
                destination: destination,
                destinationAddress: destinationAddress,
                departureAt: departureAt,
                returnAt: returnAt,
                requiresPermissionSlip: requiresPermissionSlip,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripLogisticsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripLogisticsTable,
      TripLogistic,
      $$TripLogisticsTableFilterComposer,
      $$TripLogisticsTableOrderingComposer,
      $$TripLogisticsTableAnnotationComposer,
      $$TripLogisticsTableCreateCompanionBuilder,
      $$TripLogisticsTableUpdateCompanionBuilder,
      (
        TripLogistic,
        BaseReferences<_$AppDatabase, $TripLogisticsTable, TripLogistic>,
      ),
      TripLogistic,
      PrefetchHooks Function()
    >;
typedef $$TripVehiclesTableCreateCompanionBuilder =
    TripVehiclesCompanion Function({
      required String id,
      required String spaceId,
      required String tripLogisticsId,
      required String vehicleId,
      Value<String?> driverMemberId,
      required String manifest,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$TripVehiclesTableUpdateCompanionBuilder =
    TripVehiclesCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> tripLogisticsId,
      Value<String> vehicleId,
      Value<String?> driverMemberId,
      Value<String> manifest,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$TripVehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $TripVehiclesTable> {
  $$TripVehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripLogisticsId => $composableBuilder(
    column: $table.tripLogisticsId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driverMemberId => $composableBuilder(
    column: $table.driverMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TripVehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $TripVehiclesTable> {
  $$TripVehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripLogisticsId => $composableBuilder(
    column: $table.tripLogisticsId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleId => $composableBuilder(
    column: $table.vehicleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driverMemberId => $composableBuilder(
    column: $table.driverMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripVehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripVehiclesTable> {
  $$TripVehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get tripLogisticsId => $composableBuilder(
    column: $table.tripLogisticsId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get driverMemberId => $composableBuilder(
    column: $table.driverMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifest =>
      $composableBuilder(column: $table.manifest, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TripVehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripVehiclesTable,
          TripVehicle,
          $$TripVehiclesTableFilterComposer,
          $$TripVehiclesTableOrderingComposer,
          $$TripVehiclesTableAnnotationComposer,
          $$TripVehiclesTableCreateCompanionBuilder,
          $$TripVehiclesTableUpdateCompanionBuilder,
          (
            TripVehicle,
            BaseReferences<_$AppDatabase, $TripVehiclesTable, TripVehicle>,
          ),
          TripVehicle,
          PrefetchHooks Function()
        > {
  $$TripVehiclesTableTableManager(_$AppDatabase db, $TripVehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripVehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripVehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripVehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> tripLogisticsId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String?> driverMemberId = const Value.absent(),
                Value<String> manifest = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripVehiclesCompanion(
                id: id,
                spaceId: spaceId,
                tripLogisticsId: tripLogisticsId,
                vehicleId: vehicleId,
                driverMemberId: driverMemberId,
                manifest: manifest,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String tripLogisticsId,
                required String vehicleId,
                Value<String?> driverMemberId = const Value.absent(),
                required String manifest,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TripVehiclesCompanion.insert(
                id: id,
                spaceId: spaceId,
                tripLogisticsId: tripLogisticsId,
                vehicleId: vehicleId,
                driverMemberId: driverMemberId,
                manifest: manifest,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripVehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripVehiclesTable,
      TripVehicle,
      $$TripVehiclesTableFilterComposer,
      $$TripVehiclesTableOrderingComposer,
      $$TripVehiclesTableAnnotationComposer,
      $$TripVehiclesTableCreateCompanionBuilder,
      $$TripVehiclesTableUpdateCompanionBuilder,
      (
        TripVehicle,
        BaseReferences<_$AppDatabase, $TripVehiclesTable, TripVehicle>,
      ),
      TripVehicle,
      PrefetchHooks Function()
    >;
typedef $$PermissionSlipsTableCreateCompanionBuilder =
    PermissionSlipsCompanion Function({
      required String id,
      required String spaceId,
      required String subjectId,
      required String tripLogisticsId,
      Value<String?> signerGuardianId,
      Value<String?> signerName,
      required String signedAt,
      Value<String?> sourceUrl,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$PermissionSlipsTableUpdateCompanionBuilder =
    PermissionSlipsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> subjectId,
      Value<String> tripLogisticsId,
      Value<String?> signerGuardianId,
      Value<String?> signerName,
      Value<String> signedAt,
      Value<String?> sourceUrl,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$PermissionSlipsTableFilterComposer
    extends Composer<_$AppDatabase, $PermissionSlipsTable> {
  $$PermissionSlipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripLogisticsId => $composableBuilder(
    column: $table.tripLogisticsId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerGuardianId => $composableBuilder(
    column: $table.signerGuardianId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerName => $composableBuilder(
    column: $table.signerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signedAt => $composableBuilder(
    column: $table.signedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PermissionSlipsTableOrderingComposer
    extends Composer<_$AppDatabase, $PermissionSlipsTable> {
  $$PermissionSlipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripLogisticsId => $composableBuilder(
    column: $table.tripLogisticsId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerGuardianId => $composableBuilder(
    column: $table.signerGuardianId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerName => $composableBuilder(
    column: $table.signerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signedAt => $composableBuilder(
    column: $table.signedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PermissionSlipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PermissionSlipsTable> {
  $$PermissionSlipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get tripLogisticsId => $composableBuilder(
    column: $table.tripLogisticsId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signerGuardianId => $composableBuilder(
    column: $table.signerGuardianId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signerName => $composableBuilder(
    column: $table.signerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signedAt =>
      $composableBuilder(column: $table.signedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PermissionSlipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PermissionSlipsTable,
          PermissionSlip,
          $$PermissionSlipsTableFilterComposer,
          $$PermissionSlipsTableOrderingComposer,
          $$PermissionSlipsTableAnnotationComposer,
          $$PermissionSlipsTableCreateCompanionBuilder,
          $$PermissionSlipsTableUpdateCompanionBuilder,
          (
            PermissionSlip,
            BaseReferences<
              _$AppDatabase,
              $PermissionSlipsTable,
              PermissionSlip
            >,
          ),
          PermissionSlip,
          PrefetchHooks Function()
        > {
  $$PermissionSlipsTableTableManager(
    _$AppDatabase db,
    $PermissionSlipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PermissionSlipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PermissionSlipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PermissionSlipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> tripLogisticsId = const Value.absent(),
                Value<String?> signerGuardianId = const Value.absent(),
                Value<String?> signerName = const Value.absent(),
                Value<String> signedAt = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PermissionSlipsCompanion(
                id: id,
                spaceId: spaceId,
                subjectId: subjectId,
                tripLogisticsId: tripLogisticsId,
                signerGuardianId: signerGuardianId,
                signerName: signerName,
                signedAt: signedAt,
                sourceUrl: sourceUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String subjectId,
                required String tripLogisticsId,
                Value<String?> signerGuardianId = const Value.absent(),
                Value<String?> signerName = const Value.absent(),
                required String signedAt,
                Value<String?> sourceUrl = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PermissionSlipsCompanion.insert(
                id: id,
                spaceId: spaceId,
                subjectId: subjectId,
                tripLogisticsId: tripLogisticsId,
                signerGuardianId: signerGuardianId,
                signerName: signerName,
                signedAt: signedAt,
                sourceUrl: sourceUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PermissionSlipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PermissionSlipsTable,
      PermissionSlip,
      $$PermissionSlipsTableFilterComposer,
      $$PermissionSlipsTableOrderingComposer,
      $$PermissionSlipsTableAnnotationComposer,
      $$PermissionSlipsTableCreateCompanionBuilder,
      $$PermissionSlipsTableUpdateCompanionBuilder,
      (
        PermissionSlip,
        BaseReferences<_$AppDatabase, $PermissionSlipsTable, PermissionSlip>,
      ),
      PermissionSlip,
      PrefetchHooks Function()
    >;
typedef $$HeadcountsTableCreateCompanionBuilder =
    HeadcountsCompanion Function({
      required String id,
      required String spaceId,
      required String scheduleBlockId,
      required String checkpointLabel,
      required int count,
      Value<int?> expectedCount,
      Value<String?> takenByMemberId,
      required String takenAt,
      Value<String?> notes,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$HeadcountsTableUpdateCompanionBuilder =
    HeadcountsCompanion Function({
      Value<String> id,
      Value<String> spaceId,
      Value<String> scheduleBlockId,
      Value<String> checkpointLabel,
      Value<int> count,
      Value<int?> expectedCount,
      Value<String?> takenByMemberId,
      Value<String> takenAt,
      Value<String?> notes,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$HeadcountsTableFilterComposer
    extends Composer<_$AppDatabase, $HeadcountsTable> {
  $$HeadcountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleBlockId => $composableBuilder(
    column: $table.scheduleBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpointLabel => $composableBuilder(
    column: $table.checkpointLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedCount => $composableBuilder(
    column: $table.expectedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get takenByMemberId => $composableBuilder(
    column: $table.takenByMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HeadcountsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeadcountsTable> {
  $$HeadcountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spaceId => $composableBuilder(
    column: $table.spaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleBlockId => $composableBuilder(
    column: $table.scheduleBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpointLabel => $composableBuilder(
    column: $table.checkpointLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedCount => $composableBuilder(
    column: $table.expectedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get takenByMemberId => $composableBuilder(
    column: $table.takenByMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HeadcountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeadcountsTable> {
  $$HeadcountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spaceId =>
      $composableBuilder(column: $table.spaceId, builder: (column) => column);

  GeneratedColumn<String> get scheduleBlockId => $composableBuilder(
    column: $table.scheduleBlockId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkpointLabel => $composableBuilder(
    column: $table.checkpointLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<int> get expectedCount => $composableBuilder(
    column: $table.expectedCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get takenByMemberId => $composableBuilder(
    column: $table.takenByMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HeadcountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeadcountsTable,
          Headcount,
          $$HeadcountsTableFilterComposer,
          $$HeadcountsTableOrderingComposer,
          $$HeadcountsTableAnnotationComposer,
          $$HeadcountsTableCreateCompanionBuilder,
          $$HeadcountsTableUpdateCompanionBuilder,
          (
            Headcount,
            BaseReferences<_$AppDatabase, $HeadcountsTable, Headcount>,
          ),
          Headcount,
          PrefetchHooks Function()
        > {
  $$HeadcountsTableTableManager(_$AppDatabase db, $HeadcountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeadcountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeadcountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeadcountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<String> scheduleBlockId = const Value.absent(),
                Value<String> checkpointLabel = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int?> expectedCount = const Value.absent(),
                Value<String?> takenByMemberId = const Value.absent(),
                Value<String> takenAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeadcountsCompanion(
                id: id,
                spaceId: spaceId,
                scheduleBlockId: scheduleBlockId,
                checkpointLabel: checkpointLabel,
                count: count,
                expectedCount: expectedCount,
                takenByMemberId: takenByMemberId,
                takenAt: takenAt,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String spaceId,
                required String scheduleBlockId,
                required String checkpointLabel,
                required int count,
                Value<int?> expectedCount = const Value.absent(),
                Value<String?> takenByMemberId = const Value.absent(),
                required String takenAt,
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => HeadcountsCompanion.insert(
                id: id,
                spaceId: spaceId,
                scheduleBlockId: scheduleBlockId,
                checkpointLabel: checkpointLabel,
                count: count,
                expectedCount: expectedCount,
                takenByMemberId: takenByMemberId,
                takenAt: takenAt,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HeadcountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeadcountsTable,
      Headcount,
      $$HeadcountsTableFilterComposer,
      $$HeadcountsTableOrderingComposer,
      $$HeadcountsTableAnnotationComposer,
      $$HeadcountsTableCreateCompanionBuilder,
      $$HeadcountsTableUpdateCompanionBuilder,
      (Headcount, BaseReferences<_$AppDatabase, $HeadcountsTable, Headcount>),
      Headcount,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SpacesTableTableManager get spaces =>
      $$SpacesTableTableManager(_db, _db.spaces);
  $$MembersTableTableManager get members =>
      $$MembersTableTableManager(_db, _db.members);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db, _db.subjects);
  $$AttendanceRecordsTableTableManager get attendanceRecords =>
      $$AttendanceRecordsTableTableManager(_db, _db.attendanceRecords);
  $$InvitesTableTableManager get invites =>
      $$InvitesTableTableManager(_db, _db.invites);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db, _db.groupMembers);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$GuardiansTableTableManager get guardians =>
      $$GuardiansTableTableManager(_db, _db.guardians);
  $$SubjectGuardiansTableTableManager get subjectGuardians =>
      $$SubjectGuardiansTableTableManager(_db, _db.subjectGuardians);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$VehicleLogsTableTableManager get vehicleLogs =>
      $$VehicleLogsTableTableManager(_db, _db.vehicleLogs);
  $$MemberCertificationsTableTableManager get memberCertifications =>
      $$MemberCertificationsTableTableManager(_db, _db.memberCertifications);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$SurveyResponsesTableTableManager get surveyResponses =>
      $$SurveyResponsesTableTableManager(_db, _db.surveyResponses);
  $$DismissedInsightsTableTableManager get dismissedInsights =>
      $$DismissedInsightsTableTableManager(_db, _db.dismissedInsights);
  $$CapturesTableTableManager get captures =>
      $$CapturesTableTableManager(_db, _db.captures);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ExportsTableTableManager get exports =>
      $$ExportsTableTableManager(_db, _db.exports);
  $$ExportRecipientsTableTableManager get exportRecipients =>
      $$ExportRecipientsTableTableManager(_db, _db.exportRecipients);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$ScheduleBlocksTableTableManager get scheduleBlocks =>
      $$ScheduleBlocksTableTableManager(_db, _db.scheduleBlocks);
  $$TripLogisticsTableTableManager get tripLogistics =>
      $$TripLogisticsTableTableManager(_db, _db.tripLogistics);
  $$TripVehiclesTableTableManager get tripVehicles =>
      $$TripVehiclesTableTableManager(_db, _db.tripVehicles);
  $$PermissionSlipsTableTableManager get permissionSlips =>
      $$PermissionSlipsTableTableManager(_db, _db.permissionSlips);
  $$HeadcountsTableTableManager get headcounts =>
      $$HeadcountsTableTableManager(_db, _db.headcounts);
}
