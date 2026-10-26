import 'package:flutter/material.dart';
import '../models/partida.dart';

class PartidaFormDialog extends StatefulWidget {
  final Partida? existingPartida;
  final String suggestedItemNumber;
  final Function(Partida) onSave;

  const PartidaFormDialog({
    super.key,
    this.existingPartida,
    this.suggestedItemNumber = '01',
    required this.onSave,
  });

  @override
  State<PartidaFormDialog> createState() => _PartidaFormDialogState();
}

class _PartidaFormDialogState extends State<PartidaFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late bool _isTitle;
  late int _level;
  late TextEditingController _itemController;
  late TextEditingController _descController;
  late TextEditingController _unitController;
  late TextEditingController _metradoController;
  late TextEditingController _rendimientoController;

  static const List<String> _commonUnits = [
    'm3',
    'm2',
    'ml',
    'kg',
    'und',
    'pza',
    'p2',
    'bol',
    'gal',
    'glb',
    'est',
    'km',
    'ton',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPartida;
    _isTitle = p?.isTitle ?? false;
    _level = p?.level ?? 1;
    _itemController = TextEditingController(text: p?.itemNumber ?? widget.suggestedItemNumber);
    _descController = TextEditingController(text: p?.description ?? '');
    _unitController = TextEditingController(text: p?.unit ?? 'm3');
    _metradoController = TextEditingController(text: p != null ? p.metrado.toString() : '1.0');
    _rendimientoController = TextEditingController(text: p != null ? p.rendimiento.toString() : '20.0');
  }

  @override
  void dispose() {
    _itemController.dispose();
    _descController.dispose();
    _unitController.dispose();
    _metradoController.dispose();
    _rendimientoController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final metrado = double.tryParse(_metradoController.text) ?? 0.0;
      final rendimiento = double.tryParse(_rendimientoController.text) ?? 1.0;

      final updated = (widget.existingPartida ??
              Partida(
                id: '',
                itemNumber: '',
                description: '',
              ))
          .copyWith(
        itemNumber: _itemController.text.trim(),
        description: _descController.text.trim().toUpperCase(),
        isTitle: _isTitle,
        level: _level,
        unit: _isTitle ? '' : _unitController.text.trim().toLowerCase(),
        metrado: _isTitle ? 0.0 : metrado,
        rendimiento: _isTitle ? 1.0 : (rendimiento > 0 ? rendimiento : 1.0),
      );

      widget.onSave(updated);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isTitle ? Icons.folder_open_outlined : Icons.construction_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(widget.existingPartida != null ? 'Editar Registro' : 'Nueva Partida / Título'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector Título vs Partida
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Título'),
                    icon: Icon(Icons.title),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Partida (APU)'),
                    icon: Icon(Icons.calculate_outlined),
                  ),
                ],
                selected: {_isTitle},
                onSelectionChanged: (val) {
                  setState(() {
                    _isTitle = val.first;
                  });
                },
              ),
              const SizedBox(height: 14),

              // Nivel jerárquico
              Row(
                children: [
                  const Text('Nivel jerárquico: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _level,
                    items: [1, 2, 3, 4, 5].map((lvl) {
                      return DropdownMenuItem(
                        value: lvl,
                        child: Text('Nivel $lvl'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _level = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Ítem
              TextFormField(
                controller: _itemController,
                decoration: const InputDecoration(
                  labelText: 'Ítem (ej: 01.01.02)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese el ítem' : null,
              ),
              const SizedBox(height: 10),

              // Descripción
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese una descripción' : null,
              ),

              if (!_isTitle) ...[
                const SizedBox(height: 10),
                // Unidad y Selector rápido
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Und común',
                          border: OutlineInputBorder(),
                        ),
                        items: _commonUnits.map((u) {
                          return DropdownMenuItem(value: u, child: Text(u));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _unitController.text = val;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Metrado y Rendimiento
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _metradoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Metrado',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Obligatorio';
                          if (double.tryParse(val) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _rendimientoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Rdto (und/día)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Obligatorio';
                          if (double.tryParse(val) == null) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
