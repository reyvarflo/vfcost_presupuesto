import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/presupuesto.dart';

class ProjectFormDialog extends StatefulWidget {
  final Presupuesto? existingProject;
  final Function(Presupuesto) onSave;

  const ProjectFormDialog({
    super.key,
    this.existingProject,
    required this.onSave,
  });

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _portafolios = [
    'Construcción',
    'Mejoramiento',
    'Ampliación',
    'Rehabilitación',
    'Mantenimiento',
    'Obras por Impuestos (OxI)',
    'Asociación Público Privada (APP)',
  ];

  static const List<String> _tiposObra = [
    'Edificaciones',
    'Agua potable y alcantarillado',
    'Obras Viales',
    'Infraestructura Educativa',
    'Obras Hidráulicas',
    'PROYECTO URBANIZMO',
    'DRENAJE PLUVIAL',
    'Electrificación',
  ];

  static const List<String> _departamentosPeru = [
    'AMAZONAS',
    'ANCASH',
    'APURIMAC',
    'AREQUIPA',
    'AYACUCHO',
    'CAJAMARCA',
    'CALLAO',
    'CUSCO',
    'HUANCAVELICA',
    'HUANUCO',
    'ICA',
    'JUNIN',
    'LA LIBERTAD',
    'LAMBAYEQUE',
    'LIMA',
    'LORETO',
    'MADRE DE DIOS',
    'MOQUEGUA',
    'PASCO',
    'PIURA',
    'PUNO',
    'SAN MARTIN',
    'TACNA',
    'TUMBES',
    'UCAYALI',
  ];

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _clientController;
  late TextEditingController _provController;
  late TextEditingController _distController;
  late TextEditingController _localidadController;
  late TextEditingController _currencySymbolController;
  late TextEditingController _currencyNameController;
  late TextEditingController _jornadaController;
  late TextEditingController _plazoController;
  late TextEditingController _hechoPorController;

  late String _naturaleza;
  late String _tipoObra;
  late String _departamento;
  late DateTime _fechaElaboracion;
  late String _unidadDuracion; // 'MESES' o 'DIAS'
  late String _modalidadEjecucion;
  late String _metodoCalculoAcu;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProject;
    _codeController = TextEditingController(text: p?.code ?? '0101001');
    _nameController = TextEditingController(text: p?.name ?? '');
    _clientController = TextEditingController(text: p?.client ?? '');

    // Intentar extraer Dpto / Prov / Dist de location si están separados por '-' o '>'
    String initDpto = p?.departamento ?? 'LIMA';
    String initProv = p?.provincia ?? 'LIMA';
    String initDist = p?.distrito ?? 'LIMA';
    if (p != null && p.location.isNotEmpty && p.departamento == 'LIMA') {
      final parts = p.location.split(RegExp(r'[-/>]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty && _departamentosPeru.contains(parts[0].toUpperCase())) {
        initDpto = parts[0].toUpperCase();
      }
      if (parts.length >= 2) initProv = parts[1].toUpperCase();
      if (parts.length >= 3) initDist = parts[2].toUpperCase();
    }

    _departamento = _departamentosPeru.contains(initDpto) ? initDpto : 'LIMA';
    _provController = TextEditingController(text: initProv);
    _distController = TextEditingController(text: initDist);
    _localidadController = TextEditingController(text: p?.localidad ?? '');
    _currencySymbolController = TextEditingController(text: p?.currencySymbol ?? 'S/.');
    _currencyNameController = TextEditingController(text: p?.currencyName ?? 'Soles');
    _jornadaController = TextEditingController(text: p?.jornada.toString() ?? '8.0');

    final plazoDias = p?.plazoDias ?? 120;
    if (plazoDias % 30 == 0 && plazoDias >= 30) {
      _unidadDuracion = 'MESES';
      _plazoController = TextEditingController(text: (plazoDias ~/ 30).toString());
    } else {
      _unidadDuracion = 'DIAS';
      _plazoController = TextEditingController(text: plazoDias.toString());
    }

    _hechoPorController = TextEditingController(text: p?.hechoPor ?? 'Administrador');
    _naturaleza = _portafolios.contains(p?.naturaleza) ? p!.naturaleza : 'Construcción';
    _tipoObra = _tiposObra.contains(p?.tipoObra) ? p!.tipoObra : 'Edificaciones';
    _fechaElaboracion = p?.date ?? DateTime.now();
    _modalidadEjecucion = p?.modalidadEjecucion ?? 'Por contrata';
    _metodoCalculoAcu = p?.metodoCalculoAcu ?? 'Por Rendimiento de Cuadrilla';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _clientController.dispose();
    _provController.dispose();
    _distController.dispose();
    _localidadController.dispose();
    _currencySymbolController.dispose();
    _currencyNameController.dispose();
    _jornadaController.dispose();
    _plazoController.dispose();
    _hechoPorController.dispose();
    super.dispose();
  }

