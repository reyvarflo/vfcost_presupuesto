import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/apu_item.dart';
import '../models/resource.dart';

class ApuResourceDialog extends StatefulWidget {
  final ApuItem? existingItem;
  final List<Resource> masterCatalog;
  final double rendimiento;
  final double jornada;
  final double subtotalMO;
  final String currencySymbol;
  final Function(ApuItem) onSave;

  const ApuResourceDialog({
    super.key,
    this.existingItem,
    required this.masterCatalog,
    required this.rendimiento,
    required this.jornada,
    required this.subtotalMO,
    required this.currencySymbol,
    required this.onSave,
  });

  @override
  State<ApuResourceDialog> createState() => _ApuResourceDialogState();
}

class _ApuResourceDialogState extends State<ApuResourceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');

  late ResourceType _type;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _unitController;
  late TextEditingController _iuController;
  late TextEditingController _cuadrillaController;
  late TextEditingController _cantidadController;
  late TextEditingController _precioController;
  late TextEditingController _percentageController;
  late bool _isPercentageOfMO;
  String _resourceId = '';

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _type = item?.type ?? ResourceType.material;
    _resourceId = item?.resourceId ?? '';
    _codeController = TextEditingController(text: item?.resourceCode ?? '');
    _descController = TextEditingController(text: item?.resourceDescription ?? '');
    _unitController = TextEditingController(text: item?.unit ?? 'kg');
    _iuController = TextEditingController(text: item != null ? item.unifiedIndex.toString() : '2');
    _cuadrillaController = TextEditingController(text: item != null && item.cuadrilla > 0 ? item.cuadrilla.toString() : '1.0');
    _cantidadController = TextEditingController(text: item != null ? item.cantidad.toString() : '1.0');
    _precioController = TextEditingController(text: item != null ? item.precioUnitario.toString() : '0.0');
    _isPercentageOfMO = item?.isPercentageOfMO ?? false;
    _percentageController = TextEditingController(text: item != null ? item.percentageValue.toString() : '5.0');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _unitController.dispose();
    _iuController.dispose();
    _cuadrillaController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  void _onCuadrillaChanged(String val) {
    final cuadrilla = double.tryParse(val) ?? 0.0;
    if (widget.rendimiento > 0 && (_type == ResourceType.manoDeObra || _type == ResourceType.equipo)) {
      final cant = (cuadrilla * widget.jornada) / widget.rendimiento;
      _cantidadController.text = cant.toStringAsFixed(4);
      setState(() {});
    }
  }

  void _selectFromCatalog(Resource res) {
    setState(() {
      _resourceId = res.id;
      _type = res.type;
      _codeController.text = res.code;
      _descController.text = res.description;
      _unitController.text = res.unit;
      _iuController.text = res.unifiedIndex.toString();
      _precioController.text = res.unitPrice.toString();
      _isPercentageOfMO = res.unit.toLowerCase() == '%mo' || res.id.contains('herramientas');
      if (_isPercentageOfMO) {
        _percentageController.text = '5.0';
      } else if ((_type == ResourceType.manoDeObra || _type == ResourceType.equipo) && widget.rendimiento > 0) {
        final c = double.tryParse(_cuadrillaController.text) ?? 1.0;
        _cantidadController.text = ((c * widget.jornada) / widget.rendimiento).toStringAsFixed(4);
      }
    });
  }

  double _calculateCurrentParcial() {
    if (_isPercentageOfMO) {
      final p = double.tryParse(_percentageController.text) ?? 0.0;
      return widget.subtotalMO * (p / 100.0);
    }
    final cant = double.tryParse(_cantidadController.text) ?? 0.0;
    final price = double.tryParse(_precioController.text) ?? 0.0;
    return cant * price;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final cuadrilla = double.tryParse(_cuadrillaController.text) ?? 0.0;
      final cantidad = double.tryParse(_cantidadController.text) ?? 0.0;
      final precio = double.tryParse(_precioController.text) ?? 0.0;
      final iu = int.tryParse(_iuController.text) ?? 0;
      final percentVal = double.tryParse(_percentageController.text) ?? 0.0;

      final item = ApuItem(
        id: widget.existingItem?.id ?? const Uuid().v4(),
        resourceId: _resourceId,
        resourceCode: _codeController.text.trim(),
        resourceDescription: _descController.text.trim().toUpperCase(),
        unit: _isPercentageOfMO ? '%mo' : _unitController.text.trim().toLowerCase(),
        type: _type,
        unifiedIndex: iu,
        cuadrilla: _isPercentageOfMO ? 0.0 : cuadrilla,
        cantidad: _isPercentageOfMO ? 0.0 : cantidad,
        precioUnitario: _isPercentageOfMO ? 0.0 : precio,
        isPercentageOfMO: _isPercentageOfMO,
        percentageValue: percentVal,
      );

      widget.onSave(item);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parcial = _calculateCurrentParcial();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_shopping_cart, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(widget.existingItem != null ? 'Editar Insumo APU' : 'Agregar Insumo al APU'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón selector del catálogo de insumos
                OutlinedButton.icon(
                  onPressed: () => _openCatalogSelector(context),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Elegir del Catálogo Maestro S10'),
                ),
                const SizedBox(height: 12),

                // Selector de Tipo de Recurso
                DropdownButtonFormField<ResourceType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Recurso',
                    border: OutlineInputBorder(),
                  ),
                  items: ResourceType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text('${t.shortCode} - ${t.displayName}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _type = val;
                        if (_type == ResourceType.material) {
                          _isPercentageOfMO = false;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Código y Descripción
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Código',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción Insumo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Unidad e Índice Unificado (IU)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unidad (hh, m3, kg)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _iuController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Índice Unificado (IU)',
                          border: OutlineInputBorder(),
                          helperText: 'ej. 47 MO, 21 Cem, 02 Ac',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Toggle para Herramientas Manuales (% de Mano de Obra)
                if (_type == ResourceType.equipo) ...[
                  SwitchListTile(
                    title: const Text('¿Es % de Mano de Obra?'),
                    subtitle: const Text('Herramientas manuales estándar (% de MO)'),
                    value: _isPercentageOfMO,
                    onChanged: (val) {
                      setState(() {
                        _isPercentageOfMO = val;
                        if (val) _unitController.text = '%mo';
                      });
                    },
                  ),
                  if (_isPercentageOfMO) ...[
                    TextFormField(
                      controller: _percentageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Porcentaje de MO (%)',
                        border: const OutlineInputBorder(),
                        helperText: 'Subtotal MO actual: ${widget.currencySymbol} ${_currencyFormat.format(widget.subtotalMO)}',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                // Si NO es porcentaje: Cuadrilla, Cantidad y Precio
                if (!_isPercentageOfMO) ...[
                  if (_type == ResourceType.manoDeObra || _type == ResourceType.equipo) ...[
                    TextFormField(
                      controller: _cuadrillaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cuadrilla',
                        border: const OutlineInputBorder(),
                        helperText: 'Cantidad = (Cuadrilla × ${widget.jornada}h) / ${widget.rendimiento} rdto',
                      ),
                      onChanged: _onCuadrillaChanged,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cantidadController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cantidad / Aporte',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _precioController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Precio (${widget.currencySymbol})',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) => val == null || val.isEmpty ? 'Obligatorio' : null,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                // Tarjeta de Previsualización del Parcial
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Costo Parcial en APU:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${widget.currencySymbol} ${_currencyFormat.format(parcial)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          child: const Text('Aceptar'),
        ),
      ],
    );
  }

  void _openCatalogSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Catálogo Maestro de Insumos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: widget.masterCatalog.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final res = widget.masterCatalog[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(res.type.shortCode, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(res.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: Text('${res.code}  |  IU: ${res.unifiedIndex}  |  Und: ${res.unit}', style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          '${widget.currencySymbol} ${_currencyFormat.format(res.unitPrice)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          _selectFromCatalog(res);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
