import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vfcost_presupuesto/data/sample_projects.dart';
import 'package:vfcost_presupuesto/models/presupuesto.dart';
import 'package:vfcost_presupuesto/services/cloud_drive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudDriveService & Google Drive Backup Tests', () {
    test('User email, cloud URL and autoSync settings persist in SharedPreferences', () async {
      expect(await CloudDriveService.getUserEmail(), equals('miempresa@gmail.com'));

      await CloudDriveService.setUserEmail('constructora.ingenieria@gmail.com');
      expect(await CloudDriveService.getUserEmail(), equals('constructora.ingenieria@gmail.com'));

      await CloudDriveService.setCloudUrl('https://script.google.com/macros/s/TEST/exec');
      expect(await CloudDriveService.getCloudUrl(), equals('https://script.google.com/macros/s/TEST/exec'));

      await CloudDriveService.setAutoSyncEnabled(true);
      expect(await CloudDriveService.isAutoSyncEnabled(), isTrue);

      await CloudDriveService.setLastSyncTime(DateTime(2026, 10, 26, 15, 30));
      final lastSync = await CloudDriveService.getLastSyncTime();
      expect(lastSync, contains('26/10/2026 15:30'));
    });

    test('generateFullBackupJson creates structured bundle with projects and metadata', () {
      final sample = SampleProjects.getSamplePresupuesto();
      final jsonStr = CloudDriveService.generateFullBackupJson([sample], 'usuario@ingenieria.pe');

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['app'], equals('VF COST Pro'));
      expect(decoded['tipo'], equals('BACKUP_COMPLETO_GOOGLE_DRIVE'));
      expect(decoded['usuario_email'], equals('usuario@ingenieria.pe'));
      expect(decoded['total_proyectos'], equals(1));
      expect(decoded['proyectos'], isA<List>());

      final projs = decoded['proyectos'] as List;
      final parsed = Presupuesto.fromJson(projs.first as Map<String, dynamic>);
      expect(parsed.name, equals(sample.name));
      expect(parsed.subpresupuestos.isNotEmpty, isTrue);
    });

    test('getGoogleAppsScriptTemplate returns valid Google Apps Script code for Drive', () {
      final script = CloudDriveService.getGoogleAppsScriptTemplate();
      expect(script, contains('function doPost(e)'));
      expect(script, contains('DriveApp.createFolder'));
      expect(script, contains('VFCOST_Presupuestos_Drive'));
    });
  });
}
