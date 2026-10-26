import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/presupuesto.dart';
import 'delphin_excel_service.dart';
import 'delphin_json_service.dart';
import 'storage_service.dart';

class CloudImportResult {
  final bool success;
  final String message;
  final List<Presupuesto> presupuestos;
  final String? usuarioEmail;
  final DateTime? fechaBackup;
  final String? tipoArchivo;

  const CloudImportResult({
    required this.success,
    required this.message,
    this.presupuestos = const [],
    this.usuarioEmail,
    this.fechaBackup,
    this.tipoArchivo,
  });
}

class CloudDriveService {
  static const String _keyGoogleEmail = 'vfcost_google_email';
  static const String _keyCloudUrl = 'vfcost_cloud_url';
  static const String _keyAutoSync = 'vfcost_auto_sync_drive';
  static const String _keyLastSync = 'vfcost_last_sync_timestamp';

  // --- CONFIGURACIÓN DE CUENTA Y NUBE ---

  static Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGoogleEmail) ?? 'miempresa@gmail.com';
  }

  static Future<void> setUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleEmail, email.trim());
  }

  static Future<String> getCloudUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCloudUrl) ?? '';
  }

  static Future<void> setCloudUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCloudUrl, url.trim());
  }

  static Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSync) ?? false;
  }

  static Future<void> setAutoSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSync, value);
  }

  static Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastSync);
  }

  static Future<void> setLastSyncTime([DateTime? time]) async {
    final prefs = await SharedPreferences.getInstance();
    final t = time ?? DateTime.now();
    final str = '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await prefs.setString(_keyLastSync, str);
  }

  // --- EXPORTAR / GUARDAR EN GOOGLE DRIVE Y RED ---

  /// Genera el contenido JSON para la copia de seguridad de toda la base de proyectos
  static String generateFullBackupJson(List<Presupuesto> presupuestos, String email) {
    final data = {
      'app': 'VF COST Pro',
      'version': '2.0.0',
      'tipo': 'BACKUP_COMPLETO_GOOGLE_DRIVE',
      'fecha_backup': DateTime.now().toIso8601String(),
      'usuario_email': email,
      'total_proyectos': presupuestos.length,
      'proyectos': presupuestos.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 1. GUARDADO CON SELECTOR OFICIAL SAF (Permite elegir directamente Google Drive o Descargas)
  static Future<Uri?> saveBackupWithPicker({
    required List<Presupuesto> presupuestos,
    required String userEmail,
  }) async {
    final jsonStr = generateFullBackupJson(presupuestos, userEmail);
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'VFCOST_Backup_$dateStr.json';

    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final uri = await FilePicker.saveFile(
      dialogTitle: 'Selecciona Google Drive o la carpeta donde deseas guardar',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );

    if (uri != null) {
      await setLastSyncTime(now);
    }
    return uri;
  }

  /// 2. GUARDADO DIRECTO EN LA CARPETA DESCARGAS (DOWNLOADS) DE ANDROID
  static Future<File?> saveBackupToDownloads({
    required List<Presupuesto> presupuestos,
    required String userEmail,
  }) async {
    final jsonStr = generateFullBackupJson(presupuestos, userEmail);
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'VFCOST_Backup_$dateStr.json';

    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = downloadDir;
        }
      }
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final file = File('${targetDir.path}/$fileName');
      await file.writeAsString(jsonStr, flush: true);
      await setLastSyncTime(now);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// 3. GUARDADO MEDIANTE INTENT DE COMPARTIR A LA APP DE GOOGLE DRIVE (Share sheet)
  static Future<File> exportAllToGoogleDrive({
    required List<Presupuesto> presupuestos,
    required String userEmail,
  }) async {
    final jsonStr = generateFullBackupJson(presupuestos, userEmail);
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    // Usar extensión .json para que la app Google Drive de Android lo reconozca de inmediato
    final file = File('${tempDir.path}/VFCOST_Backup_GoogleDrive_$dateStr.json');
    await file.writeAsString(jsonStr, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'VF COST Pro - Respaldo Completo Google Drive ($userEmail)',
      text: 'Copia de seguridad en la nube de ${presupuestos.length} proyectos de presupuestos y costos unitarios de VF COST Pro.',
    );

    await setLastSyncTime(now);
    return file;
  }

  /// Guarda un solo presupuesto en Google Drive con el selector SAF
  static Future<Uri?> saveSingleProjectWithPicker({
    required Presupuesto presupuesto,
    required String userEmail,
  }) async {
    final cleanCode = presupuesto.code.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final fileName = 'VFCOST_${cleanCode}_GoogleDrive.json';

    final data = {
      'app': 'VF COST Pro',
      'version': '2.0.0',
      'tipo': 'PROYECTO_INDIVIDUAL_GOOGLE_DRIVE',
      'fecha_backup': DateTime.now().toIso8601String(),
      'usuario_email': userEmail,
      'proyecto': presupuesto.toJson(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar proyecto en Google Drive o Dispositivo',
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );

    if (uri != null) {
      await setLastSyncTime(DateTime.now());
    }
    return uri;
  }

  /// Guarda un solo presupuesto en Google Drive mediante compartir
  static Future<File> exportSingleProjectToGoogleDrive({
    required Presupuesto presupuesto,
    required String userEmail,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final cleanCode = presupuesto.code.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final file = File('${tempDir.path}/VFCOST_${cleanCode}_GoogleDrive.json');

    final data = {
      'app': 'VF COST Pro',
      'version': '2.0.0',
      'tipo': 'PROYECTO_INDIVIDUAL_GOOGLE_DRIVE',
      'fecha_backup': DateTime.now().toIso8601String(),
      'usuario_email': userEmail,
      'proyecto': presupuesto.toJson(),
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Presupuesto ${presupuesto.name} - Guardar en Google Drive',
      text: 'Proyecto: ${presupuesto.name} | Código: ${presupuesto.code} | Guardado desde VF COST Pro ($userEmail)',
    );

    await setLastSyncTime(DateTime.now());
    return file;
  }

  /// Guarda un reporte PDF directamente en Google Drive
  static Future<File> exportPdfToGoogleDrive({
    required Uint8List pdfBytes,
    required String filename,
    required String userEmail,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(pdfBytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Reporte PDF Oficial - Guardar en Google Drive',
      text: 'Documento técnico emitido por VF COST Pro para $userEmail.',
    );

    return file;
  }

  /// Guarda una planilla Excel directamente en Google Drive
  static Future<File> exportExcelToGoogleDrive({
    required List<int> excelBytes,
    required String filename,
    required String userEmail,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(excelBytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Planilla Excel S10 / Delphin - Guardar en Google Drive',
      text: 'Planilla de costos y presupuestos generada por VF COST Pro para $userEmail.',
    );

    return file;
  }

  // --- IMPORTAR / RESTAURAR DESDE GOOGLE DRIVE ---

  /// Permite seleccionar cualquier archivo desde Google Drive (o almacenamiento local) y procesarlo
  static Future<CloudImportResult> importFromGoogleDrive() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files == null || files.isEmpty) {
        return const CloudImportResult(
          success: false,
          message: 'Operación cancelada por el usuario.',
        );
      }

      final pickedFile = files.first;
      final bytes = await pickedFile.xFile.readAsBytes();

      if (bytes == null || bytes.isEmpty) {
        return const CloudImportResult(
          success: false,
          message: 'El archivo seleccionado está vacío o no se pudo leer.',
        );
      }

      final fileName = pickedFile.name.toLowerCase();

      // Caso 1: Archivo Excel (.xlsx / .xls)
      if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
        final cleanName = pickedFile.name.replaceAll(RegExp(r'\.xlsx$|\.xls$', caseSensitive: false), '');
        final presupuesto = DelphinExcelService.importDelphinXlsx(bytes, defaultName: cleanName);
        if (presupuesto == null) {
          return const CloudImportResult(
            success: false,
            message: 'El archivo Excel de Google Drive no contiene una estructura válida de partidas.',
          );
        }
        return CloudImportResult(
          success: true,
          message: 'Presupuesto Excel importado correctamente desde Google Drive.',
          presupuestos: [presupuesto],
          tipoArchivo: 'Excel (.xlsx)',
        );
      }

      // Caso 2: Archivo JSON / .vfcost
      final jsonString = utf8.decode(bytes);
      final decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        return const CloudImportResult(
          success: false,
          message: 'El archivo seleccionado no tiene un formato JSON válido.',
        );
      }

      final jsonMap = decoded;

      // 2.A: Copia de Seguridad Completa (Múltiples Proyectos)
      if (jsonMap.containsKey('proyectos') && jsonMap['proyectos'] is List) {
        final rawList = jsonMap['proyectos'] as List<dynamic>;
        final lista = <Presupuesto>[];
        for (final pItem in rawList) {
          if (pItem is Map<String, dynamic>) {
            try {
              lista.add(Presupuesto.fromJson(pItem));
            } catch (_) {}
          }
        }

        if (lista.isEmpty) {
          return const CloudImportResult(
            success: false,
            message: 'El archivo de respaldo no contiene proyectos válidos.',
          );
        }

        DateTime? fecha;
        if (jsonMap['fecha_backup'] != null) {
          try {
            fecha = DateTime.parse(jsonMap['fecha_backup'].toString());
          } catch (_) {}
        }

        return CloudImportResult(
          success: true,
          message: 'Respaldo completo de ${lista.length} proyectos extraído con éxito.',
          presupuestos: lista,
          usuarioEmail: jsonMap['usuario_email']?.toString(),
          fechaBackup: fecha,
          tipoArchivo: 'Backup Completo (.json / .vfcost)',
        );
      }

      // 2.B: Proyecto Individual Guardado en Drive
      if (jsonMap.containsKey('proyecto') && jsonMap['proyecto'] is Map) {
        final pData = jsonMap['proyecto'] as Map<String, dynamic>;
        Presupuesto? single;
        try {
          single = Presupuesto.fromJson(pData);
        } catch (_) {
          single = DelphinJsonService.importDelphinJson(jsonMap);
        }

        if (single != null) {
          return CloudImportResult(
            success: true,
            message: 'Proyecto "${single.name}" cargado desde Google Drive.',
            presupuestos: [single],
            usuarioEmail: jsonMap['usuario_email']?.toString(),
            tipoArchivo: 'Proyecto Individual (.json)',
          );
        }
      }

      // 2.C: Presupuesto Estándar VF COST / S10 JSON
      final singleP = StorageService.importPresupuestoFromJson(jsonString);
      if (singleP != null) {
        return CloudImportResult(
          success: true,
          message: 'Proyecto "${singleP.name}" cargado desde Google Drive.',
          presupuestos: [singleP],
          tipoArchivo: 'JSON Estándar',
        );
      }

      // 2.D: Formato Delphin Express JSON
      final delphinP = DelphinJsonService.importDelphinJson(jsonMap);
      if (delphinP != null) {
        return CloudImportResult(
          success: true,
          message: 'Presupuesto Delphin Express "${delphinP.name}" importado con éxito.',
          presupuestos: [delphinP],
          tipoArchivo: 'Delphin JSON',
        );
      }

      return const CloudImportResult(
        success: false,
        message: 'No se reconoció el formato del archivo de Google Drive.',
      );
    } catch (e) {
      return CloudImportResult(
        success: false,
        message: 'Error al leer archivo de Google Drive: ${e.toString()}',
      );
    }
  }

  // --- SINCRONIZACIÓN AUTOMÁTICA WEB (GOOGLE APPS SCRIPT / SERVIDOR EN RED) ---

  /// Envía la copia de seguridad por HTTP POST a un Webhook / Google Apps Script en la red
  static Future<Map<String, dynamic>> syncToCloudUrl({
    required String url,
    required List<Presupuesto> presupuestos,
    required String userEmail,
  }) async {
    try {
      final jsonPayload = generateFullBackupJson(presupuestos, userEmail);
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonPayload,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await setLastSyncTime(DateTime.now());
        try {
          final resData = jsonDecode(response.body) as Map<String, dynamic>;
          return {'success': true, 'message': 'Sincronización exitosa con la red.', 'data': resData};
        } catch (_) {
          return {'success': true, 'message': 'Copia enviada a la red con código HTTP ${response.statusCode}.'};
        }
      } else {
        return {
          'success': false,
          'message': 'Error del servidor en la red (Código HTTP ${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión a la red: ${e.toString()}'};
    }
  }

  /// Código Google Apps Script gratuito para que el usuario despliegue en Google Drive
  static String getGoogleAppsScriptTemplate() {
    return '''// Código Google Apps Script para Respaldos VF COST Pro en Google Drive
// 1. Ve a https://script.google.com/
// 2. Crea un Nuevo Proyecto y pega este código.
// 3. Haz clic en "Implementar" -> "Nueva Implementación" -> "Aplicación web".
//    - Ejecutar como: "Yo (tu cuenta de correo)".
//    - Quién tiene acceso: "Cualquier persona".
// 4. Copia la URL generada y pégala en VF COST Pro.

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var folderName = "VFCOST_Presupuestos_Drive";
    var folders = DriveApp.getFoldersByName(folderName);
    var folder = folders.hasNext() ? folders.next() : DriveApp.createFolder(folderName);
    
    var email = data.usuario_email || "usuario";
    var timestamp = Utilities.formatDate(new Date(), "GMT-5", "yyyyMMdd_HHmmss");
    var fileName = "VFCOST_Backup_" + email + "_" + timestamp + ".json";
    
    var file = folder.createFile(fileName, e.postData.contents, MimeType.PLAIN_TEXT);
    
    return ContentService.createTextOutput(JSON.stringify({
      success: true,
      message: "Respaldo guardado exitosamente en Google Drive",
      fileName: fileName,
      fileUrl: file.getUrl()
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
''';
  }
}