  int get _calculatedPlazoDias {
    final raw = int.tryParse(_plazoController.text) ?? 1;
    final val = raw > 0 ? raw : 1;
    return _unidadDuracion == 'MESES' ? val * 30 : val;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final jornada = double.tryParse(_jornadaController.text) ?? 8.0;
      final plazoDias = _calculatedPlazoDias;
      final prov = _provController.text.trim().toUpperCase();
      final dist = _distController.text.trim().toUpperCase();
      final locBreadcrumb = '$_departamento > $prov > $dist';

      final baseProj = widget.existingProject ??
          Presupuesto(
            id: '',
            code: '',
            name: '',
            client: '',
            location: '',
            date: _fechaElaboracion,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      // Si es Por Administración Directa, la utilidad es 0%
      final updatedPie = _modalidadEjecucion == 'Por administración directa'
          ? baseProj.piePresupuesto.copyWith(porcentajeUtilidad: 0.0)
          : baseProj.piePresupuesto;

      final updated = baseProj.copyWith(
        code: _codeController.text.trim(),
        name: _nameController.text.trim().toUpperCase(),
        client: _clientController.text.trim().toUpperCase(),
        location: locBreadcrumb,
        departamento: _departamento,
        provincia: prov,
        distrito: dist,
        localidad: _localidadController.text.trim().toUpperCase(),
        naturaleza: _naturaleza,
        tipoObra: _tipoObra,
        date: _fechaElaboracion,
        currencySymbol: _currencySymbolController.text.trim(),
        currencyName: _currencyNameController.text.trim(),
        jornada: jornada > 0 ? jornada : 8.0,
        plazoDias: plazoDias,
        modalidadEjecucion: _modalidadEjecucion,
        metodoCalculoAcu: _metodoCalculoAcu,
        hechoPor: _hechoPorController.text.trim(),
        piePresupuesto: updatedPie,
      );

      widget.onSave(updated);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final fechaFin = _fechaElaboracion.add(Duration(days: _calculatedPlazoDias));
    final breadcrumb =
        '$_departamento > ${_provController.text.trim().toUpperCase()} > ${_distController.text.trim().toUpperCase()}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera estilo Delphin: "Datos del Proyecto / Información del proyecto"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFDCE6F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información del proyecto',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          'Mostrando datos generales, ubicación, duración y modalidad de ejecución',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Formulario desplazable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Código y Nombre del Proyecto
                      Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              controller: _codeController,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Código',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Proyecto',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 2. Propietario / Cliente
                      TextFormField(
                        controller: _clientController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Propietario / Entidad Contratante',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 10),

                      // 3. Portafolio y Tipo de Obra
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _naturaleza,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Portafolio',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _portafolios
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e, style: const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _naturaleza = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _tipoObra,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Obra',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _tiposObra
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e, style: const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _tipoObra = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 4. Sección Ubicación Geográfica (Estilo Delphin)
                      _buildSectionBox(
                        title: 'Ubicación Geográfica',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blueGrey.shade300),
                              ),
                              child: Text(
                                breadcrumb,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _departamento,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Departamento',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _departamentosPeru
                                        .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d, style: const TextStyle(fontSize: 11.5)),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _departamento = v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _provController,
                                    style: const TextStyle(fontSize: 11.5),
                                    decoration: const InputDecoration(
                                      labelText: 'Provincia',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _distController,
                                    style: const TextStyle(fontSize: 11.5),
                                    decoration: const InputDecoration(
                                      labelText: 'Distrito',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _localidadController,
                                    style: const TextStyle(fontSize: 11.5),
                                    decoration: const InputDecoration(
                                      labelText: 'Localidad / Centro Poblado',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 5. Sección Duración y Fechas
                      _buildSectionBox(
                        title: 'Duración y Jornada',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _fechaElaboracion,
                                        firstDate: DateTime(2015),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() => _fechaElaboracion = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha de elaboración / Inicio',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                                      ),
                                      child: Text(
                                        dateFmt.format(_fechaElaboracion),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Fin estimado',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      dateFmt.format(fechaFin),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    controller: _plazoController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      labelText: 'Duración',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 110,
                                  child: DropdownButtonFormField<String>(
                                    value: _unidadDuracion,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'MESES',
                                        child: Text('MESES', style: TextStyle(fontSize: 11.5)),
                                      ),
                                      DropdownMenuItem(
                                        value: 'DIAS',
                                        child: Text('DÍAS', style: TextStyle(fontSize: 11.5)),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _unidadDuracion = v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _jornadaController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      labelText: 'Jornada (h/día)',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 6. Modalidad de Ejecución (Por Contrata vs Por Administración Directa)
                      _buildSectionBox(
                        title: 'Modalidad de Ejecución',
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Por contrata', style: TextStyle(fontSize: 12)),
                                value: 'Por contrata',
                                groupValue: _modalidadEjecucion,
                                onChanged: (v) => setState(() => _modalidadEjecucion = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Por administración directa', style: TextStyle(fontSize: 12)),
                                value: 'Por administración directa',
                                groupValue: _modalidadEjecucion,
                                onChanged: (v) => setState(() => _modalidadEjecucion = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 7. Cálculo de Costos Unitarios
                      _buildSectionBox(
                        title: 'Cálculo de Costos Unitarios',
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Por Rendimiento de Cuadrilla', style: TextStyle(fontSize: 12)),
                              value: 'Por Rendimiento de Cuadrilla',
                              groupValue: _metodoCalculoAcu,
                              onChanged: (v) => setState(() => _metodoCalculoAcu = v!),
                            ),
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Por Asignación de Recursos, Disponibilidad y Duración de Tarea',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              value: 'Por Asignación de Recursos',
                              groupValue: _metodoCalculoAcu,
                              onChanged: (v) => setState(() => _metodoCalculoAcu = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 8. Hecho por & Moneda
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _hechoPorController,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Hecho por',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _currencySymbolController,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Moneda',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botones Aceptar / Cerrar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                border: Border(top: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aceptar'),
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBox({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
