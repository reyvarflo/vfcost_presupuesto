import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  print('Iniciando generación de PDF del Manual de Usuario VF COST Pro...');

  final doc = pw.Document(
    title: 'Manual de Usuario - VF COST Pro',
    author: 'VARFLO Ingeniería y Construcción',
  );

  // Cargar logo si existe
  pw.MemoryImage? logoImage;
  final logoFile = File('assets/images/logo.png');
  if (await logoFile.exists()) {
    final bytes = await logoFile.readAsBytes();
    logoImage = pw.MemoryImage(bytes);
  }

  const azulVarflo = PdfColor.fromInt(0xFF0F2B48);
  const naranjaVarflo = PdfColor.fromInt(0xFFFF6D00);
  const grisFondo = PdfColor.fromInt(0xFFF1F5F9);
  const grisTexto = PdfColor.fromInt(0xFF334155);

  // --- PÁGINA 1: PORTADA ELEGANTE ---
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Container(
          color: PdfColors.white,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Franja superior azul corporativo
              pw.Container(
                height: 280,
                color: azulVarflo,
                padding: const pw.EdgeInsets.all(36),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 65,
                            height: 65,
                            decoration: const pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: PdfColors.white,
                            ),
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Image(logoImage),
                          )
                        else
                          pw.Container(
                            width: 50,
                            height: 50,
                            color: naranjaVarflo,
                            child: pw.Center(
                              child: pw.Text('VF', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                            ),
                          ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: naranjaVarflo,
                            borderRadius: pw.BorderRadius.circular(16),
                          ),
                          child: pw.Text(
                            'VERSIÓN 2.0.0 RELEASE',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MANUAL DE USUARIO OFICIAL',
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'VF COST PRO — S10 & DELPHIN EXPRESS BIM 360',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFFFFB300),
                            letterSpacing: 0.3,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Guía Completa de Ingeniería de Costos, APUs, Presupuestos y Control de Obras',
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey300),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Barra intermedia naranja Varflo
              pw.Container(
                height: 6,
                color: naranjaVarflo,
              ),

              // Cuerpo de portada con datos y resumen
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(36),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ESTÁNDAR NORMATIVO APLICADO',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azulVarflo),
                          ),
                          pw.SizedBox(height: 8),
                          _bulletItemCover('Contraloría General de la República del Perú (R.C. N° 196-2020-CG)'),
                          _bulletItemCover('Organismo Supervisor de las Contrataciones del Estado (OSCE)'),
                          _bulletItemCover('Decreto Supremo N° 011-79-VC (Fórmulas Polinómicas y Coeficientes K)'),
                          _bulletItemCover('Ministerio de Transportes y Comunicaciones (MTC) & Delphin Express BIM'),
                          pw.SizedBox(height: 18),
                          pw.Text(
                            'FORMATO TÉCNICO PERUANO EXCLUSIVO',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azulVarflo),
                          ),
                          pw.SizedBox(height: 8),
                          _bulletItemCover('Apóstrofe para millones y comas para miles: S/ 1\'325,125.25'),
                          _bulletItemCover('Conversión automática a glosa legal en letras (SON: ... Y XX/100 SOLES)'),
                          _bulletItemCover('Sincronización en la Nube: Google Drive, Descargas locales y Webhooks'),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: grisFondo,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Desarrollado para:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('VARFLO INGENIERÍA & CONSTRUCCIÓN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: azulVarflo)),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text('Fecha de Emisión:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                pw.Text('26 de Octubre de 2026', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: azulVarflo)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  // --- CONTENIDO DEL MANUAL (MULTI-PAGE) ---
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
      header: (context) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 16),
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: azulVarflo, width: 1.2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VF COST PRO — MANUAL DE USUARIO OFICIAL',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: azulVarflo),
              ),
              pw.Text(
                'S10 & Delphin Express BIM 360',
                style: const pw.TextStyle(fontSize: 8.5, color: naranjaVarflo),
              ),
            ],
          ),
        );
      },
      footer: (context) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(top: 14),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VARFLO INGENIERÍA • Documento Oficial de Operación',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: azulVarflo),
              ),
            ],
          ),
        );
      },
      build: (context) {
        return [
          // CAPÍTULO 1
          _sectionHeader('1. PRESENTACIÓN E IDENTIDAD DE VF COST PRO', azulVarflo),
          _paragraph(
            'VF COST Pro es una suite técnica integral desarrollada para teléfonos inteligentes y tablets Android, orientada a ingenieros civiles, consultores, residentes y supervisores de obras en el Perú. Permite estructurar, calcular y auditar presupuestos de obra civil con el mismo rigor matemático y normativo de S10 Presupuestos y Delphin Express BIM 360.',
          ),
          _calloutBox(
            'FORMATO NUMÉRICO EXCLUSIVO Y GLOSA LEGAL PERUANA',
            '• Apóstrofe de millones: Números a partir de 1 millón utilizan apóstrofe para millones y comas para miles (ejemplo: S/ 1\'325,125.25 o S/ 21\'426,672.57).\n'
            '• Glosa en letras automática: Toda tarjeta y liquidación genera la transcripción legal (ejemplo: "SON: UN MILLÓN TRESCIENTOS VEINTICINCO MIL CIENTO VEINTICINCO Y 25/100 SOLES").\n'
            '• Paleta Corporativa Varflo: Azul Marino (#0F2B48), Naranja Construcción (#FF6D00) y Gris Pizarra (#F1F5F9).',
            naranjaVarflo,
          ),
          pw.SizedBox(height: 12),

          // CAPÍTULO 2
          _sectionHeader('2. INSTALACIÓN DEL ARCHIVO APK EN ANDROID', azulVarflo),
          _paragraph(
            'El instalable oficial se encuentra compilado en la raíz del proyecto con el nombre VFCOST_Pro_Release.apk (61.1 MB). Para instalarlo:',
          ),
          _numberedStep('1', 'Copie el archivo VFCOST_Pro_Release.apk a su celular mediante cable USB, WhatsApp Web o Google Drive.'),
          _numberedStep('2', 'Abra la carpeta "Descargas" de su dispositivo y toque el archivo APK.'),
          _numberedStep('3', 'Si el sistema solicita permisos, pulse "Configuración" y active "Confiar en esta fuente".'),
          _numberedStep('4', 'Toque "Instalar". Al finalizar, pulse "Abrir" para iniciar la suite.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 3
          _sectionHeader('3. PANTALLA PRINCIPAL Y PORTAFOLIO DE OBRAS', azulVarflo),
          _paragraph(
            'La pantalla de inicio centraliza todos los proyectos con controles rápidos de productividad:',
          ),
          _bulletPoint('Barra de Búsqueda Dinámica: Permite filtrar al instante por código (ej. 0101001), nombre o cliente.'),
          _bulletPoint('Filtro por Especialidades: Píldoras interactivas con conteo (Edificaciones, Obras Viales, Saneamiento, etc.).'),
          _bulletPoint('Candado de Seguridad Delphin: Ícono en cada tarjeta para bloquear la obra en "Solo Lectura", protegiendo los metrados de modificaciones involuntarias.'),
          _bulletPoint('Menú Contextual (⋮): Permite duplicar presupuestos, exportar respaldos JSON, subir a Google Drive o eliminar.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 4
          _sectionHeader('4. CREACIÓN DE UN NUEVO PRESUPUESTO', azulVarflo),
          _paragraph(
            'Para iniciar un presupuesto desde cero, toque el botón flotante "+ Nuevo Presupuesto" en la esquina inferior derecha y complete los siguientes datos:',
          ),
          _bulletPoint('Código del Proyecto: Autonumerado correlativo (ej. 0101008).'),
          _bulletPoint('Nombre de la Obra: Denominación oficial del proyecto según términos de referencia.'),
          _bulletPoint('Cliente / Entidad: Municipalidad, Gobierno Regional, Ministerio o Cliente Privado.'),
          _bulletPoint('Ubicación: Departamento - Provincia - Distrito.'),
          _bulletPoint('Jornada y Plazo: 8.00 horas estándar y plazo de ejecución en días calendario.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 5
          _sectionHeader('5. IMPORTACIÓN DE BASES DE DATOS (DELPHIN .SQLITE / EXCEL / S10)', azulVarflo),
          _paragraph(
            'VF COST Pro cuenta con módulos de importación universal para reutilizar bancos de datos existentes sin volver a digitar:',
          ),
          _subHeader('A. Importación Directa desde SQLite de Delphin Express (.sqlite):'),
          _paragraph('Abra el menú principal (⋮) -> "Importar Delphin (.xlsx / .sqlite)" -> pestaña "Base de Datos SQLite". Seleccione su base de datos Delphin nativa y el sistema cargará automáticamente todas las partidas, insumos, cuadrillas y precios históricos.'),
          _subHeader('B. Importación desde Planillas Excel (.xlsx):'),
          _paragraph('Importa partidas estructuradas en hojas de cálculo con columnas: Item, Descripción, Unidad, Metrado, Precio Unitario y Parcial.'),
          _subHeader('C. Importación de Respaldos S10 (.S2K / .json):'),
          _paragraph('Reconstruye presupuestos completos a partir de backups estándar de S10.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 6
          _sectionHeader('6. SUBPRESUPUESTOS Y VISTA DIVIDIDA (SPLIT SCREEN BIM 360)', azulVarflo),
          _paragraph(
            'Todo proyecto se organiza en subpresupuestos (Estructuras, Arquitectura, Sanitarias, Eléctricas). Para agregar un subpresupuesto, presione el chip "+ Subpresupuesto" en la barra horizontal superior.',
          ),
          _paragraph(
            'Modo Doble Panel (Split View Delphin): Al presionar el icono de vista dividida en la barra superior, la pantalla muestra en simultáneo el árbol de partidas arriba y los insumos del APU con el gráfico de barras de incidencia abajo, permitiendo editar rendimientos y ver el impacto en tiempo real.',
          ),
          pw.SizedBox(height: 12),

          // CAPÍTULO 7
          _sectionHeader('7. GESTIÓN DE PARTIDAS, TÍTULOS Y METRADOS', azulVarflo),
          _paragraph('El árbol WBS distingue dos tipos de elementos:'),
          _bulletPoint('Títulos (Nivel 1, 2, 3...): Ítems de agrupación sombreados. Tocar su flecha (⌄ / ›) expande o contrae todas sus partidas hijas.'),
          _bulletPoint('Partidas con APU: Ítems ejecutables con unidad, metrado y precio unitario. Se identifican con una flecha verde hacia arriba (↑).'),
          _bulletPoint('Especificaciones Técnicas ([A]): Ficha redactada con descripción, método de medición y forma de pago lista para licitaciones.'),
          _bulletPoint('Planilla de Metrado de Fierro: Cálculo de acero clasificado por diámetro (1/4" a 1") con conversión directa a kilogramos.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 8
          _sectionHeader('8. ANÁLISIS DE PRECIOS UNITARIOS (APUs)', azulVarflo),
          _paragraph(
            'Al pulsar sobre cualquier partida o su flecha verde (↑), se abre el Editor de Costos Unitarios con sus 4 grupos normativos:',
          ),
          _bulletPoint('Mano de Obra: Cuadrilla calculada con la fórmula oficial: Cantidad = (Cuadrilla * Jornada) / Rendimiento.'),
          _bulletPoint('Materiales: Cantidad por unidad con porcentaje de desperdicio editable (% Desp.).'),
          _bulletPoint('Equipos y Herramientas: Maquinaria por cuadrilla y herramientas manuales (% MO, típicamente 3% o 5%).'),
          _bulletPoint('Subcontratos: Servicios tercerizados o especializados.'),
          _bulletPoint('Duración Fija Programada: Caja técnica que muestra los días de duración exacta para ejecutar el metrado según el rendimiento.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 9
          _sectionHeader('9. PIE DE PRESUPUESTO Y LIQUIDACIÓN ECONÓMICA', azulVarflo),
          _paragraph(
            'En la pestaña "Pie / GG" se liquidan los costos indirectos de la obra:',
          ),
          _bulletPoint('Gastos Generales Fijos (GGF): Gastos de licitación, fianzas y seguros (ej. 2.5%).'),
          _bulletPoint('Gastos Generales Variables (GGV): Supervisión, residencia y camionetas por tiempo de obra (ej. 8.0%).'),
          _bulletPoint('Utilidad: Margen empresarial del contratista (ej. 5% a 10%).'),
          _bulletPoint('I.G.V. (18%): Impuesto general a las ventas con selector de aplicación.'),
          _bulletPoint('Presupuesto Total: Importe final en soles y glosa legal en letras con gráfico de torta de distribución del gasto.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 10
          _sectionHeader('10. INCIDENCIA DE COSTOS Y FÓRMULA POLINÓMICA (D.S. 011-79-VC)', azulVarflo),
          _paragraph(
            'VF COST Pro calcula la fórmula polinómica de reajuste agrupando todos los insumos por su Índice Unificado INEI (IU 47 Mano de obra, IU 21 Cemento, IU 02 Acero, etc.):',
          ),
          _calloutBox(
            'CONDICIÓN DE CIERRE MATEMÁTICO',
            'El sistema valida estrictamente que la sumatoria de coeficientes de incidencia sea igual a la unidad (∑ K = 1.000) calculada a 10 decimales de precisión, garantizando que el expediente no sea observado por OSCE o Contraloría.',
            azulVarflo,
          ),
          pw.SizedBox(height: 12),

          // CAPÍTULO 11
          _sectionHeader('11. RESPALDO Y SINCRONIZACIÓN EN GOOGLE DRIVE', azulVarflo),
          _paragraph(
            'Para asegurar que sus proyectos nunca se pierdan, la pantalla "Google Drive & Respaldo en la Red" ofrece 3 formas garantizadas de guardado:',
          ),
          _numberedStep('Opción 1', 'Elegir carpeta en Google Drive (Recomendado): Abre el selector oficial del sistema (SAF). En el panel izquierdo elija "Google Drive" -> "Mi unidad" para guardar el archivo .json directo en su nube.'),
          _numberedStep('Opción 2', 'Guardar en Descargas del teléfono: Guarda una copia local en /storage/emulated/0/Download/ para acceso inmediato sin internet.'),
          _numberedStep('Opción 3', 'Subir con la App Google Drive: Abre el menú de compartir nativo de Android seleccionando "Guardar en Drive".'),
          _numberedStep('Restaurar', 'Toque "Restaurar de Drive", seleccione el archivo y elija si desea añadir o sobrescribir proyectos.'),
          pw.SizedBox(height: 12),

          // CAPÍTULO 12
          _sectionHeader('12. GENERACIÓN DE EXPEDIENTES TÉCNICOS EN PDF Y EXCEL', azulVarflo),
          _paragraph(
            'Toque el icono de PDF en la barra superior del proyecto para emitir los documentos oficiales listos para firma y trámite:',
          ),
          _tableHeaderRow(['Reporte Técnico', 'Contenido y Alcance', 'Uso Oficial']),
          _tableDataRow(['Expediente Completo', 'Hoja de presupuesto, APUs, insumos y fórmula polinómica encuadernados.', 'Licitaciones y Contraloría']),
          _tableDataRow(['Hoja de Presupuesto', 'Títulos, partidas, metrados, precios unitarios y liquidación al pie.', 'Resumen ejecutivo de obra']),
          _tableDataRow(['Análisis de Costos (APUs)', 'Desglose analítico de cada partida con aportes unitarios y cuadrillas.', 'Sustento técnico de precios']),
          _tableDataRow(['Relación de Insumos', 'Consolidado general de recursos agrupados por Mano de obra, Materiales y Equipos.', 'Cotizaciones y compras']),
          _tableDataRow(['Fórmula Polinómica', 'Monomios de reajuste con coeficientes de incidencia y factores K.', 'Valorizaciones de obra']),
          _tableDataRow(['Exportación Excel (.xlsx)', 'Planilla de 4 pestañas idéntica a Delphin Express para trabajo en PC.', 'Edición en computadora']),
          _tableDataRow(['Exportación MS Project (.xml)', 'Cronograma con tareas WBS y duraciones para diagrama de GANTT.', 'Control de ruta crítica CPM']),
          pw.SizedBox(height: 12),

          // CAPÍTULO 13
          _sectionHeader('13. PREGUNTAS FRECUENTES (FAQ) Y BUENAS PRÁCTICAS', azulVarflo),
          _subHeader('• ¿Qué hago si cambio rendimientos y el costo total no se actualiza?'),
          _paragraph('Presione el botón "PROCESAR" (equivalente al F9 de S10 / Delphin) en la barra superior derecha para recalcular en cascada toda la obra.'),
          _subHeader('• ¿La aplicación requiere conexión a internet para trabajar en obra?'),
          _paragraph('No. Todo el motor de cálculo, SQLite y generación de PDFs funciona 100% offline sin señal celular.'),
          _subHeader('• ¿Cómo traspaso mis proyectos a otro celular o tablet?'),
          _paragraph('En el primer equipo pulse "Guardar en Drive". En el nuevo equipo instale el APK, abra la pantalla de Google Drive y toque "Restaurar de Drive".'),
        ];
      },
    ),
  );

  // Guardar archivo PDF en la raíz del proyecto
  final outputFile = File('H:/APP PRESUPUESTO VFCOST/MANUAL_DE_USO_VFCOST_PRO.pdf');
  await outputFile.writeAsBytes(await doc.save());

  print('¡PDF generado exitosamente!');
  print('Ruta: ${outputFile.path}');
  print('Tamaño: ${(await outputFile.length()) / 1024} KB');
  print('Páginas generadas: ${doc.document.pdfPageList.pages.length}');
}

// --- WIDGETS AUXILIARES PARA EL PDF ---

pw.Widget _sectionHeader(String title, PdfColor color) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 10.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );
}

pw.Widget _subHeader(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF0F2B48),
      ),
    ),
  );
}

