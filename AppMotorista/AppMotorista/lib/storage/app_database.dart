import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({
    DatabaseFactory? factory,
    String? databasePath,
    String databaseFileName = AppDatabase.databaseFileName,
  }) : _factory = factory ?? databaseFactory,
       _databasePath = databasePath,
       _databaseFileName = databaseFileName;

  static const schemaVersion = 3;
  static const databaseFileName = 'app_motorista.db';

  static const localTripTable = 'local_trip';
  static const localStopTable = 'local_stop';
  static const localOrderTable = 'local_order';
  static const localOccurrenceTable = 'local_occurrence';
  static const outboxOperationTable = 'outbox_operation';
  static const tripDownloadTable = 'trip_download';

  final DatabaseFactory _factory;
  final String? _databasePath;
  final String _databaseFileName;

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database {
    final opened = _database;
    if (opened != null) return Future.value(opened);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      final resolvedPath =
          _databasePath ??
          path.join(await getDatabasesPath(), _databaseFileName);
      final opened = await _factory.openDatabase(
        resolvedPath,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (database) async {
            await database.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: _createSchema,
          onUpgrade: _upgradeSchema,
        ),
      );
      _database = opened;
      return opened;
    } finally {
      _opening = null;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await opening;
    final opened = _database;
    _database = null;
    if (opened != null && opened.isOpen) await opened.close();
  }

  static Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $localTripTable (
        driver_guid TEXT NOT NULL,
        manifest_guid TEXT NOT NULL,
        load_id INTEGER NOT NULL,
        manifest_status TEXT NOT NULL,
        description TEXT NOT NULL,
        driver_name TEXT NOT NULL,
        origin_name TEXT NOT NULL,
        departure_date TEXT,
        departure_time TEXT,
        occurrence_count INTEGER NOT NULL CHECK (occurrence_count >= 0),
        downloaded_at TEXT NOT NULL,
        last_server_sync_at TEXT,
        sync_state TEXT NOT NULL CHECK (
          sync_state IN ('synced','pending','sending','retry','rejected','conflict')
        ),
        PRIMARY KEY (driver_guid, manifest_guid)
      )
    ''');
    await database.execute('''
      CREATE TABLE $localStopTable (
        driver_guid TEXT NOT NULL,
        manifest_guid TEXT NOT NULL,
        stop_id INTEGER NOT NULL,
        sort_index INTEGER NOT NULL CHECK (sort_index >= 0),
        planned_order INTEGER NOT NULL,
        status TEXT NOT NULL,
        client_name TEXT NOT NULL,
        city TEXT NOT NULL,
        state TEXT NOT NULL,
        address TEXT NOT NULL,
        PRIMARY KEY (driver_guid, manifest_guid, stop_id),
        FOREIGN KEY (driver_guid, manifest_guid)
          REFERENCES $localTripTable (driver_guid, manifest_guid)
          ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE $localOrderTable (
        driver_guid TEXT NOT NULL,
        manifest_guid TEXT NOT NULL,
        stop_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        sort_index INTEGER NOT NULL CHECK (sort_index >= 0),
        status TEXT NOT NULL,
        PRIMARY KEY (driver_guid, manifest_guid, stop_id, order_id),
        FOREIGN KEY (driver_guid, manifest_guid, stop_id)
          REFERENCES $localStopTable (driver_guid, manifest_guid, stop_id)
          ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE $localOccurrenceTable (
        driver_guid TEXT NOT NULL,
        manifest_guid TEXT NOT NULL,
        occurrence_guid TEXT NOT NULL,
        occurrence_id INTEGER NOT NULL,
        stop_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        sort_index INTEGER NOT NULL CHECK (sort_index >= 0),
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('C','R')),
        code TEXT NOT NULL,
        roll_id INTEGER,
        quantity TEXT NOT NULL,
        status TEXT NOT NULL,
        sync_state TEXT NOT NULL CHECK (
          sync_state IN ('synced','pending','sending','retry','rejected','conflict')
        ),
        PRIMARY KEY (driver_guid, manifest_guid, occurrence_guid),
        FOREIGN KEY (driver_guid, manifest_guid, stop_id, order_id)
          REFERENCES $localOrderTable (
            driver_guid, manifest_guid, stop_id, order_id
          ) ON DELETE CASCADE,
        CHECK (
          (type = 'C' AND roll_id IS NULL) OR
          (type = 'R' AND roll_id IS NOT NULL)
        )
      )
    ''');
    await database.execute('''
      CREATE TABLE $outboxOperationTable (
        operation_guid TEXT PRIMARY KEY NOT NULL,
        operation_type TEXT NOT NULL,
        payload_version INTEGER NOT NULL CHECK (payload_version > 0),
        driver_guid TEXT NOT NULL,
        manifest_guid TEXT NOT NULL,
        occurrence_guid TEXT,
        stop_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        code TEXT NOT NULL,
        device_datetime TEXT NOT NULL,
        timezone_offset_minutes INTEGER NOT NULL,
        payload_json TEXT NOT NULL,
        state TEXT NOT NULL CHECK (
          state IN ('synced','pending','sending','retry','rejected','conflict')
        ),
        attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
        created_at TEXT NOT NULL,
        last_attempt_at TEXT,
        next_attempt_at TEXT,
        synced_at TEXT,
        response_code TEXT,
        response_json TEXT,
        last_error TEXT
      )
    ''');

    await database.execute(
      'CREATE INDEX ix_local_trip_driver '
      'ON $localTripTable (driver_guid, downloaded_at DESC)',
    );
    await database.execute(
      'CREATE INDEX ix_local_stop_order '
      'ON $localStopTable (driver_guid, manifest_guid, sort_index)',
    );
    await database.execute(
      'CREATE INDEX ix_local_order_status '
      'ON $localOrderTable '
      '(driver_guid, manifest_guid, stop_id, status, sort_index)',
    );
    await database.execute(
      'CREATE INDEX ix_local_occurrence_order '
      'ON $localOccurrenceTable '
      '(driver_guid, manifest_guid, stop_id, order_id, status, sort_index)',
    );
    await database.execute(
      'CREATE INDEX ix_local_occurrence_code '
      'ON $localOccurrenceTable '
      '(driver_guid, manifest_guid, stop_id, order_id, code, status)',
    );
    await database.execute(
      'CREATE INDEX ix_outbox_state_created '
      'ON $outboxOperationTable (state, created_at)',
    );
    await database.execute(
      'CREATE INDEX ix_outbox_manifest '
      'ON $outboxOperationTable (driver_guid, manifest_guid, created_at)',
    );
    await _createTripDownloadTable(database);
  }

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE $outboxOperationTable ADD COLUMN occurrence_guid TEXT',
      );
    }
    if (oldVersion < 3) {
      await _createTripDownloadTable(database);
    }
  }

  static Future<void> _createTripDownloadTable(Database database) {
    return database.execute('''
      CREATE TABLE IF NOT EXISTS $tripDownloadTable (
        driver_guid TEXT NOT NULL,
        manifest_guid TEXT NOT NULL,
        state TEXT NOT NULL CHECK (state IN ('pending','failed')),
        error_message TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (driver_guid, manifest_guid)
      )
    ''');
  }
}
