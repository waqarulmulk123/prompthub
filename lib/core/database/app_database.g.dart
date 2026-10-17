// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedPromptsTableTable extends CachedPromptsTable
    with TableInfo<$CachedPromptsTableTable, CachedPromptsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPromptsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawPromptMeta = const VerificationMeta(
    'rawPrompt',
  );
  @override
  late final GeneratedColumn<String> rawPrompt = GeneratedColumn<String>(
    'raw_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    rawPrompt,
    category,
    payload,
    rank,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_prompts_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedPromptsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('raw_prompt')) {
      context.handle(
        _rawPromptMeta,
        rawPrompt.isAcceptableOrUnknown(data['raw_prompt']!, _rawPromptMeta),
      );
    } else if (isInserting) {
      context.missing(_rawPromptMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedPromptsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPromptsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      rawPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_prompt'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
    );
  }

  @override
  $CachedPromptsTableTable createAlias(String alias) {
    return $CachedPromptsTableTable(attachedDatabase, alias);
  }
}

class CachedPromptsTableData extends DataClass
    implements Insertable<CachedPromptsTableData> {
  final String id;
  final String title;
  final String rawPrompt;
  final String category;
  final String payload;
  final int rank;
  const CachedPromptsTableData({
    required this.id,
    required this.title,
    required this.rawPrompt,
    required this.category,
    required this.payload,
    required this.rank,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['raw_prompt'] = Variable<String>(rawPrompt);
    map['category'] = Variable<String>(category);
    map['payload'] = Variable<String>(payload);
    map['rank'] = Variable<int>(rank);
    return map;
  }

  CachedPromptsTableCompanion toCompanion(bool nullToAbsent) {
    return CachedPromptsTableCompanion(
      id: Value(id),
      title: Value(title),
      rawPrompt: Value(rawPrompt),
      category: Value(category),
      payload: Value(payload),
      rank: Value(rank),
    );
  }

  factory CachedPromptsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPromptsTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      rawPrompt: serializer.fromJson<String>(json['rawPrompt']),
      category: serializer.fromJson<String>(json['category']),
      payload: serializer.fromJson<String>(json['payload']),
      rank: serializer.fromJson<int>(json['rank']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'rawPrompt': serializer.toJson<String>(rawPrompt),
      'category': serializer.toJson<String>(category),
      'payload': serializer.toJson<String>(payload),
      'rank': serializer.toJson<int>(rank),
    };
  }

  CachedPromptsTableData copyWith({
    String? id,
    String? title,
    String? rawPrompt,
    String? category,
    String? payload,
    int? rank,
  }) => CachedPromptsTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    rawPrompt: rawPrompt ?? this.rawPrompt,
    category: category ?? this.category,
    payload: payload ?? this.payload,
    rank: rank ?? this.rank,
  );
  CachedPromptsTableData copyWithCompanion(CachedPromptsTableCompanion data) {
    return CachedPromptsTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      rawPrompt: data.rawPrompt.present ? data.rawPrompt.value : this.rawPrompt,
      category: data.category.present ? data.category.value : this.category,
      payload: data.payload.present ? data.payload.value : this.payload,
      rank: data.rank.present ? data.rank.value : this.rank,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPromptsTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('rawPrompt: $rawPrompt, ')
          ..write('category: $category, ')
          ..write('payload: $payload, ')
          ..write('rank: $rank')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, rawPrompt, category, payload, rank);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPromptsTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.rawPrompt == this.rawPrompt &&
          other.category == this.category &&
          other.payload == this.payload &&
          other.rank == this.rank);
}

