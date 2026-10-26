import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../models/presupuesto.dart';
import '../models/subpresupuesto.dart';

class MsProjectExportService {
  static final _dateFormat = DateFormat("yyyy-MM-dd'T'08:00:00");
  static final _dateFinishFormat = DateFormat("yyyy-MM-dd'T'17:00:00");

  /// Genera un archivo XML de MS Project (.xml) a partir del presupuesto y subpresupuesto
  static Future<File?> exportMsProjectXml(Presupuesto p, Subpresupuesto sub, {bool share = true}) async {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');

    final startDate = p.date;
    var currentDate = startDate;

    builder.element('Project', attributes: {
      'xmlns': 'http://schemas.microsoft.com/project',
    }, nest: () {
      builder.element('Name', nest: '${p.code} - ${p.name}');
      builder.element('Title', nest: p.name);
      builder.element('Company', nest: p.client);
      builder.element('StartDate', nest: _dateFormat.format(startDate));
      builder.element('CurrencySymbol', nest: p.currencySymbol);
      builder.element('MinutesPerDay', nest: (p.jornada * 60).round().toString());
      builder.element('MinutesPerWeek', nest: (p.jornada * 60 * 6).round().toString());
      builder.element('DaysPerMonth', nest: '26');

      builder.element('Tasks', nest: () {
        int uid = 1;

        // Tarea Resumen del Proyecto completo
        builder.element('Task', nest: () {
          builder.element('UID', nest: uid.toString());
          builder.element('ID', nest: uid.toString());
          builder.element('Name', nest: '${p.name} - ${sub.name}');
          builder.element('Active', nest: '1');
          builder.element('Summary', nest: '1');
          builder.element('OutlineLevel', nest: '1');
          builder.element('OutlineNumber', nest: '0');
          builder.element('Start', nest: _dateFormat.format(startDate));
          builder.element('Cost', nest: sub.costoDirecto.toStringAsFixed(2));
        });
        uid++;

        for (final partida in sub.partidas) {
          final isTitle = partida.isTitle;
          final outlineLevel = (partida.itemNumber.split('.').length) + 1;

          // Cálculo de duración en días laborales (Metrado / Rendimiento)
          int duracionDias = 1;
          if (!isTitle && partida.rendimiento > 0 && partida.metrado > 0) {
            duracionDias = (partida.metrado / partida.rendimiento).ceil();
            if (duracionDias < 1) duracionDias = 1;
          }

          final taskStart = currentDate;
          final taskFinish = taskStart.add(Duration(days: isTitle ? 0 : duracionDias));
          if (!isTitle) {
            currentDate = taskFinish;
          }

          builder.element('Task', nest: () {
            builder.element('UID', nest: uid.toString());
            builder.element('ID', nest: uid.toString());
            builder.element('Name', nest: partida.description);
            builder.element('Active', nest: '1');
            builder.element('Summary', nest: isTitle ? '1' : '0');
            builder.element('OutlineLevel', nest: outlineLevel.toString());
            builder.element('OutlineNumber', nest: partida.itemNumber);
            builder.element('Start', nest: _dateFormat.format(taskStart));
            builder.element('Finish', nest: _dateFinishFormat.format(taskFinish));
            builder.element('Duration', nest: isTitle ? 'PT0H0M0S' : 'PT${duracionDias * p.jornada.round()}H0M0S');
            builder.element('Cost', nest: partida.costoParcial.toStringAsFixed(2));
            if (!isTitle) {
              builder.element('Work', nest: 'PT${duracionDias * p.jornada.round()}H0M0S');
            }
          });
          uid++;
        }
      });
    });

    final xmlDocument = builder.buildDocument();
    final xmlString = xmlDocument.toXmlString(pretty: true, indent: '  ');

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final sanitizedName = p.name.replaceAll(RegExp(r'[^\w\s-]'), '_').trim();
    final file = File('${tempDir.path}/${sanitizedName}_MSProject.xml');
    await file.writeAsString(xmlString);

    if (share) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/xml')],
        subject: 'Cronograma MS Project XML - ${p.name}',
      );
    }

    return file;
  }
}