pw.Widget _paragraph(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.justify,
      style: const pw.TextStyle(
        fontSize: 8.5,
        lineSpacing: 1.25,
        color: PdfColor.fromInt(0xFF334155),
      ),
    ),
  );
}

pw.Widget _bulletPoint(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('• ', style: pw.TextStyle(color: const PdfColor.fromInt(0xFFFF6D00), fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Expanded(
          child: pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF334155), lineSpacing: 1.2),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _numberedStep(String number, String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 6, bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 18,
          height: 18,
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF0F2B48),
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(number, style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF334155), lineSpacing: 1.2),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _calloutBox(String title, String content, PdfColor borderColor) {
  return pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 6),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF8FAFC),
      border: pw.Border(left: pw.BorderSide(color: borderColor, width: 3.5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F2B48)),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          content,
          style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF475569), lineSpacing: 1.2),
        ),
      ],
    ),
  );
}

pw.Widget _bulletItemCover(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.Container(width: 5, height: 5, color: const PdfColor.fromInt(0xFFFF6D00)),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5, color: PdfColor.fromInt(0xFF1E293B))),
        ),
      ],
    ),
  );
}

pw.Widget _tableHeaderRow(List<String> columns) {
  return pw.Container(
    color: const PdfColor.fromInt(0xFF0F2B48),
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 3, child: pw.Text(columns[0], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
        pw.Expanded(flex: 5, child: pw.Text(columns[1], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
        pw.Expanded(flex: 3, child: pw.Text(columns[2], style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
      ],
    ),
  );
}

pw.Widget _tableDataRow(List<String> columns) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 3, child: pw.Text(columns[0], style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F2B48)))),
        pw.Expanded(flex: 5, child: pw.Text(columns[1], style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800))),
        pw.Expanded(flex: 3, child: pw.Text(columns[2], style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700))),
      ],
    ),
  );
}
