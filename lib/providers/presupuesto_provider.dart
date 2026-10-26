import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/apu_item.dart';
import '../models/formula_polinomica.dart';
import '../models/gasto_general.dart';
import '../models/metrado_line.dart';
import '../models/partida.dart';
import '../models/pie_presupuesto.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';
import '../models/subpresupuesto.dart';
import '../models/valorizacion.dart';
import '../services/cronograma_service.dart';
import '../services/storage_service.dart';

class PresupuestoProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  List<Presupuesto> _presupuestos = [];
  Presupuesto? _activePresupuesto;
  List<Resource> _masterResources = [];
  bool _isLoading = true;
  String _searchFilter = '';

  List<Presupuesto> get presupuestos => _presupuestos;
  Presupuesto? get activePresupuesto => _activePresupuesto;
  List<Resource> get masterResources => _masterResources;
  bool get isLoading => _isLoading;
  String get searchFilter => _searchFilter;

  Subpresupuesto? get activeSubpresupuesto {
    if (_activePresupuesto == null) return null;
    return _activePresupuesto!.activeSubpresupuesto;
  }

  PresupuestoProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _presupuestos = await StorageService.loadPresupuestos();
    _masterResources = await StorageService.loadResources();

    final activeId = await StorageService.getActivePresupuestoId();
    if (activeId != null && _presupuestos.any((p) => p.id == activeId)) {
      _activePresupuesto = _presupuestos.firstWhere((p) => p.id == activeId);
    } else if (_presupuestos.isNotEmpty) {
      _activePresupuesto = _presupuestos.first;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSearchFilter(String query) {
    _searchFilter = query;
    notifyListeners();
  }

  void selectPresupuesto(String id) {
    if (_presupuestos.any((p) => p.id == id)) {
      _activePresupuesto = _presupuestos.firstWhere((p) => p.id == id);
      StorageService.saveActivePresupuestoId(id);
      notifyListeners();
    }
  }

  void selectSubpresupuesto(String subId) {
    if (_activePresupuesto == null) return;
    if (_activePresupuesto!.subpresupuestos.any((s) => s.id == subId)) {
      _activePresupuesto = _activePresupuesto!.copyWith(
        activeSubpresupuestoId: subId,
      );
      _persistActivePresupuesto();
      notifyListeners();
    }
  }

  Future<void> createPresupuesto({
    required String code,
    required String name,
    required String client,
    required String location,
    DateTime? date,
    String currencySymbol = 'S/.',
    String currencyName = 'Soles',
    double jornada = 8.0,
    int plazoDias = 120,
    String tipoObra = 'Edificaciones',
    String naturaleza = 'Construcción',
  }) async {
    final subEstructuras = Subpresupuesto(
      id: _uuid.v4(),
      code: '001',
      name: 'ESTRUCTURAS',
      partidas: [],
    );

    final newPresupuesto = Presupuesto(
      id: _uuid.v4(),
      code: code,
      name: name,
      client: client,
      location: location,
      date: date ?? DateTime.now(),
      currencySymbol: currencySymbol,
      currencyName: currencyName,
      jornada: jornada,
      plazoDias: plazoDias,
      tipoObra: tipoObra,
      naturaleza: naturaleza,
      subpresupuestos: [subEstructuras],
      piePresupuesto: const PiePresupuesto(),
      formulaPolinomica: const FormulaPolinomica(),
      activeSubpresupuestoId: subEstructuras.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _presupuestos.add(newPresupuesto);
    _activePresupuesto = newPresupuesto;
    await _persistAll();
    notifyListeners();
  }

  Future<void> toggleLockPresupuesto(String id) async {
    final index = _presupuestos.indexWhere((p) => p.id == id);
    if (index != -1) {
      final updated = _presupuestos[index].copyWith(
        isLocked: !_presupuestos[index].isLocked,
        updatedAt: DateTime.now(),
      );
      _presupuestos[index] = updated;
      if (_activePresupuesto?.id == id) {
        _activePresupuesto = updated;
      }
      await _persistAll();
      notifyListeners();
    }
  }

  Future<void> updatePresupuestoMetadata(Presupuesto updated) async {
    _activePresupuesto = updated.copyWith(updatedAt: DateTime.now());
    final index = _presupuestos.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _presupuestos[index] = _activePresupuesto!;
    }
    await _persistAll();
    notifyListeners();
  }

  Future<void> duplicatePresupuesto(String id) async {
    final original = _presupuestos.firstWhere((p) => p.id == id);
    final copy = original.copyWith(
      id: _uuid.v4(),
      code: '${original.code}-C',
      name: '${original.name} (COPIA)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _presupuestos.add(copy);
    _activePresupuesto = copy;
    await _persistAll();
    notifyListeners();
  }

  Future<void> deletePresupuesto(String id) async {
    _presupuestos.removeWhere((p) => p.id == id);
    if (_activePresupuesto?.id == id) {
      _activePresupuesto = _presupuestos.isNotEmpty ? _presupuestos.first : null;
    }
    await _persistAll();
    notifyListeners();
  }

  // --- SUBPRESUPUESTOS ---
  Future<void> addSubpresupuesto(String name) async {
    if (_activePresupuesto == null) return;
    final nextNumber = _activePresupuesto!.subpresupuestos.length + 1;
    final code = nextNumber.toString().padLeft(3, '0');

    final newSub = Subpresupuesto(
      id: _uuid.v4(),
      code: code,
      name: name.toUpperCase(),
      partidas: [],
    );

    final updatedSubs = List<Subpresupuesto>.from(_activePresupuesto!.subpresupuestos)..add(newSub);
    _activePresupuesto = _activePresupuesto!.copyWith(
      subpresupuestos: updatedSubs,
      activeSubpresupuestoId: newSub.id,
    );
    await _persistActivePresupuesto();
    notifyListeners();
  }

  Future<void> deleteSubpresupuesto(String subId) async {
    if (_activePresupuesto == null || _activePresupuesto!.subpresupuestos.length <= 1) return;
    final updatedSubs = _activePresupuesto!.subpresupuestos.where((s) => s.id != subId).toList();
    _activePresupuesto = _activePresupuesto!.copyWith(
      subpresupuestos: updatedSubs,
      activeSubpresupuestoId: updatedSubs.first.id,
    );
    await _persistActivePresupuesto();
    notifyListeners();
  }

  // --- PARTIDAS ---
  Future<void> addPartida({
    required String itemNumber,
    required String description,
    required bool isTitle,
    required int level,
    String unit = '',
    double metrado = 0.0,
    double rendimiento = 1.0,
  }) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final newPartida = Partida(
      id: _uuid.v4(),
      itemNumber: itemNumber,
      description: description.toUpperCase(),
      isTitle: isTitle,
      level: level,
      unit: unit,
      metrado: metrado,
      rendimiento: rendimiento > 0 ? rendimiento : 1.0,
      apuItems: [],
    );

    final currentPartidas = List<Partida>.from(activeSubpresupuesto!.partidas)..add(newPartida);
    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  Future<void> updatePartida(Partida updated) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final currentPartidas = activeSubpresupuesto!.partidas.map((p) {
      return p.id == updated.id ? updated : p;
    }).toList();

    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  Future<void> deletePartida(String partidaId) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final currentPartidas = activeSubpresupuesto!.partidas.where((p) => p.id != partidaId).toList();
    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  Future<void> reorderPartida(int oldIndex, int newIndex) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final list = List<Partida>.from(activeSubpresupuesto!.partidas);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    _updateActiveSubPartidas(list);
    await procesarPresupuesto();
  }

  Future<void> changePartidaIndent(String partidaId, bool increase) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final list = activeSubpresupuesto!.partidas.map((p) {
      if (p.id == partidaId) {
        final newLevel = increase ? (p.level + 1).clamp(1, 5) : (p.level - 1).clamp(1, 5);
        return p.copyWith(level: newLevel);
      }
      return p;
    }).toList();

    _updateActiveSubPartidas(list);
    await procesarPresupuesto();
  }

  // --- APU (ANÁLISIS DE PRECIOS UNITARIOS) ---
  Future<void> addApuItem(String partidaId, ApuItem item) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final currentPartidas = activeSubpresupuesto!.partidas.map((p) {
      if (p.id == partidaId) {
        final updatedApu = List<ApuItem>.from(p.apuItems)..add(item);
        return p.copyWith(apuItems: updatedApu);
      }
      return p;
    }).toList();

    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  Future<void> updateApuItem(String partidaId, ApuItem item) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final currentPartidas = activeSubpresupuesto!.partidas.map((p) {
      if (p.id == partidaId) {
        final updatedApu = p.apuItems.map((a) => a.id == item.id ? item : a).toList();
        return p.copyWith(apuItems: updatedApu);
      }
      return p;
    }).toList();

    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  Future<void> removeApuItem(String partidaId, String apuItemId) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final currentPartidas = activeSubpresupuesto!.partidas.map((p) {
      if (p.id == partidaId) {
        final updatedApu = p.apuItems.where((a) => a.id != apuItemId).toList();
        return p.copyWith(apuItems: updatedApu);
      }
      return p;
    }).toList();

    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  // --- DELPHIN EXPRESS: HOJA DE METRADOS ---
  Future<void> updatePartidaMetrados(String partidaId, List<MetradoLine> lines) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final totalHoja = lines.fold(0.0, (s, l) => s + l.parcial);

    final currentPartidas = activeSubpresupuesto!.partidas.map((p) {
      if (p.id == partidaId) {
        return p.copyWith(
          metradoLines: lines,
          metrado: lines.isNotEmpty ? totalHoja : p.metrado,
        );
      }
      return p;
    }).toList();

    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  // --- DELPHIN EXPRESS: PRECIOS GLOBALES DE INSUMOS Y PROVEEDORES ---
  Future<int> updatePrecioGlobalInsumo({
    required String resourceDescription,
    required ResourceType type,
    required double nuevoPrecio,
    String? nuevoProveedor,
    String? nuevaMarca,
    int? nuevoIndiceUnificado,
  }) async {
    if (_activePresupuesto == null || nuevoPrecio < 0) return 0;

    int affectedCount = 0;
    final updatedSubs = _activePresupuesto!.subpresupuestos.map((sub) {
      final updatedPartidas = sub.partidas.map((partida) {
        if (partida.isTitle) return partida;
        bool partidaModified = false;
        final updatedApus = partida.apuItems.map((apu) {
          final isSameType = apu.type == type;
          final isSameDesc = apu.resourceDescription.trim().toUpperCase() ==
              resourceDescription.trim().toUpperCase();
          if (isSameType && isSameDesc) {
            affectedCount++;
            partidaModified = true;
            return apu.copyWith(
              precioUnitario: nuevoPrecio,
              proveedor: nuevoProveedor ?? apu.proveedor,
              marca: nuevaMarca ?? apu.marca,
              unifiedIndex: nuevoIndiceUnificado ?? apu.unifiedIndex,
            );
          }
          return apu;
        }).toList();

        return partidaModified ? partida.copyWith(apuItems: updatedApus) : partida;
      }).toList();

      return sub.copyWith(partidas: updatedPartidas);
    }).toList();

    _activePresupuesto = _activePresupuesto!.copyWith(subpresupuestos: updatedSubs);
    await procesarPresupuesto();
    return affectedCount;
  }

  /// Sincroniza los precios e IU de todos los insumos del proyecto con el catálogo maestro
  /// ("Actualizar insumos -> Datos de insumos" en Delphin Express)
  Future<int> sincronizarInsumosConCatalogo() async {
    if (_activePresupuesto == null) return 0;

    final catalogByDesc = <String, Resource>{};
    for (final r in _masterResources) {
      catalogByDesc[r.description.trim().toUpperCase()] = r;
    }

    int syncedCount = 0;
    final updatedSubs = _activePresupuesto!.subpresupuestos.map((sub) {
      final updatedPartidas = sub.partidas.map((partida) {
        if (partida.isTitle) return partida;
        bool modified = false;
        final updatedApus = partida.apuItems.map((apu) {
          if (apu.isPercentageOfMO) return apu;
          final key = apu.resourceDescription.trim().toUpperCase();
          final catItem = catalogByDesc[key];
          if (catItem != null && (apu.precioUnitario - catItem.unitPrice).abs() > 0.001) {
            modified = true;
            syncedCount++;
            return apu.copyWith(
              precioUnitario: catItem.unitPrice,
              unifiedIndex: catItem.unifiedIndex > 0 ? catItem.unifiedIndex : apu.unifiedIndex,
            );
          }
          return apu;
        }).toList();
        return modified ? partida.copyWith(apuItems: updatedApus) : partida;
      }).toList();
      return sub.copyWith(partidas: updatedPartidas);
    }).toList();

    if (syncedCount > 0) {
      _activePresupuesto = _activePresupuesto!.copyWith(subpresupuestos: updatedSubs);
      await procesarPresupuesto();
    }
    return syncedCount;
  }

  Future<void> updateTipoCambio(double nuevoTC) async {
    if (_activePresupuesto == null || nuevoTC <= 0) return;
    _activePresupuesto = _activePresupuesto!.copyWith(tipoCambio: nuevoTC);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  // --- DELPHIN EXPRESS: BANCO DE PARTIDAS (PLANTILLAS) ---
  Future<void> importPartidaFromLibrary(Partida template) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    // Generar nuevo código de ítem según las partidas existentes
    String newItemNumber = '01.01';
    final partidas = activeSubpresupuesto!.partidas;
    if (partidas.isNotEmpty) {
      final last = partidas.last;
      final parts = last.itemNumber.split('.');
      if (parts.isNotEmpty) {
        final lastNum = int.tryParse(parts.last) ?? 1;
        parts[parts.length - 1] = (lastNum + 1).toString().padLeft(2, '0');
        newItemNumber = parts.join('.');
      }
    }

    final newPartida = Partida(
      id: _uuid.v4(),
      itemNumber: newItemNumber,
      description: template.description,
      isTitle: false,
      level: 2,
      unit: template.unit,
      metrado: template.metrado > 0 ? template.metrado : 10.0,
      rendimiento: template.rendimiento > 0 ? template.rendimiento : 1.0,
      apuItems: template.apuItems.map((item) {
        return item.copyWith(id: _uuid.v4());
      }).toList(),
    );

    final currentPartidas = List<Partida>.from(activeSubpresupuesto!.partidas)..add(newPartida);
    _updateActiveSubPartidas(currentPartidas);
    await procesarPresupuesto();
  }

  // --- DELPHIN EXPRESS: PROGRAMACIÓN / CRONOGRAMA GANTT ---
  Future<void> updatePartidaProgramacion({
    required String partidaId,
    int? inicioDia,
    int? duracionDiasManual,
    String? predecesoraId,
    bool clearPredecesora = false,
    int? desfaseDias,
  }) async {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;

    final currentPartidas = activeSubpresupuesto!.partidas.map((p) {
      if (p.id == partidaId) {
        return p.copyWith(
          inicioDia: inicioDia ?? p.inicioDia,
          duracionDias: duracionDiasManual,
          predecesoraId: predecesoraId ?? p.predecesoraId,
          clearPredecesora: clearPredecesora,
          desfaseDias: desfaseDias ?? p.desfaseDias,
        );
      }
      return p;
    }).toList();

    _updateActiveSubPartidas(currentPartidas);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  Future<void> autoSecuenciarPartidas() async {
    if (_activePresupuesto == null) return;
    final encadenados = CronogramaService.encadenar(_activePresupuesto!.subpresupuestos);
    _activePresupuesto = _activePresupuesto!.copyWith(subpresupuestos: encadenados);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  // --- DELPHIN EXPRESS: GASTOS GENERALES ANALÍTICOS ---
  Future<void> addGastoGeneralItem(GastoGeneralItem item) async {
    if (_activePresupuesto == null) return;
    final list = List<GastoGeneralItem>.from(_activePresupuesto!.gastosGenerales)..add(item);
    _activePresupuesto = _activePresupuesto!.copyWith(gastosGenerales: list);
    if (_activePresupuesto!.usarGGDesagregado) {
      _syncGGPie();
    }
    await procesarPresupuesto();
  }

  Future<void> updateGastoGeneralItem(GastoGeneralItem item) async {
    if (_activePresupuesto == null) return;
    final list = _activePresupuesto!.gastosGenerales.map((g) => g.id == item.id ? item : g).toList();
    _activePresupuesto = _activePresupuesto!.copyWith(gastosGenerales: list);
    if (_activePresupuesto!.usarGGDesagregado) {
      _syncGGPie();
    }
    await procesarPresupuesto();
  }

  Future<void> removeGastoGeneralItem(String itemId) async {
    if (_activePresupuesto == null) return;
    final list = _activePresupuesto!.gastosGenerales.where((g) => g.id != itemId).toList();
    _activePresupuesto = _activePresupuesto!.copyWith(gastosGenerales: list);
    if (_activePresupuesto!.usarGGDesagregado) {
      _syncGGPie();
    }
    await procesarPresupuesto();
  }

  Future<void> toggleUsarGGDesagregado(bool value) async {
    if (_activePresupuesto == null) return;
    _activePresupuesto = _activePresupuesto!.copyWith(usarGGDesagregado: value);
    if (value) {
      _syncGGPie();
    }
    await procesarPresupuesto();
  }

  void _syncGGPie() {
    if (_activePresupuesto == null) return;
    final cd = _activePresupuesto!.totalCostoDirecto;
    if (cd <= 0) return;

    final fijosMonto = _activePresupuesto!.totalGGFijosDesagregado;
    final varMonto = _activePresupuesto!.totalGGVariablesDesagregado;

    final pctFijos = double.parse(((fijosMonto / cd) * 100).toStringAsFixed(2));
    final pctVar = double.parse(((varMonto / cd) * 100).toStringAsFixed(2));

    final currentPie = _activePresupuesto!.piePresupuesto;
    _activePresupuesto = _activePresupuesto!.copyWith(
      piePresupuesto: currentPie.copyWith(
        porcentajeGGFijos: pctFijos,
        porcentajeGGVariables: pctVar,
      ),
    );
  }

  Future<void> cargarPlantillaGastosGenerales() async {
    if (_activePresupuesto == null) return;

    final plazoMeses = (_activePresupuesto!.plazoDias / 30.0).clamp(1.0, 36.0);

    final plantilla = [
      // GG Fijos
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.fijo,
        descripcion: 'GASTOS DE LICITACIÓN Y FORMALIZACIÓN DE CONTRATO (BASES, NOTARÍA)',
        unidad: 'glb',
        cantidad: 1.0,
        tiempo: 1.0,
        precio: 3500.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.fijo,
        descripcion: 'CARTA FIANZA DE FIEL CUMPLIMIENTO Y ADELANTO DIRECTO',
        unidad: 'glb',
        cantidad: 1.0,
        tiempo: 1.0,
        precio: 4200.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.fijo,
        descripcion: 'ENSAYOS DE CONTROL DE CALIDAD (PROBETAS DE CONCRETO Y DENSIDAD)',
        unidad: 'glb',
        cantidad: 1.0,
        tiempo: 1.0,
        precio: 2800.0,
        participacion: 100.0,
      ),
      // GG Variables
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.variable,
        descripcion: 'INGENIERO RESIDENTE DE OBRA (CIP)',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: plazoMeses,
        precio: 7500.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.variable,
        descripcion: 'INGENIERO ASISTENTE DE CONTROL Y SEGURIDAD (SSOMA)',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: plazoMeses,
        precio: 4500.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.variable,
        descripcion: 'MAESTRO DE OBRA GENERAL',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: plazoMeses,
        precio: 3800.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.variable,
        descripcion: 'ALQUILER DE CAMIONETA 4X4 (SUPERVISIÓN Y LOGÍSTICA)',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: plazoMeses,
        precio: 3200.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.variable,
        descripcion: 'ALQUILER DE OFICINA, ALMACÉN Y GUARDIANÍA DE OBRA',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: plazoMeses,
        precio: 1500.0,
        participacion: 100.0,
      ),
      GastoGeneralItem(
        id: _uuid.v4(),
        tipo: TipoGasto.variable,
        descripcion: 'EQUIPOS DE PROTECCIÓN PERSONAL (EPP) Y SEGURIDAD',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: plazoMeses,
        precio: 1200.0,
        participacion: 100.0,
      ),
    ];

    _activePresupuesto = _activePresupuesto!.copyWith(
      gastosGenerales: plantilla,
      usarGGDesagregado: true,
    );
    _syncGGPie();
    await procesarPresupuesto();
  }

  // --- DELPHIN EXPRESS: VALORIZACIONES MENSUALES ---
  Future<void> addValorizacion(Valorizacion v) async {
    if (_activePresupuesto == null) return;
    final list = List<Valorizacion>.from(_activePresupuesto!.valorizaciones)..add(v);
    _activePresupuesto = _activePresupuesto!.copyWith(valorizaciones: list);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  Future<void> updateValorizacion(Valorizacion v) async {
    if (_activePresupuesto == null) return;
    final list = _activePresupuesto!.valorizaciones.map((x) => x.id == v.id ? v : x).toList();
    _activePresupuesto = _activePresupuesto!.copyWith(valorizaciones: list);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  Future<void> deleteValorizacion(String valId) async {
    if (_activePresupuesto == null) return;
    final list = _activePresupuesto!.valorizaciones.where((x) => x.id != valId).toList();
    _activePresupuesto = _activePresupuesto!.copyWith(valorizaciones: list);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  Future<void> setIndiceBase(int iu, double valor) async {
    if (_activePresupuesto == null) return;
    final current = Map<int, double>.from(_activePresupuesto!.indicesBase);
    current[iu] = valor;
    _activePresupuesto = _activePresupuesto!.copyWith(indicesBase: current);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  // --- EL EMBLEMÁTICO "PROCESAR PRESUPUESTO" (F9 EN S10) ---
  Future<void> procesarPresupuesto() async {
    if (_activePresupuesto == null) return;

    // Recalcular todo el presupuesto (partidas, rollups, Costo Directo y Pie)
    var processed = _activePresupuesto!.processAll();

    // Actualizar automáticamente la Fórmula Polinómica preliminar por Índices Unificados
    processed = _autoGenerateFormulaPolinomica(processed);

    _activePresupuesto = processed;
    await _persistActivePresupuesto();
    notifyListeners();
  }

  Presupuesto _autoGenerateFormulaPolinomica(Presupuesto p) {
    if (p.totalCostoDirecto <= 0) return p;

    final cd = p.totalCostoDirecto;
    final iuCostMap = <int, double>{};

    for (final sub in p.subpresupuestos) {
      for (final partida in sub.partidas) {
        if (partida.isTitle) continue;
        for (final apu in partida.apuItems) {
          final iu = apu.unifiedIndex > 0 ? apu.unifiedIndex : (apu.type == ResourceType.manoDeObra ? 47 : 39);
          final cost = apu.calculateParcial(subtotalMO: partida.subtotalMO) * partida.metrado;
          iuCostMap[iu] = (iuCostMap[iu] ?? 0.0) + cost;
        }
      }
    }

    if (iuCostMap.isEmpty) return p;

    // Calcular participación de GG y Utilidad
    final ggUtilCost = p.totalGastosGenerales + p.totalUtilidad;
    final totalPresupuestoSinIGV = cd + ggUtilCost;

    // Generar monomios ponderados
    final monomios = <Monomio>[];
    int monomioIndex = 1;

    // 1. Mano de Obra (IU 47)
    final moCost = iuCostMap[47] ?? 0.0;
    if (moCost > 0) {
      final kMO = moCost / totalPresupuestoSinIGV;
      monomios.add(Monomio(
        monomioNumber: monomioIndex++,
        symbol: 'MO',
        coeficiente: double.parse(kMO.toStringAsFixed(3)),
        submonomios: [
          const Submonomio(
            unifiedIndex: 47,
            description: 'Mano de Obra inc. Leyes Sociales',
            factor: 1.0,
          ),
        ],
      ));
    }

    // 2. Materiales significativos (IU 21 Cemento, IU 2 Acero, etc.)
    final matIndices = iuCostMap.keys.where((iu) => iu != 47 && iu != 37 && iu != 48 && iu != 49).toList();
    for (final iu in matIndices) {
      final cost = iuCostMap[iu] ?? 0.0;
      final k = cost / totalPresupuestoSinIGV;
      if (k >= 0.04 && monomios.length < 5) {
        monomios.add(Monomio(
          monomioNumber: monomioIndex++,
          symbol: 'MAT_$iu',
          coeficiente: double.parse(k.toStringAsFixed(3)),
          submonomios: [
            Submonomio(
              unifiedIndex: iu,
              description: 'Insumos Índice Unificado $iu',
              factor: 1.0,
            ),
          ],
        ));
      }
    }

    // 3. Equipos y Maquinarias (IU 48 / 49 / 37)
    final eqCost = (iuCostMap[48] ?? 0.0) + (iuCostMap[49] ?? 0.0) + (iuCostMap[37] ?? 0.0);
    if (eqCost > 0 && monomios.length < 6) {
      final kEQ = eqCost / totalPresupuestoSinIGV;
      monomios.add(Monomio(
        monomioNumber: monomioIndex++,
        symbol: 'EQ',
        coeficiente: double.parse(kEQ.toStringAsFixed(3)),
        submonomios: [
          const Submonomio(
            unifiedIndex: 49,
            description: 'Maquinaria y Equipo',
            factor: 1.0,
          ),
        ],
      ));
    }

    // Monomio final: Gastos Generales y Utilidad (IU 39)
    final currentSum = monomios.fold(0.0, (sum, m) => sum + m.coeficiente);
    final kGU = (1.0 - currentSum).clamp(0.05, 0.40);
    monomios.add(Monomio(
      monomioNumber: monomioIndex,
      symbol: 'GU',
      coeficiente: double.parse(kGU.toStringAsFixed(3)),
      submonomios: [
        const Submonomio(
          unifiedIndex: 39,
          description: 'Índice General de Precios al Consumidor (GG y Utilidad)',
          factor: 1.0,
        ),
      ],
    ));

    return p.copyWith(formulaPolinomica: FormulaPolinomica(monomios: monomios));
  }

  Future<void> updatePiePresupuesto(PiePresupuesto pie) async {
    if (_activePresupuesto == null) return;
    _activePresupuesto = _activePresupuesto!.copyWith(piePresupuesto: pie);
    await procesarPresupuesto();
  }

  Future<void> updateFormulaPolinomica(FormulaPolinomica formula) async {
    if (_activePresupuesto == null) return;
    _activePresupuesto = _activePresupuesto!.copyWith(formulaPolinomica: formula);
    await _persistActivePresupuesto();
    notifyListeners();
  }

  // --- CATÁLOGO DE RECURSOS ---
  Future<void> addCustomResource(Resource res) async {
    _masterResources.add(res);
    await StorageService.saveCustomResource(res);
    notifyListeners();
  }

  // --- IMPORT / EXPORT JSON ---
  String exportCurrentPresupuestoJson() {
    if (_activePresupuesto == null) return '{}';
    return StorageService.exportPresupuestoToJson(_activePresupuesto!);
  }

  Future<bool> importPresupuestoFromJson(String jsonStr) async {
    final imported = StorageService.importPresupuestoFromJson(jsonStr);
    if (imported == null) return false;

    // Generar nuevos IDs para evitar colisiones
    final refreshed = imported.copyWith(
      id: _uuid.v4(),
      code: '${imported.code}-IMP',
      name: '${imported.name} (IMPORTADO)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _presupuestos.add(refreshed);
    _activePresupuesto = refreshed;
    await _persistAll();
    notifyListeners();
    return true;
  }

  Future<bool> importarPresupuestoExterno(Presupuesto imported) async {
    final processed = imported.processAll();
    final withFormula = _autoGenerateFormulaPolinomica(processed);

    final refreshed = withFormula.copyWith(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _presupuestos.add(refreshed);
    _activePresupuesto = refreshed;
    await _persistAll();
    notifyListeners();
    return true;
  }

  /// Restaura una lista completa de presupuestos provenientes de Google Drive / Nube
  Future<int> restaurarMultiplesPresupuestos(List<Presupuesto> lista, {bool sobrescribir = false}) async {
    if (lista.isEmpty) return 0;
    int count = 0;

    for (final raw in lista) {
      final processed = raw.processAll();
      final withFormula = _autoGenerateFormulaPolinomica(processed);

      final existingIndex = _presupuestos.indexWhere((p) => p.code == withFormula.code);
      if (existingIndex != -1) {
        if (sobrescribir) {
          _presupuestos[existingIndex] = withFormula.copyWith(
            id: _presupuestos[existingIndex].id,
            updatedAt: DateTime.now(),
          );
          count++;
        } else {
          final duplicated = withFormula.copyWith(
            id: _uuid.v4(),
            code: '${withFormula.code}-DRIVE',
            name: '${withFormula.name} (Drive)',
            updatedAt: DateTime.now(),
          );
          _presupuestos.add(duplicated);
          count++;
        }
      } else {
        _presupuestos.add(withFormula);
        count++;
      }
    }

    if (_presupuestos.isNotEmpty) {
      _activePresupuesto = _presupuestos.first;
    }

    await _persistAll();
    notifyListeners();
    return count;
  }

  // --- HELPERS PRIVADOS ---
  void _updateActiveSubPartidas(List<Partida> partidas) {
    if (_activePresupuesto == null || activeSubpresupuesto == null) return;
    final updatedSub = activeSubpresupuesto!.copyWith(partidas: partidas);
    final updatedSubs = _activePresupuesto!.subpresupuestos.map((s) {
      return s.id == updatedSub.id ? updatedSub : s;
    }).toList();
    _activePresupuesto = _activePresupuesto!.copyWith(subpresupuestos: updatedSubs);
  }

  Future<void> _persistActivePresupuesto() async {
    if (_activePresupuesto == null) return;
    final index = _presupuestos.indexWhere((p) => p.id == _activePresupuesto!.id);
    if (index != -1) {
      _presupuestos[index] = _activePresupuesto!;
    }
    await _persistAll();
  }

  Future<void> _persistAll() async {
    await StorageService.savePresupuestos(_presupuestos);
    if (_activePresupuesto != null) {
      await StorageService.saveActivePresupuestoId(_activePresupuesto!.id);
    }
  }
}