class CachedPromptsTableCompanion
    extends UpdateCompanion<CachedPromptsTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> rawPrompt;
  final Value<String> category;
  final Value<String> payload;
  final Value<int> rank;
  final Value<int> rowid;
  const CachedPromptsTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.rawPrompt = const Value.absent(),
    this.category = const Value.absent(),
    this.payload = const Value.absent(),
    this.rank = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPromptsTableCompanion.insert({
    required String id,
    required String title,
    required String rawPrompt,
    required String category,
    required String payload,
    required int rank,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       rawPrompt = Value(rawPrompt),
       category = Value(category),
       payload = Value(payload),
       rank = Value(rank);
  static Insertable<CachedPromptsTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? rawPrompt,
    Expression<String>? category,
    Expression<String>? payload,
    Expression<int>? rank,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (rawPrompt != null) 'raw_prompt': rawPrompt,
      if (category != null) 'category': category,
      if (payload != null) 'payload': payload,
      if (rank != null) 'rank': rank,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPromptsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? rawPrompt,
    Value<String>? category,
    Value<String>? payload,
    Value<int>? rank,
    Value<int>? rowid,
  }) {
    return CachedPromptsTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      rawPrompt: rawPrompt ?? this.rawPrompt,
      category: category ?? this.category,
      payload: payload ?? this.payload,
      rank: rank ?? this.rank,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rawPrompt.present) {
      map['raw_prompt'] = Variable<String>(rawPrompt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPromptsTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('rawPrompt: $rawPrompt, ')
          ..write('category: $category, ')
          ..write('payload: $payload, ')
          ..write('rank: $rank, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBookmarksTable extends LocalBookmarks
    with TableInfo<$LocalBookmarksTable, LocalBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptIdMeta = const VerificationMeta(
    'promptId',
  );
  @override
  late final GeneratedColumn<String> promptId = GeneratedColumn<String>(
    'prompt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variablesMeta = const VerificationMeta(
    'variables',
  );
  @override
  late final GeneratedColumn<String> variables = GeneratedColumn<String>(
    'variables',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    promptId,
    variables,
    collectionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('prompt_id')) {
      context.handle(
        _promptIdMeta,
        promptId.isAcceptableOrUnknown(data['prompt_id']!, _promptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_promptIdMeta);
    }
    if (data.containsKey('variables')) {
      context.handle(
        _variablesMeta,
        variables.isAcceptableOrUnknown(data['variables']!, _variablesMeta),
      );
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, promptId};
  @override
  LocalBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBookmark(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      promptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_id'],
      )!,
      variables: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variables'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      ),
    );
  }

  @override
  $LocalBookmarksTable createAlias(String alias) {
    return $LocalBookmarksTable(attachedDatabase, alias);
  }
}

class LocalBookmark extends DataClass implements Insertable<LocalBookmark> {
  final String userId;
  final String promptId;
  final String variables;
  final String? collectionId;
  const LocalBookmark({
    required this.userId,
    required this.promptId,
    required this.variables,
    this.collectionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['prompt_id'] = Variable<String>(promptId);
    map['variables'] = Variable<String>(variables);
    if (!nullToAbsent || collectionId != null) {
      map['collection_id'] = Variable<String>(collectionId);
    }
    return map;
  }

  LocalBookmarksCompanion toCompanion(bool nullToAbsent) {
    return LocalBookmarksCompanion(
      userId: Value(userId),
      promptId: Value(promptId),
      variables: Value(variables),
      collectionId: collectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionId),
    );
  }

  factory LocalBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBookmark(
      userId: serializer.fromJson<String>(json['userId']),
      promptId: serializer.fromJson<String>(json['promptId']),
      variables: serializer.fromJson<String>(json['variables']),
      collectionId: serializer.fromJson<String?>(json['collectionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'promptId': serializer.toJson<String>(promptId),
      'variables': serializer.toJson<String>(variables),
      'collectionId': serializer.toJson<String?>(collectionId),
    };
  }

  LocalBookmark copyWith({
    String? userId,
    String? promptId,
    String? variables,
    Value<String?> collectionId = const Value.absent(),
  }) => LocalBookmark(
    userId: userId ?? this.userId,
    promptId: promptId ?? this.promptId,
    variables: variables ?? this.variables,
    collectionId: collectionId.present ? collectionId.value : this.collectionId,
  );
  LocalBookmark copyWithCompanion(LocalBookmarksCompanion data) {
    return LocalBookmark(
      userId: data.userId.present ? data.userId.value : this.userId,
      promptId: data.promptId.present ? data.promptId.value : this.promptId,
      variables: data.variables.present ? data.variables.value : this.variables,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookmark(')
          ..write('userId: $userId, ')
          ..write('promptId: $promptId, ')
          ..write('variables: $variables, ')
          ..write('collectionId: $collectionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, promptId, variables, collectionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBookmark &&
          other.userId == this.userId &&
          other.promptId == this.promptId &&
          other.variables == this.variables &&
          other.collectionId == this.collectionId);
}

class LocalBookmarksCompanion extends UpdateCompanion<LocalBookmark> {
  final Value<String> userId;
  final Value<String> promptId;
  final Value<String> variables;
  final Value<String?> collectionId;
  final Value<int> rowid;
  const LocalBookmarksCompanion({
    this.userId = const Value.absent(),
    this.promptId = const Value.absent(),
    this.variables = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBookmarksCompanion.insert({
    required String userId,
    required String promptId,
    this.variables = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       promptId = Value(promptId);
  static Insertable<LocalBookmark> custom({
    Expression<String>? userId,
    Expression<String>? promptId,
    Expression<String>? variables,
    Expression<String>? collectionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (promptId != null) 'prompt_id': promptId,
      if (variables != null) 'variables': variables,
      if (collectionId != null) 'collection_id': collectionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBookmarksCompanion copyWith({
    Value<String>? userId,
    Value<String>? promptId,
    Value<String>? variables,
    Value<String?>? collectionId,
    Value<int>? rowid,
  }) {
    return LocalBookmarksCompanion(
      userId: userId ?? this.userId,
      promptId: promptId ?? this.promptId,
      variables: variables ?? this.variables,
      collectionId: collectionId ?? this.collectionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (promptId.present) {
      map['prompt_id'] = Variable<String>(promptId.value);
    }
    if (variables.present) {
      map['variables'] = Variable<String>(variables.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBookmarksCompanion(')
          ..write('userId: $userId, ')
          ..write('promptId: $promptId, ')
          ..write('variables: $variables, ')
          ..write('collectionId: $collectionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedPromptsTableTable cachedPromptsTable =
      $CachedPromptsTableTable(this);
  late final $LocalBookmarksTable localBookmarks = $LocalBookmarksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedPromptsTable,
    localBookmarks,
  ];
}

typedef $$CachedPromptsTableTableCreateCompanionBuilder =
    CachedPromptsTableCompanion Function({
      required String id,
      required String title,
      required String rawPrompt,
      required String category,
      required String payload,
      required int rank,
      Value<int> rowid,
    });
typedef $$CachedPromptsTableTableUpdateCompanionBuilder =
    CachedPromptsTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> rawPrompt,
      Value<String> category,
      Value<String> payload,
      Value<int> rank,
      Value<int> rowid,
    });

class $$CachedPromptsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CachedPromptsTableTable> {
  $$CachedPromptsTableTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawPrompt => $composableBuilder(
    column: $table.rawPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedPromptsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedPromptsTableTable> {
  $$CachedPromptsTableTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawPrompt => $composableBuilder(
    column: $table.rawPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedPromptsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedPromptsTableTable> {
  $$CachedPromptsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get rawPrompt =>
      $composableBuilder(column: $table.rawPrompt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);
}

class $$CachedPromptsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedPromptsTableTable,
          CachedPromptsTableData,
          $$CachedPromptsTableTableFilterComposer,
          $$CachedPromptsTableTableOrderingComposer,
          $$CachedPromptsTableTableAnnotationComposer,
          $$CachedPromptsTableTableCreateCompanionBuilder,
          $$CachedPromptsTableTableUpdateCompanionBuilder,
          (
            CachedPromptsTableData,
            BaseReferences<
              _$AppDatabase,
              $CachedPromptsTableTable,
              CachedPromptsTableData
            >,
          ),
          CachedPromptsTableData,
          PrefetchHooks Function()
        > {
  $$CachedPromptsTableTableTableManager(
    _$AppDatabase db,
    $CachedPromptsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPromptsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPromptsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPromptsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> rawPrompt = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPromptsTableCompanion(
                id: id,
                title: title,
                rawPrompt: rawPrompt,
                category: category,
                payload: payload,
                rank: rank,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String rawPrompt,
                required String category,
                required String payload,
                required int rank,
                Value<int> rowid = const Value.absent(),
              }) => CachedPromptsTableCompanion.insert(
                id: id,
                title: title,
                rawPrompt: rawPrompt,
                category: category,
                payload: payload,
                rank: rank,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedPromptsTableTable, CachedPromptsTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedPromptsTableTable,
                    CachedPromptsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedPromptsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedPromptsTableTable,
      CachedPromptsTableData,
      $$CachedPromptsTableTableFilterComposer,
      $$CachedPromptsTableTableOrderingComposer,
      $$CachedPromptsTableTableAnnotationComposer,
      $$CachedPromptsTableTableCreateCompanionBuilder,
      $$CachedPromptsTableTableUpdateCompanionBuilder,
      (
        CachedPromptsTableData,
        BaseReferences<
          _$AppDatabase,
          $CachedPromptsTableTable,
          CachedPromptsTableData
        >,
      ),
      CachedPromptsTableData,
      PrefetchHooks Function()
    >;
typedef $$LocalBookmarksTableCreateCompanionBuilder =
    LocalBookmarksCompanion Function({
      required String userId,
      required String promptId,
      Value<String> variables,
      Value<String?> collectionId,
      Value<int> rowid,
    });
typedef $$LocalBookmarksTableUpdateCompanionBuilder =
    LocalBookmarksCompanion Function({
      Value<String> userId,
      Value<String> promptId,
      Value<String> variables,
      Value<String?> collectionId,
      Value<int> rowid,
    });

class $$LocalBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBookmarksTable> {
  $$LocalBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variables => $composableBuilder(
    column: $table.variables,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBookmarksTable> {
  $$LocalBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variables => $composableBuilder(
    column: $table.variables,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBookmarksTable> {
  $$LocalBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get promptId =>
      $composableBuilder(column: $table.promptId, builder: (column) => column);

  GeneratedColumn<String> get variables =>
      $composableBuilder(column: $table.variables, builder: (column) => column);

  GeneratedColumn<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );
}

class $$LocalBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBookmarksTable,
          LocalBookmark,
          $$LocalBookmarksTableFilterComposer,
          $$LocalBookmarksTableOrderingComposer,
          $$LocalBookmarksTableAnnotationComposer,
          $$LocalBookmarksTableCreateCompanionBuilder,
          $$LocalBookmarksTableUpdateCompanionBuilder,
          (
            LocalBookmark,
            BaseReferences<_$AppDatabase, $LocalBookmarksTable, LocalBookmark>,
          ),
          LocalBookmark,
          PrefetchHooks Function()
        > {
  $$LocalBookmarksTableTableManager(
    _$AppDatabase db,
    $LocalBookmarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> promptId = const Value.absent(),
                Value<String> variables = const Value.absent(),
                Value<String?> collectionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBookmarksCompanion(
                userId: userId,
                promptId: promptId,
                variables: variables,
                collectionId: collectionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String promptId,
                Value<String> variables = const Value.absent(),
                Value<String?> collectionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBookmarksCompanion.insert(
                userId: userId,
                promptId: promptId,
                variables: variables,
                collectionId: collectionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalBookmarksTable, LocalBookmark>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalBookmarksTable,
                    LocalBookmark
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBookmarksTable,
      LocalBookmark,
      $$LocalBookmarksTableFilterComposer,
      $$LocalBookmarksTableOrderingComposer,
      $$LocalBookmarksTableAnnotationComposer,
      $$LocalBookmarksTableCreateCompanionBuilder,
      $$LocalBookmarksTableUpdateCompanionBuilder,
      (
        LocalBookmark,
        BaseReferences<_$AppDatabase, $LocalBookmarksTable, LocalBookmark>,
      ),
      LocalBookmark,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedPromptsTableTableTableManager get cachedPromptsTable =>
      $$CachedPromptsTableTableTableManager(_db, _db.cachedPromptsTable);
  $$LocalBookmarksTableTableManager get localBookmarks =>
      $$LocalBookmarksTableTableManager(_db, _db.localBookmarks);
}
