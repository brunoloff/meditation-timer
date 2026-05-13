part of 'main.dart';

class MeditationLogEntry {
  const MeditationLogEntry({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.preset,
    required this.activity,
  });

  final String id;
  final DateTime startedAt;
  final Duration duration;
  final String preset;
  final String activity;

  MeditationLogEntry copyWith({
    String? id,
    DateTime? startedAt,
    Duration? duration,
    String? preset,
    String? activity,
  }) {
    return MeditationLogEntry(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      preset: preset ?? this.preset,
      activity: activity ?? this.activity,
    );
  }
}

class MeditationLogStore {
  const MeditationLogStore();

  static const int defaultPageSize = 50;

  Future<void> append(MeditationLogEntry entry) async {
    await _migrateLegacyAndroidLogsIfNeeded();
    final entries = List<MeditationLogEntry>.of(await _loadAllAsync());
    entries.insert(0, entry);
    await _saveAll(entries);
  }

  Future<LogQueryResult> query({
    DateTime? startDate,
    DateTime? endDate,
    int offset = 0,
    int limit = defaultPageSize,
  }) async {
    await _migrateLegacyAndroidLogsIfNeeded();
    final entries = _filterEntries(
      await _loadAllAsync(),
      startDate: startDate,
      endDate: endDate,
    );
    final safeOffset = offset.clamp(0, entries.length);
    final endOffset = (safeOffset + limit).clamp(safeOffset, entries.length);

    return LogQueryResult(
      entries: entries.sublist(safeOffset, endOffset),
      totalCount: entries.length,
      nextOffset: endOffset,
      hasMore: endOffset < entries.length,
    );
  }

  Future<void> applyChanges({
    required List<MeditationLogEntry> additions,
    required Set<String> deletedIds,
  }) async {
    await _migrateLegacyAndroidLogsIfNeeded();
    final existingEntries = await _loadAllAsync();
    final updatedEntries = [
      ...additions,
      for (final entry in existingEntries)
        if (!deletedIds.contains(entry.id)) entry,
    ];
    updatedEntries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _saveAll(updatedEntries);
  }

  Future<LogImportResult> importCsv(String csvText) async {
    await _migrateLegacyAndroidLogsIfNeeded();
    final parsedEntries = _decodeMeditationLogsCsv(csvText);
    final existingEntries = await _loadAllAsync();
    final existingKeys = {
      for (final entry in existingEntries) _logContentKey(entry),
    };
    final additions = <MeditationLogEntry>[];

    for (final entry in parsedEntries.entries) {
      if (existingKeys.add(_logContentKey(entry))) {
        additions.add(entry);
      }
    }

    if (additions.isNotEmpty) {
      final updatedEntries = [...additions, ...existingEntries]
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      await _saveAll(updatedEntries);
    }

    return LogImportResult(
      importedCount: additions.length,
      skippedCount:
          parsedEntries.skippedCount +
          (parsedEntries.entries.length - additions.length),
    );
  }

  Future<String> exportCsv() async {
    await _migrateLegacyAndroidLogsIfNeeded();
    return _encodeMeditationLogsCsv(await _loadAllAsync());
  }

  Future<List<MeditationLogEntry>> allEntries() async {
    await _migrateLegacyAndroidLogsIfNeeded();
    return _loadAllAsync();
  }

  Future<void> purgeAll() async {
    await _migrateLegacyAndroidLogsIfNeeded();
    await _asyncPreferences().remove(_meditationLogsKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_meditationLogsKey);
  }

  Future<List<MeditationLogEntry>> _loadAllAsync() async {
    final encodedAsyncLogs = await _asyncPreferences().getString(
      _meditationLogsKey,
    );
    final asyncLogs = _decodeMeditationLogs(encodedAsyncLogs);
    if (asyncLogs.isNotEmpty) {
      return asyncLogs;
    }

    final preferences = await SharedPreferences.getInstance();
    final encodedLogs = preferences.getString(_meditationLogsKey);
    return _decodeMeditationLogs(encodedLogs);
  }

  Future<void> _saveAll(List<MeditationLogEntry> entries) async {
    final encodedLogs = jsonEncode([
      for (final entry in entries) _encodeMeditationLog(entry),
    ]);
    await _asyncPreferences().setString(_meditationLogsKey, encodedLogs);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_meditationLogsKey, encodedLogs);
  }
}

