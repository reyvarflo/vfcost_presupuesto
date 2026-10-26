import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/metrado_line.dart';
import '../models/partida.dart';
import '../providers/presupuesto_provider.dart';

class MetradosEditorScreen extends StatefulWidget {
  final Partida partida;

  const MetradosEditorScreen({
    super.key,
    required this.partida,
  });

  @override
  State<MetradosEditorScreen> createState() => _MetradosEditorScreenState();
}

class _MetradosEditorScreenState extends State<MetradosEditorScreen> {
  final _uuid = const Uuid();
  final _numFormat = NumberFormat('#,##0.00', 'es_PE');
  final _dimFormat = NumberFormat('#,##0.000', 'es_PE');

  late List<MetradoLine> _lines;

  @override
  void initState() {
    super.initState();
    _lines = List<MetradoLine>.from(widget.partida.metradoLines);
  }

  double get _totalMetrado => _lines.fold(0.0, (s, l) => s + l.parcial);

  void _openLineDialog({MetradoLine? existingLine, int? index}) {
    final descCtrl = TextEditingController(text: existingLine?.descripcion ?? '');
    final vecesCtrl = TextEditingController(text: (existingLine?.veces ?? 1.0).toString());
    final largoCtrl = TextEditingController(text: (existingLine?.largo ?? 1.0).toString());
    final anchoCtrl = TextEditingController(text: (existingLine?.ancho ?? 1.0).toString());
    final altoCtrl = TextEditingController(text: (existingLine?.alto ?? 1.0).toString());

    double calcParcial() {
      final v = double.tryParse(vecesCtrl.text) ?? 1.0;
      final l = double.tryParse(largoCtrl.text) ?? 1.0;
      final a = double.tryParse(anchoCtrl.text) ?? 1.0;
      final h = double.tryParse(altoCtrl.text) ?? 1.0;
      return v * l * a * h;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final parcialActual = calcParcial();
            return AlertDialog(
              title: Text(
                existingLine == null ? 'Nueva Línea de Metrado' : 'Editar Línea de Metrado',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Ubicación / Eje',
                        hintText: 'ej. Eje A entre 1 y 4 (Zapata Z-1)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: vecesCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'N° Veces',
                              hintText: '1.0',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: largoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Largo (m)',
                              hintText: '1.0',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: anchoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Ancho (m)',
                              hintText: '1.0',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: altoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Alto/Esp. (m)',
                              hintText: '1.0',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Parcial Calculado:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_numFormat.format(parcialActual)} ${widget.partida.unit}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final desc = descCtrl.text.trim();
                    final veces = double.tryParse(vecesCtrl.text) ?? 1.0;
                    final largo = double.tryParse(largoCtrl.text) ?? 1.0;
                    final ancho = double.tryParse(anchoCtrl.text) ?? 1.0;
                    final alto = double.tryParse(altoCtrl.text) ?? 1.0;

                    final line = MetradoLine(
                      id: existingLine?.id ?? _uuid.v4(),
                      descripcion: desc.isEmpty ? 'Elemento' : desc,
                      veces: veces,
                      largo: largo,
                      ancho: ancho,
                      alto: alto,
                    );

                    setState(() {
                      if (index != null && index >= 0) {
                        _lines[index] = line;
                      } else {
                        _lines.add(line);
                      }
                    });

                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveAndTransfer() {
    context.read<PresupuestoProvider>().updatePartidaMetrados(
          widget.partida.id,
          _lines,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Metrado transferido: ${_numFormat.format(_totalMetrado)} ${widget.partida.unit}',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partida = widget.partida;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${partida.itemNumber} ${partida.description}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Hoja de Metrados  •  Unidad: ${partida.unit}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Guardar y Transferir Metrado',
            onPressed: _saveAndTransfer,
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen de Metrado Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL METRADO:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _numFormat.format(_totalMetrado),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          partida.unit,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_lines.length} Líneas de desglose',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar Fila', style: TextStyle(fontSize: 11.5)),
                      onPressed: () => _openLineDialog(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de líneas de metrados
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.straighten, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay líneas de metrado ingresadas',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Desglose dimensiones (Veces × Largo × Ancho × Alto)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Primera Fila'),
                          onPressed: () => _openLineDialog(),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 80, left: 10, right: 10),
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      line.descripcion,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Editar',
                                    onPressed: () => _openLineDialog(
                                      existingLine: line,
                                      index: index,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Eliminar',
                                    onPressed: () {
                                      setState(() {
                                        _lines.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _dimColumn('Elementos', _dimFormat.format(line.veces)),
                                  _dimColumn('Cant.xEl.', _dimFormat.format(line.cantidadPorElemento)),
                                  _dimColumn('Largo (m)', line.largo != null ? _dimFormat.format(line.largo) : '-'),
                                  _dimColumn('Ancho (m)', line.ancho != null ? _dimFormat.format(line.ancho) : '-'),
                                  _dimColumn('Alto (m)', line.alto != null ? _dimFormat.format(line.alto) : '-'),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Parcial',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${_numFormat.format(line.parcial)} ${partida.unit}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.save),
          label: Text(
            'Guardar Metrado (${_numFormat.format(_totalMetrado)} ${partida.unit})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _saveAndTransfer,
        ),
      ),
    );
  }

  Widget _dimColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
