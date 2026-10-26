import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/presupuesto_provider.dart';
import '../../services/delphin_excel_service.dart';
import '../../services/delphin_json_service.dart';
import '../../services/excel_export_service.dart';
import '../../services/ms_project_export_service.dart';
import '../../services/pdf_export_service.dart';

class ReportesTab extends StatelessWidget {
  const ReportesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;
    final activeSub = provider.activeSubpresupuesto;

    if (presupuesto == null || activeSub == null) {
      return const Center(child: Text('No hay presupuesto seleccionado'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // BANNER DESTACADO: IMPRIMIR TODOS LOS RESULTADOS EN UN SOLO EXPEDIENTE PDF
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.print_rounded, color: Colors.amberAccent, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Expediente Técnico Completo en un solo PDF',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Genera e imprime de una sola vez todos los resultados del proyecto: Hoja de Presupuesto, Pie Resumen, Análisis de Costos Unitarios (APUs), Relación de Insumos y Fórmula Polinómica.',
                style: TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade400,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text(
                    'IMPRIMIR TODOS LOS RESULTADOS EN PDF',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                  onPressed: () async {
                    await PdfExportService.printExpedienteCompletoPdf(presupuesto, activeSub);
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        const Text(
          'Impresión de Resultados Individuales en PDF (S10 / Delphin Express)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 1. Hoja de Presupuesto PDF
        _buildReportCard(
          context,
          icon: Icons.picture_as_pdf,
          iconColor: Colors.red.shade700,
          title: '1. Hoja de Presupuesto y Pie Resumen (PDF)',
          description:
              'Documento oficial con estructura jerárquica WBS/EDT, metrados, precios unitarios, subtotales y pie de presupuesto.',
          buttonLabel: 'Imprimir Presupuesto PDF',
          onAction: () async {
            await PdfExportService.printHojaPresupuesto(presupuesto, activeSub);
          },
        ),
        const SizedBox(height: 10),

        // 2. Reporte de APU PDF
        _buildReportCard(
          context,
          icon: Icons.analytics_outlined,
          iconColor: Colors.blue.shade700,
          title: '2. Análisis de Costos Unitarios - APUs (PDF)',
          description:
              'Desglose detallado de mano de obra, materiales (% desperdicio), equipos, cuadrillas, rendimientos y duración fija en formato PDF.',
          buttonLabel: 'Imprimir Dossier APUs PDF',
          onAction: () async {
            await PdfExportService.printApuReport(presupuesto, activeSub);
          },
        ),
        const SizedBox(height: 10),

        // 3. Relación Consolidada de Insumos PDF
        _buildReportCard(
          context,
          icon: Icons.inventory_2_outlined,
          iconColor: Colors.teal.shade700,
          title: '3. Relación Consolidada de Insumos por Rubro (PDF)',
          description:
              'Listado oficial agrupado por Mano de Obra, Materiales, Equipos y Subcontratos con Código, IU, Cantidad a 4 decimales, Precio y Parcial.',
          buttonLabel: 'Imprimir Insumos PDF',
          onAction: () async {
            await PdfExportService.printInsumosReport(presupuesto, activeSub);
          },
        ),
        const SizedBox(height: 10),

        // 4. Fórmula Polinómica y Coeficientes a 10 Decimales PDF
        _buildReportCard(
          context,
          icon: Icons.functions,
          iconColor: Colors.deepPurple.shade700,
          title: '4. Fórmula Polinómica y Coeficientes de Incidencia (PDF)',
          description:
              'Ecuación algebraica K₁, árbol de agrupamiento de monomios (Coef. Calculado a 10 decimales vs. Definido a 3 decimales) e incidencia INEI.',
          buttonLabel: 'Imprimir Fórmula Polinómica PDF',
          onAction: () async {
            await PdfExportService.printFormulaPolinomicaReport(presupuesto, activeSub);
          },
        ),
        const SizedBox(height: 10),

        // 5. Cronograma Valorizado y Resumen de Costos PDF
        _buildReportCard(
          context,
          icon: Icons.calendar_month_outlined,
          iconColor: Colors.indigo.shade700,
          title: '5. Calendario Valorizado de Obra y Resumen MO/MAT/EQ (PDF)',
          description:
              'Programación de obra, desglose de costos por rubro (Mano de Obra, Materiales, Equipos) y avance financiero mensual valorizado.',
          buttonLabel: 'Imprimir Cronograma PDF',
          onAction: () async {
            await PdfExportService.printCronogramaReport(presupuesto, activeSub);
          },
        ),
        const SizedBox(height: 10),

        // 6. Planilla de Metrados y Especificaciones Técnicas PDF
        _buildReportCard(
          context,
          icon: Icons.description_outlined,
          iconColor: Colors.brown.shade700,
          title: '6. Planilla de Metrados y Especificaciones Técnicas (PDF)',
          description:
              'Sustento detallado de dimensiones de metrados y pliego de especificaciones técnicas (Descripción, Método de medición y Bases de pago).',
          buttonLabel: 'Imprimir Metrados y Especif. PDF',
          onAction: () async {
            await PdfExportService.printMetradosYEspecificacionesReport(presupuesto, activeSub);
          },
        ),

        const SizedBox(height: 18),
        const Text(
          'Exportación Digital (Delphin Express .xlsx, MS Project .xml y JSON)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 7. Exportar Delphin Express (.xlsx con 4 hojas completas)
        _buildReportCard(
          context,
          icon: Icons.table_chart,
          iconColor: Colors.green.shade700,
          title: 'Exportar Delphin Express BIM 360 (.xlsx)',
          description:
              'Libro de Excel oficial con 4 hojas estructuradas: Hoja de Presupuesto (WBS/EDT), Análisis de Precios Unitarios (APU), Relación de Insumos y Fórmula Polinómica.',
          buttonLabel: 'Exportar Excel Completo (.xlsx)',
          onAction: () async {
            await DelphinExcelService.exportDelphinXlsx(presupuesto);
          },
        ),
        const SizedBox(height: 10),

        // 8. Exportar MS Project XML
        _buildReportCard(
          context,
          icon: Icons.account_tree_outlined,
          iconColor: Colors.blueGrey.shade700,
          title: 'Cronograma MS Project XML (ExportMsprj.xml)',
          description:
              'Archivo estándar de Microsoft Project con tareas, niveles de esquema, duraciones calculadas (Metrado / Rendimiento) y fechas.',
          buttonLabel: 'Exportar MS Project (.xml)',
          onAction: () async {
            await MsProjectExportService.exportMsProjectXml(presupuesto, activeSub);
          },
        ),
        const SizedBox(height: 10),

        // 9. Exportar Delphin Express JSON
        _buildReportCard(
          context,
          icon: Icons.data_object,
          iconColor: Colors.deepOrange.shade700,
          title: 'Exportar Proyecto Delphin (JSON)',
          description:
              'Archivo JSON estructurado con el catálogo completo de partidas, APUs, cuadrillas y recursos para intercambio con Delphin Express.',
          buttonLabel: 'Exportar Delphin JSON',
          onAction: () async {
            await DelphinJsonService.exportDelphinJson(presupuesto);
          },
        ),
        const SizedBox(height: 10),

        // 10. Exportar Insumos Consolidados CSV
        _buildReportCard(
          context,
          icon: Icons.list_alt,
          iconColor: Colors.orange.shade800,
          title: 'Listado Consolidado de Insumos (CSV)',
          description:
              'Resumen total de materiales, horas-hombre y maquinaria requerida para toda la obra.',
          buttonLabel: 'Exportar Lista de Insumos CSV',
          onAction: () async {
            final csv = ExcelExportService.generateResourcesCsv(presupuesto, activeSub);
            await ExcelExportService.shareCsvFile(
              csv,
              'Insumos_Obra_${presupuesto.code}.csv',
            );
          },
        ),
        const SizedBox(height: 10),

        // 11. Copia de Seguridad JSON interna
        _buildReportCard(
          context,
          icon: Icons.cloud_download_outlined,
          iconColor: Colors.purple.shade700,
          title: 'Respaldo del Proyecto (JSON Interno)',
          description:
              'Exporta o copia el texto de respaldo completo del presupuesto para guardarlo o compartirlo.',
          buttonLabel: 'Copiar JSON al Portapapeles',
          onAction: () {
            final jsonStr = provider.exportCurrentPresupuestoJson();
            Clipboard.setData(ClipboardData(text: jsonStr));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copia de respaldo copiada al portapapeles con éxito')),
            );
          },
        ),

        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