Future<void> _migrateLegacyAndroidLogsIfNeeded() async {
  final preferences = await SharedPreferences.getInstance();
  final asyncPreferences = _asyncPreferences();
  final asyncMigrationDone =
      await asyncPreferences.getBool(_legacyAndroidLogsMigrationKey) ?? false;
  final legacyMigrationDone =
      preferences.getBool(_legacyAndroidLogsMigrationKey) ?? false;
  if (asyncMigrationDone && legacyMigrationDone) {
    return;
  }

  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    await asyncPreferences.setBool(_legacyAndroidLogsMigrationKey, true);
    await preferences.setBool(_legacyAndroidLogsMigrationKey, true);
    return;
  }

  final currentLogs = [
    ..._decodeMeditationLogs(
      await asyncPreferences.getString(_meditationLogsKey),
    ),
    ..._decodeMeditationLogs(preferences.getString(_meditationLogsKey)),
  ];
  if (currentLogs.isNotEmpty) {
    final mergedByContent = <String, MeditationLogEntry>{
      for (final entry in currentLogs) _logContentKey(entry): entry,
    };
    final mergedLogs = mergedByContent.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final encodedLogs = jsonEncode([
      for (final entry in mergedLogs) _encodeMeditationLog(entry),
    ]);
    await asyncPreferences.setString(_meditationLogsKey, encodedLogs);
    await preferences.setString(_meditationLogsKey, encodedLogs);
  }

  await asyncPreferences.setBool(_legacyAndroidLogsMigrationKey, true);
  await preferences.setBool(_legacyAndroidLogsMigrationKey, true);
}

SharedPreferencesAsync _asyncPreferences() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return SharedPreferencesAsync(
      options: const SharedPreferencesAsyncAndroidOptions(
        backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
        originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
          fileName: 'FlutterSharedPreferences',
        ),
      ),
    );
  }

  return SharedPreferencesAsync();
}

