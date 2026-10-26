import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/presupuesto.dart';
import '../providers/presupuesto_provider.dart';
import '../services/s2k_service.dart';
import 'presupuesto_detail_screen.dart';

class S2kImportDialog extends StatefulWidget {
  const S2kImportDialog({super.key});

  @override
  State<S2kImportDialog> createState() => _S2kImportDialogState();
}

class _S2kImportDialogState extends State<S2kImportDialog> {
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  double _fileSizeMb = 0.0;

  String _serverUrl = S2kService.defaultServerUrl;
  bool _serverOnline = false;
  String _serverMessage = 'Comprobando conexión...';
  bool _isCheckingServer = false;

  bool _isConverting = false;
  String _currentStep = '';

  @override
  void initState() {
    super.initState();
    _loadServerUrlAndCheck();
  }

  Future<void> _loadServerUrlAndCheck() async {
    setState(() => _isCheckingServer = true);
    final url = await S2kService.getServerUrl();
    _serverUrl = url;
    final health = await S2kService.checkServerHealth(url);
    if (mounted) {
      setState(() {
        _serverOnline = health['online'] == true;
        _serverMessage = health['message'] as String? ?? '';
        _isCheckingServer = false;
      });
    }
  }

  void _openEditServerUrlDialog() {
    final controller = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar Servidor Cloud S10', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingrese la URL base del microservicio backend (Docker / Nube) con SQL Server:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL del Backend',
                hintText: 'http://10.0.2.2:8000 o https://s10.tuempresa.com',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• En Emulador Android: http://10.0.2.2:8000\n• En Teléfono Wi-Fi: http://192.168.X.X:8000\n• En Servidor Cloud: https://tudominio.com',
              style: TextStyle(fontSize: 10.5, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await S2kService.setServerUrl(newUrl);
                Navigator.pop(ctx);
                _loadServerUrlAndCheck();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickS2kFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isNotEmpty) {
        final file = files.first;
        final name = file.name;
        final bytes = await file.readAsBytes();

        setState(() {
          _selectedFileName = name;
          _selectedFileBytes = bytes;
          _fileSizeMb = bytes.length / (1024 * 1024);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando archivo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startConversion() async {
    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione un archivo .S2K primero'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isConverting = true;
      _currentStep = 'Iniciando conexión con el servidor...';
    });

    try {
      final Presupuesto presupuesto = await S2kService.uploadAndConvert(
        fileBytes: _selectedFileBytes!,
        fileName: _selectedFileName!,
        onStatusUpdate: (step) {
          if (mounted) setState(() => _currentStep = step);
        },
      );

      if (!mounted) return;

      // Registrar e importar el presupuesto en el provider local
      final provider = context.read<PresupuestoProvider>();
      provider.presupuestos.add(presupuesto);
      provider.selectPresupuesto(presupuesto.id);
      await provider.procesarPresupuesto();

      if (mounted) {
        Navigator.pop(context); // cerrar diálogo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Presupuesto "${presupuesto.name}" importado con éxito desde S10!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PresupuestoDetailScreen(presupuesto: presupuesto),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al Convertir Archivo S10', style: TextStyle(color: Colors.red)),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Importar Backup S10 (.S2K)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Arquitectura Cloud SAAS (Opción B)',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isConverting ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            // Explicación técnica resumida
            Text(
              'Los archivos .S2K son copias binarias nativas de SQL Server (BAK). Esta función sube el archivo a tu microservicio Docker en la nube, restaura la base de datos temporalmente, extrae todas las partidas y APUs, y te entrega el proyecto listo para trabajar offline en tu celular.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.3),
            ),
            const SizedBox(height: 14),

            // Sección: Selector de Archivo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Archivo de Respaldo (.S2K / .BAK):',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedFileName != null && !_isConverting)
                        TextButton(
                          onPressed: _pickS2kFile,
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('Cambiar', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_selectedFileName == null)
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Examinar Archivo en el Móvil'),
                        onPressed: _isConverting ? null : _pickS2kFile,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.blue, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFileName!,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_fileSizeMb.toStringAsFixed(2)} MB',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Estado del Servidor Backend
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _serverOnline ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _serverOnline ? Colors.green.shade200 : Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _serverOnline ? Icons.dns : Icons.warning_amber_rounded,
                    size: 16,
                    color: _serverOnline ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servidor: $_serverUrl',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isCheckingServer ? 'Verificando...' : _serverMessage,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: _serverOnline ? Colors.green.shade900 : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Cambiar URL del Servidor',
                    onPressed: _isConverting ? null : _openEditServerUrlDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progreso durante la conversión
            if (_isConverting) ...[
              LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentStep,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isConverting ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('Subir y Convertir'),
                  onPressed: _isConverting || _selectedFileBytes == null
                      ? null
                      : _startConversion,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
