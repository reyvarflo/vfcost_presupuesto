import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/presupuesto.dart';
import '../providers/presupuesto_provider.dart';
import '../services/cloud_drive_service.dart';
import '../theme/varflo_theme.dart';

class CloudDriveScreen extends StatefulWidget {
  final Presupuesto? activePresupuesto;

  const CloudDriveScreen({super.key, this.activePresupuesto});

  @override
  State<CloudDriveScreen> createState() => _CloudDriveScreenState();
}

class _CloudDriveScreenState extends State<CloudDriveScreen> {
  final _emailController = TextEditingController();
  final _cloudUrlController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  String? _lastSync;
  bool _autoSync = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cloudUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final email = await CloudDriveService.getUserEmail();
    final url = await CloudDriveService.getCloudUrl();
    final auto = await CloudDriveService.isAutoSyncEnabled();
    final last = await CloudDriveService.getLastSyncTime();

    setState(() {
      _emailController.text = email;
      _cloudUrlController.text = url;
      _autoSync = auto;
      _lastSync = last;
    });
  }

  Future<void> _saveEmail() async {
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      await CloudDriveService.setUserEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Correo "$email" guardado como cuenta principal de Google Drive.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _saveCloudUrl() async {
    final url = _cloudUrlController.text.trim();
    await CloudDriveService.setCloudUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ URL de sincronización en la red guardada.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Despliega el menú con las 3 formas 100% garantizadas de guardar en Google Drive
  void _openSaveOptionsModal() {
    final provider = context.read<PresupuestoProvider>();
    final presupuestos = provider.presupuestos;
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : 'miempresa@gmail.com';

    if (presupuestos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay presupuestos para respaldar en Google Drive.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra indicadora superior
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_to_drive, color: Color(0xFF4285F4), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guardar en Google Drive',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                        ),
                        Text(
                          'Cuenta: $email (${presupuestos.length} proyectos)',
                          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Selecciona cómo deseas guardar la copia de seguridad:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),

              // Opción 1: Selector Oficial de Google Drive / SAF
              _buildOptionTile(
                icon: Icons.drive_folder_upload,
                iconColor: const Color(0xFF4285F4),
                title: '1. Elegir carpeta en Google Drive (Recomendado)',
                subtitle: 'Abre el explorador de Android. Selecciona "Google Drive" en el menú lateral y guarda en "Mi unidad".',
                badge: 'DIRECTO',
                badgeColor: Colors.blue,
                onTap: () {
                  Navigator.pop(ctx);
                  _saveWithPicker(presupuestos, email);
                },
              ),
              const SizedBox(height: 8),

              // Opción 2: Guardar en la carpeta "Descargas" del teléfono
              _buildOptionTile(
                icon: Icons.download_for_offline_rounded,
                iconColor: const Color(0xFF34A853),
                title: '2. Guardar en carpeta "Descargas" del teléfono',
                subtitle: 'Guarda el archivo .json en /Download para que puedas subirlo o compartirlo en cualquier momento.',
                badge: 'SEGURO',
                badgeColor: Colors.green,
                onTap: () {
                  Navigator.pop(ctx);
                  _saveToDownloads(presupuestos, email);
                },
              ),
              const SizedBox(height: 8),

              // Opción 3: Subir mediante la App Google Drive instalada / Compartir
              _buildOptionTile(
                icon: Icons.share_rounded,
                iconColor: const Color(0xFFFF6D00),
                title: '3. Enviar a la app Google Drive / Compartir',
                subtitle: 'Abre el menú de compartir de Android para enviarlo a la aplicación Google Drive, Gmail o WhatsApp.',
                badge: 'APP DRIVE',
                badgeColor: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _exportViaShareSheet(presupuestos, email);
                },
              ),

              // Opción 4: Sincronización Web si está configurada
              if (_cloudUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.cloud_sync,
                  iconColor: Colors.teal,
                  title: '4. Sincronizar a Servidor Web / Google Apps Script',
                  subtitle: 'Sube automáticamente los datos a la URL configurada en la red.',
                  badge: 'WEBHOOK',
                  badgeColor: Colors.teal,
                  onTap: () {
                    Navigator.pop(ctx);
                    _syncViaWebhook();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS DE GUARDADO ---

  /// 1. Guardar usando el selector oficial SAF de Android (Permite navegar a Google Drive)
  Future<void> _saveWithPicker(List<Presupuesto> presupuestos, String email) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Abriendo selector de Google Drive...';
      });

      await CloudDriveService.setUserEmail(email);
      final uri = await CloudDriveService.saveBackupWithPicker(
        presupuestos: presupuestos,
        userEmail: email,
      );

      final last = await CloudDriveService.getLastSyncTime();
      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _lastSync = last;
      });

      if (!mounted) return;

      if (uri != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ¡Copia de seguridad de ${presupuestos.length} proyectos guardada con éxito en Google Drive!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación cancelada. Puedes elegir la opción 2 (Guardar en Descargas).'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 2. Guardar en la carpeta pública "Descargas" (Download) del dispositivo
  Future<void> _saveToDownloads(List<Presupuesto> presupuestos, String email) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Guardando en la carpeta Descargas de tu celular...';
      });

      await CloudDriveService.setUserEmail(email);
      final file = await CloudDriveService.saveBackupToDownloads(
        presupuestos: presupuestos,
        userEmail: email,
      );

      final last = await CloudDriveService.getLastSyncTime();
      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _lastSync = last;
      });

      if (!mounted) return;

      if (file != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('¡Respaldo Guardado!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Se guardó el archivo de respaldo con todos tus proyectos en:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    file.path,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Cuenta vinculada: $email\nProyectos respaldados: ${presupuestos.length}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
              FilledButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Subir a Google Drive'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportViaShareSheet(presupuestos, email);
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo acceder a la carpeta Descargas.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 3. Guardar enviando a la app de Google Drive instalada / Compartir
  Future<void> _exportViaShareSheet(List<Presupuesto> presupuestos, String email) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Preparando archivo para la app de Google Drive...';
      });

      await CloudDriveService.setUserEmail(email);
      await CloudDriveService.exportAllToGoogleDrive(
        presupuestos: presupuestos,
        userEmail: email,
      );

      final last = await CloudDriveService.getLastSyncTime();
      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _lastSync = last;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selecciona "Guardar en Drive" para subirlo a tu cuenta $email.'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Exportar proyecto individual (si hay un proyecto activo abierto)
  Future<void> _exportActiveProjectToDrive() async {
    if (widget.activePresupuesto == null) return;
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : 'miempresa@gmail.com';

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Guardando proyecto "${widget.activePresupuesto!.name}" en Google Drive...';
      });

      final uri = await CloudDriveService.saveSingleProjectWithPicker(
        presupuesto: widget.activePresupuesto!,
        userEmail: email,
      );

      final last = await CloudDriveService.getLastSyncTime();
      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _lastSync = last;
      });

      if (mounted) {
        if (uri != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Proyecto "${widget.activePresupuesto!.name}" guardado exitosamente en Google Drive.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Si el usuario canceló el selector, ofrecer compartir a la app de Drive
          await CloudDriveService.exportSingleProjectToGoogleDrive(
            presupuesto: widget.activePresupuesto!,
            userEmail: email,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importFromDrive() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Abriendo Google Drive para seleccionar archivo...';
      });

      final result = await CloudDriveService.importFromGoogleDrive();

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: Colors.orange),
        );
        return;
      }

      final count = result.presupuestos.length;
      final provider = context.read<PresupuestoProvider>();

      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cloud_download, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Restaurar desde Google Drive ($count proyectos)'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Archivo: ${result.tipoArchivo ?? "Copia de Seguridad"}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (result.usuarioEmail != null)
                Text('Vinculado a: ${result.usuarioEmail}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (result.fechaBackup != null)
                Text('Fecha de respaldo: ${result.fechaBackup}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 14),
              const Text('¿Cómo deseas restaurar los proyectos?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'add'),
              child: const Text('Añadir / Mantener Ambos'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2B48)),
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Sobrescribir Existentes'),
            ),
          ],
        ),
      );

      if (action == null || action == 'cancel') return;

      final overwrite = (action == 'overwrite');
      final restoredCount = await provider.restaurarMultiplesPresupuestos(
        result.presupuestos,
        sobrescribir: overwrite,
      );

      final now = DateTime.now();
      await CloudDriveService.setLastSyncTime(now);
      setState(() {
        _lastSync = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ¡Se restauraron $restoredCount proyectos con éxito desde Google Drive!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncViaWebhook() async {
    final url = _cloudUrlController.text.trim();
    if (url.isEmpty) {
      _showAppsScriptInstructions();
      return;
    }

    final provider = context.read<PresupuestoProvider>();
    final presupuestos = provider.presupuestos;
    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _statusMessage = 'Enviando copia a la nube (${presupuestos.length} proyectos)...';
    });

    final res = await CloudDriveService.syncToCloudUrl(
      url: url,
      presupuestos: presupuestos,
      userEmail: email,
    );

    setState(() {
      _isLoading = false;
      _statusMessage = '';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String),
          backgroundColor: (res['success'] == true) ? Colors.green : Colors.red,
        ),
      );
      if (res['success'] == true) {
        final last = await CloudDriveService.getLastSyncTime();
        setState(() => _lastSync = last);
      }
    }
  }

  void _showAppsScriptInstructions() {
    final code = CloudDriveService.getGoogleAppsScriptTemplate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.integration_instructions, color: Colors.blue),
            SizedBox(width: 8),
            Text('Sincronizador Google Drive Gratis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para sincronizar automáticamente con Google Drive en segundo plano cada vez que guardes, sigue estos 3 pasos:\n\n'
                  '1. Entra a https://script.google.com con tu cuenta de correo.\n'
                  '2. Crea un "Nuevo Proyecto" y pega el código inferior.\n'
                  '3. Haz clic en "Implementar" -> "Nueva implementación" -> "Aplicación web", selecciona acceso para "Cualquier persona" y pega la URL aquí.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar Código'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado al portapapeles.'), backgroundColor: Colors.teal),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final totalProyectos = provider.presupuestos.length;

    return Scaffold(
      backgroundColor: VarfloTheme.grisFondo,
      appBar: AppBar(
        backgroundColor: VarfloTheme.azulPrincipal,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.cloud_sync, color: VarfloTheme.naranjaPrincipal, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Drive & Respaldo en la Red',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'VF COST Pro Cloud Sync — Guardar, Exportar y Restaurar',
                    style: TextStyle(fontSize: 10.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: VarfloTheme.naranjaPrincipal),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: VarfloTheme.azulPrincipal),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TARJETA DE ESTADO DE CUENTA GOOGLE DRIVE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: VarfloTheme.sombraTarjeta,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add_to_drive, color: Color(0xFF4285F4), size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cuenta de Google / Correo Conectado',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: VarfloTheme.azulPrincipal),
                                  ),
                                  Text(
                                    _lastSync != null
                                        ? 'Última sincronización: $_lastSync'
                                        : 'Sin sincronización registrada aún',
                                    style: const TextStyle(fontSize: 11, color: VarfloTheme.grisTextoSecundario),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Listo',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Correo Electrónico (Google Drive / Gmail)',
                            hintText: 'ejemplo@gmail.com o empresa@constructora.pe',
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4285F4)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.save_outlined),
                              tooltip: 'Guardar Correo',
                              onPressed: _saveEmail,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onSubmitted: (_) => _saveEmail(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. BOTONES DE ACCIÓN PRINCIPAL: GUARDAR Y RESTAURAR
                  Row(
                    children: [
                      // Botón Guardar en Drive
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VarfloTheme.azulPrincipal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                          ),
                          onPressed: _openSaveOptionsModal,
                          icon: const Icon(Icons.cloud_upload_rounded, color: VarfloTheme.naranjaPrincipal, size: 22),
                          label: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Guardar en Drive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('Subir todos los presupuestos', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón Restaurar desde Drive
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                          ),
                          onPressed: _importFromDrive,
                          icon: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 22),
                          label: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Restaurar de Drive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('Cargar backup o Excel', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. SI HAY UN PRESUPUESTO ACTIVO ABIERTO: OPCIÓN DE GUARDAR ESTE SOLO
                  if (widget.activePresupuesto != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_special_outlined, color: VarfloTheme.naranjaPrincipal, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Presupuesto Abierto: ${widget.activePresupuesto!.name}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Código: ${widget.activePresupuesto!.code} | Costo Directo: S/ ${widget.activePresupuesto!.totalCostoDirecto.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: _exportActiveProjectToDrive,
                            style: FilledButton.styleFrom(
                              backgroundColor: VarfloTheme.naranjaClaro,
                              foregroundColor: VarfloTheme.naranjaOscuro,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Subir Éste a Drive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. RESUMEN DE PROYECTOS LOCALES
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VarfloTheme.grisBordeSuave),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: VarfloTheme.azulPrincipal, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Base de Datos Local ($totalProyectos Proyectos)',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: VarfloTheme.azulPrincipal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Al pulsar "Guardar en Drive", puedes elegir directamente tu carpeta de Google Drive (Mi unidad) o la carpeta Descargas de tu dispositivo. El archivo generado contiene todos tus presupuestos, partidas, APUs y fórmulas polinómicas.',
                          style: TextStyle(fontSize: 11.5, color: VarfloTheme.grisTextoOscuro, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. SINCRONIZACIÓN AUTOMÁTICA CON LA RED (GOOGLE APPS SCRIPT / WEBHOOK)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VarfloTheme.grisBordeSuave),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.network_wifi_rounded, color: Colors.teal, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Sincronización Web en la Red / Servidor Cloud',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Switch(
                              value: _autoSync,
                              activeColor: Colors.teal,
                              onChanged: (val) async {
                                setState(() => _autoSync = val);
                                await CloudDriveService.setAutoSyncEnabled(val);
                                if (val && _cloudUrlController.text.trim().isEmpty) {
                                  _showAppsScriptInstructions();
                                }
                              },
                            ),
                          ],
                        ),
                        const Text(
                          'Configura un Webhook o Google Apps Script para sincronizar automáticamente en segundo plano cada vez que guardes.',
                          style: TextStyle(fontSize: 11, color: VarfloTheme.grisTextoSecundario),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _cloudUrlController,
                          decoration: InputDecoration(
                            labelText: 'URL de Sincronización Web (Google Apps Script / Servidor)',
                            hintText: 'https://script.google.com/macros/s/.../exec',
                            prefixIcon: const Icon(Icons.link, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.save_outlined),
                              onPressed: _saveCloudUrl,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onSubmitted: (_) => _saveCloudUrl(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                icon: const Icon(Icons.help_outline, size: 16),
                                label: const Text('Instrucciones Gratis (Script)', style: TextStyle(fontSize: 11)),
                                onPressed: _showAppsScriptInstructions,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.sync, size: 16),
                                label: const Text('Sincronizar a la Red', style: TextStyle(fontSize: 11)),
                                onPressed: _syncViaWebhook,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
