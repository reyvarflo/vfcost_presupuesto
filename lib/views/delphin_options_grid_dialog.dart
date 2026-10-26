import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/presupuesto_provider.dart';
import 'cloud_drive_screen.dart';
import 'delphin_costos_unitarios_screen.dart';
import 'resource_catalog_screen.dart';
import 'tabs/reportes_tab.dart';

class DelphinOptionsGridDialog extends StatelessWidget {
  const DelphinOptionsGridDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opciones y Maestros (Delphin Express)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Bancos de costos, insumos, índices INEI y catálogos centrales',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    // 1. Costos Unitarios S/.
                    _buildTile(
                      context,
                      color: const Color(0xFF5B3C88),
                      symbol: 'S/.',
                      title: 'Costos Unitarios',
                      subtitle: 'Banco Maestro APUs',
                      onTap: () => _openCostosUnitarios(context),
                    ),
                    // 2. Grupos de Costos
                    _buildTile(
                      context,
                      color: const Color(0xFFE26D1E),
                      icon: Icons.folder_copy_outlined,
                      title: 'Grupos de Costos',
                      subtitle: 'Partidas por Especialidad',
                      onTap: () => _openGruposCostos(context),
                    ),
                    // 3. Unidades u
                    _buildTile(
                      context,
                      color: const Color(0xFF2C3238),
                      symbol: 'u',
                      title: 'Unidades',
                      subtitle: 'm3, m2, kg, hh, glb',
                      onTap: () => _openUnidades(context),
                    ),
                    // 4. Lista de Insumos
                    _buildTile(
                      context,
                      color: const Color(0xFF00A2D3),
                      icon: Icons.inventory_2_outlined,
                      title: 'Lista de Insumos',
                      subtitle: 'M.O, Materiales, Equipos',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ResourceCatalogScreen()),
                        );
                      },
                    ),
                    // 5. Diccionario
                    _buildTile(
                      context,
                      color: const Color(0xFF9E5429),
                      icon: Icons.menu_book_outlined,
                      title: 'Diccionario',
                      subtitle: 'Términos de Ingeniería',
                      onTap: () => _openDiccionario(context),
                    ),
                    // 6. Índices Unificados
                    _buildTile(
                      context,
                      color: const Color(0xFF4C8C2B),
                      icon: Icons.format_list_numbered,
                      title: 'Índices (01-80)',
                      subtitle: 'Tabla Oficial INEI',
                      onTap: () => _openIndicesInei(context),
                    ),
                    // 7. Proveedores
                    _buildTile(
                      context,
                      color: const Color(0xFFE8A800),
                      icon: Icons.storefront_outlined,
                      title: 'Proveedores',
                      subtitle: 'Cotizaciones y Compras',
                      onTap: () => _openProveedores(context),
                    ),
                    // 8. Clientes
                    _buildTile(
                      context,
                      color: const Color(0xFFF1C40F),
                      icon: Icons.people_alt_outlined,
                      title: 'Clientes',
                      subtitle: 'Entidades y Municipios',
                      textColor: Colors.black87,
                      onTap: () => _openClientes(context),
                    ),
                    // 9. Tipos de Obra
                    _buildTile(
                      context,
                      color: const Color(0xFF8E1B38),
                      icon: Icons.home_work_outlined,
                      title: 'Tipos de Obra',
                      subtitle: 'Viales, Edif, Saneam.',
                      onTap: () => _openTiposObra(context),
                    ),
                    // 10. Encabezados
                    _buildTile(
                      context,
                      color: const Color(0xFF679E22),
                      symbol: 'T..',
                      title: 'Encabezados',
                      subtitle: 'Formatos de Reportes',
                      onTap: () => _openEncabezados(context),
                    ),
                    // 11. Plantillas Costo
                    _buildTile(
                      context,
                      color: const Color(0xFFB5234A),
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Plantillas Costo',
                      subtitle: 'Proyectos Tipo',
                      onTap: () => _openPlantillas(context),
                    ),
                    // 12. Parámetros
                    _buildTile(
                      context,
                      color: const Color(0xFF555B62),
                      icon: Icons.settings_suggest_outlined,
                      title: 'Parámetros',
                      subtitle: 'Moneda, Jornada, IGV',
                      onTap: () => _openParametros(context),
                    ),
                    // 13. Google Drive & Red
                    _buildTile(
                      context,
                      color: const Color(0xFF4285F4),
                      icon: Icons.cloud_sync,
                      title: 'Google Drive',
                      subtitle: 'Respaldo y Red',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CloudDriveScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required Color color,
    IconData? icon,
    String? symbol,
    required String title,
    required String subtitle,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (symbol != null)
                Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontFamily: 'serif',
                  ),
                )
              else if (icon != null)
                Icon(icon, color: textColor, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUBDIÁLOGOS DE MAESTROS DELPHIN ---

  void _openIndicesInei(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 3),
      ),
    );
  }

  void _openUnidades(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 2),
      ),
    );
  }

  void _openClientes(BuildContext context) {
    final provider = context.read<PresupuestoProvider>();
    final presupuestos = provider.presupuestos;
    final clientes = <String, int>{};
    for (final p in presupuestos) {
      if (p.client.isNotEmpty) {
        clientes[p.client] = (clientes[p.client] ?? 0) + 1;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.people_alt, color: Color(0xFFE8A800)),
            SizedBox(width: 8),
            Text('Directorio de Clientes / Entidades'),
          ],
        ),
        content: SizedBox(
          width: 460,
          height: 350,
          child: clientes.isEmpty
              ? const Center(child: Text('No hay clientes registrados en los proyectos.'))
              : ListView(
                  children: clientes.entries.map((e) {
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        child: Icon(Icons.account_balance, size: 18),
                      ),
                      title: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      trailing: Chip(
                        label: Text('${e.value} obras', style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _openTiposObra(BuildContext context) {
    final tipos = [
      'Edificaciones',
      'Agua potable y alcantarillado',
      'Obras Viales',
      'Infraestructura Educativa',
      'Obras Hidráulicas',
      'Defensas Ribereñas',
      'Proyecto Urbanismo',
      'Drenaje Pluvial',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.home_work, color: Color(0xFF8E1B38)),
            SizedBox(width: 8),
            Text('Especialidades y Tipos de Obra'),
          ],
        ),
        content: SizedBox(
          width: 440,
          height: 350,
          child: ListView.builder(
            itemCount: tipos.length,
            itemBuilder: (_, index) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
                title: Text(tipos[index], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _openParametros(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text('Parámetros Generales de Costos'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Moneda Principal: Soles (S/.) / PEN', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• Moneda Secundaria: Dólares Americanos (\$) / USD', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• Jornada Laboral Estándar: 8.0 horas/día', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• Impuesto General a las Ventas (IGV): 18.00%', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• Fórmula Polinómica: Normativa D.S. N° 011-79-VC (Máx 8 monomios)', style: TextStyle(fontSize: 12)),
            SizedBox(height: 6),
            Text('• Motor de Base de Datos: SQLite Relacional + Room Offline', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
        ],
      ),
    );
  }

  void _openCostosUnitarios(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 0),
      ),
    );
  }

  void _openGruposCostos(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 1),
      ),
    );
  }

  void _openDiccionario(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diccionario Técnico de Presupuestos'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('• Metrado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Cuantificación física de la partida según planos de obra.', style: TextStyle(fontSize: 11)),
              SizedBox(height: 8),
              Text('• Rendimiento:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Cantidad de obra ejecutada por la cuadrilla en una jornada de 8 horas.', style: TextStyle(fontSize: 11)),
              SizedBox(height: 8),
              Text('• Aporte Unitario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Cantidad de insumo requerida por unidad de medida de la partida.', style: TextStyle(fontSize: 11)),
              SizedBox(height: 8),
              Text('• Costo Directo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Suma de los parciales de todas las partidas ejecutadas en obra.', style: TextStyle(fontSize: 11)),
              SizedBox(height: 8),
              Text('• Factor K:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Coeficiente de reajuste automático de valorizaciones por fórmula polinómica.', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _openProveedores(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storefront, color: Color(0xFFE8A800)),
            SizedBox(width: 8),
            Text('Directorio de Proveedores'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Aceros Arequipa S.A. | RUC: 20100138137 | Acero Corrugado', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('• UNACEM (Cemento Sol / Andino) | RUC: 20100132520 | Cemento', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('• Maestro / Sodimac Constructor | RUC: 20295675405 | Ferretería', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('• Ferreyros S.A. | RUC: 20100028692 | Maquinaria Caterpillar', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('• Pavco Wavin | RUC: 20100154680 | Tuberías y Conexiones', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _openEncabezados(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Los encabezados y logos se configuran en la pestaña Reportes (PDF / Excel)')),
    );
  }

  void _openPlantillas(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 4),
      ),
    );
  }

  String _getIuName(int iu) {
    const nombres = {
      1: 'Aceite', 2: 'Acero de construcción liso', 3: 'Acero de construcción corrugado',
      4: 'Agregado fino', 5: 'Agregado grueso', 6: 'Alambre y cable de cobre desnudo',
      7: 'Alambre y cable TW y THW', 8: 'Alcantarilla metálica', 9: 'Arena', 10: 'Asfalto',
      17: 'Bloque y ladrillo', 21: 'Cemento Portland tipo I', 27: 'Combustible (Petróleo D-2)',
      37: 'Herramienta manual', 39: 'Índice general de precios al consumidor (GG + Utilidad)',
      43: 'Madera nacional para encofrado', 47: 'Mano de obra inc. leyes sociales',
      48: 'Maquinaria y equipo nacional', 49: 'Maquinaria y equipo importado',
      69: 'Tubería de PVC para agua', 70: 'Tubería de PVC para desagüe', 78: 'Yeso',
    };
    return nombres[iu] ?? 'Índice Unificado ${iu.toString().padLeft(2, '0')}';
  }
}