class LogQueryResult {
  const LogQueryResult({
    required this.entries,
    required this.totalCount,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<MeditationLogEntry> entries;
  final int totalCount;
  final int nextOffset;
  final bool hasMore;
}

class LogImportResult {
  const LogImportResult({
    required this.importedCount,
    required this.skippedCount,
  });

  final int importedCount;
  final int skippedCount;
}

List<MeditationLogEntry> _filterEntries(
  List<MeditationLogEntry> entries, {
  DateTime? startDate,
  DateTime? endDate,
}) {
  return [
    for (final entry in entries)
      if ((startDate == null || !entry.startedAt.isBefore(startDate)) &&
          (endDate == null ||
              entry.startedAt.isBefore(
                DateTime(endDate.year, endDate.month, endDate.day + 1),
              )))
        entry,
  ];
}

Map<String, Object?> _encodeMeditationLog(MeditationLogEntry entry) {
  return {
    'id': entry.id,
    'startedAt': entry.startedAt.toIso8601String(),
    'durationSeconds': entry.duration.inSeconds,
    'preset': entry.preset,
    'activity': entry.activity,
  };
}

List<MeditationLogEntry> _decodeMeditationLogs(String? encodedLogs) {
  if (encodedLogs == null) {
    return const [];
  }

  try {
    // Stored logs are append-heavy and user-editable via import/export. Skip
    // malformed rows instead of failing the whole history, then keep newest
    // entries first for paged browsing.
    final decoded = jsonDecode(encodedLogs);
    if (decoded is! List) {
      return const [];
    }

    final entries = <MeditationLogEntry>[];
    for (final item in decoded) {
      final entry = _decodeMeditationLog(item);
      if (entry != null) {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  } on FormatException {
    return const [];
  } on TypeError {
    return const [];
  }
}

MeditationLogEntry? _decodeMeditationLog(Object? encodedLog) {
  if (encodedLog is! Map<String, Object?>) {
    return null;
  }

  final id = encodedLog['id'];
  final startedAt = encodedLog['startedAt'];
  final durationSeconds = encodedLog['durationSeconds'];
  final preset = encodedLog['preset'];
  final activity = encodedLog['activity'];

  if (id is! String ||
      startedAt is! String ||
      durationSeconds is! int ||
      preset is! String ||
      activity is! String) {
    return null;
  }

  final parsedStartedAt = DateTime.tryParse(startedAt);
  if (parsedStartedAt == null || durationSeconds < 0) {
    return null;
  }

  return MeditationLogEntry(
    id: id,
    startedAt: parsedStartedAt,
    duration: Duration(seconds: durationSeconds),
    preset: preset,
    activity: activity,
  );
}

String _newLogId() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

String _formatCsvDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final year = dateTime.year.toString().padLeft(4, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  return '$month/$day/$year $hour:$minute:$second';
}

String _formatCsvDuration(Duration duration) {
  return '${duration.inHours}:${duration.inMinutes.remainder(60)}:${duration.inSeconds.remainder(60)}';
}

String _encodeMeditationLogsCsv(List<MeditationLogEntry> entries) {
  final buffer = StringBuffer('Started At,Duration,Preset,Activity\r\n');
  for (final entry in entries) {
    buffer
      ..write(_escapeCsvCell(_formatCsvDateTime(entry.startedAt)))
      ..write(',')
      ..write(_escapeCsvCell(_formatCsvDuration(entry.duration)))
      ..write(',')
      ..write(_escapeCsvCell(entry.preset))
      ..write(',')
      ..write(_escapeCsvCell(entry.activity))
      ..write('\r\n');
  }
  return buffer.toString();
}

String _escapeCsvCell(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) {
    return value;
  }

  return '"${value.replaceAll('"', '""')}"';
}

({List<MeditationLogEntry> entries, int skippedCount}) _decodeMeditationLogsCsv(
  String csvText,
) {
  final rows = _parseCsvRows(csvText);
  if (rows.isEmpty) {
    return (entries: const [], skippedCount: 0);
  }

  final header = rows.first
      .map((value) => value.trim().toLowerCase())
      .toList(growable: false);
  final startedAtIndex = header.indexOf('started at');
  final durationIndex = header.indexOf('duration');
  final presetIndex = header.indexOf('preset');
  final activityIndex = header.indexOf('activity');
  if (startedAtIndex < 0 ||
      durationIndex < 0 ||
      presetIndex < 0 ||
      activityIndex < 0) {
    return (entries: const [], skippedCount: rows.length - 1);
  }

  final entries = <MeditationLogEntry>[];
  var skippedCount = 0;
  for (final row in rows.skip(1)) {
    final lastRequiredIndex = [
      startedAtIndex,
      durationIndex,
      presetIndex,
      activityIndex,
    ].reduce((a, b) => a > b ? a : b);
    if (row.length <= lastRequiredIndex) {
      skippedCount += 1;
      continue;
    }

    final startedAt = _parseCsvDateTime(row[startedAtIndex]);
    final duration = _parseCsvDuration(row[durationIndex]);
    if (startedAt == null || duration == null) {
      skippedCount += 1;
      continue;
    }

    final preset = row[presetIndex].trim();
    final activity = row[activityIndex].trim().isEmpty
        ? 'Meditation'
        : row[activityIndex].trim();

    entries.add(
      MeditationLogEntry(
        id: _csvLogId(
          startedAt: startedAt,
          duration: duration,
          preset: preset,
          activity: activity,
        ),
        startedAt: startedAt,
        duration: duration,
        preset: preset,
        activity: activity,
      ),
    );
  }

  entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return (entries: entries, skippedCount: skippedCount);
}

List<List<String>> _parseCsvRows(String csvText) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < csvText.length; index += 1) {
    final character = csvText[index];

    if (inQuotes) {
      if (character == '"') {
        final nextCharacter = index + 1 < csvText.length
            ? csvText[index + 1]
            : null;
        if (nextCharacter == '"') {
          field.write('"');
          index += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(character);
      }
      continue;
    }

    if (character == '"') {
      inQuotes = true;
    } else if (character == ',') {
      row.add(field.toString());
      field.clear();
    } else if (character == '\n') {
      row.add(field.toString());
      field.clear();
      if (!_isEmptyCsvRow(row)) {
        rows.add(row);
      }
      row = <String>[];
    } else if (character != '\r') {
      field.write(character);
    }
  }

  row.add(field.toString());
  if (!_isEmptyCsvRow(row)) {
    rows.add(row);
  }

  return rows;
}

bool _isEmptyCsvRow(List<String> row) {
  return row.every((field) => field.trim().isEmpty);
}

DateTime? _parseCsvDateTime(String value) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})$',
  ).firstMatch(value.trim());
  if (match == null) {
    return null;
  }

  final month = int.parse(match.group(1)!);
  final day = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final parsed = DateTime(year, month, day, hour, minute, second);

  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    return null;
  }

  return parsed;
}

Duration? _parseCsvDuration(String value) {
  final parts = value.split(':');
  if (parts.length != 3) {
    return null;
  }

  final hours = int.tryParse(parts[0].trim());
  final minutes = int.tryParse(parts[1].trim());
  final seconds = int.tryParse(parts[2].trim());

  if (hours == null ||
      minutes == null ||
      seconds == null ||
      hours < 0 ||
      minutes < 0 ||
      seconds < 0) {
    return null;
  }

  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

String _csvLogId({
  required DateTime startedAt,
  required Duration duration,
  required String preset,
  required String activity,
}) {
  final source = [
    startedAt.toIso8601String(),
    duration.inSeconds.toString(),
    preset,
    activity,
  ].join('|');
  return 'csv-${base64Url.encode(utf8.encode(source)).replaceAll('=', '')}';
}

String _logContentKey(MeditationLogEntry entry) {
  return [
    entry.startedAt.toIso8601String(),
    entry.duration.inSeconds.toString(),
    entry.preset,
    entry.activity,
  ].join('|');
}
