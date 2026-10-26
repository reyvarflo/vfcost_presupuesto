/// Utilidades para formateo numérico de ingeniería civil y costos en Perú (S10 / Delphin Express / Varflo)
class NumberFormatUtils {
  /// Formatea un monto con apóstrofe (') para millones y comas (,) para miles, punto (.) para decimales.
  /// Ejemplo: 1325125.25 -> "S/ 1'325,125.25"
  /// Ejemplo: 21426672.57 -> "S/ 21'426,672.57"
  /// Ejemplo: 50006.26 -> "S/ 50,006.26"
  /// Ejemplo: 950.50 -> "S/ 950.50"
  static String formatCurrency(
    double amount, {
    String symbol = 'S/',
    int decimalDigits = 2,
  }) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final parts = absAmount.toStringAsFixed(decimalDigits).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';

    final formattedInt = _formatIntWithApostropheAndCommas(intPart);
    final sign = isNegative ? '-' : '';
    final prefix = symbol.isNotEmpty ? '$symbol ' : '';

    return '$sign$prefix$formattedInt.$decPart';
  }

  /// Formatea solo el número sin símbolo de moneda
  static String formatNumber(double amount, {int decimalDigits = 2}) {
    return formatCurrency(amount, symbol: '', decimalDigits: decimalDigits).trim();
  }

  /// Agrega apóstrofe para millones y comas para miles.
  /// Si el número es 1325125 -> "1'325,125"
  /// Si el número es 21426672 -> "21'426,672"
  /// Si el número es 50006 -> "50,006"
  /// Si el número es 950 -> "950"
  static String _formatIntWithApostropheAndCommas(String intStr) {
    if (intStr.length <= 3) return intStr;

    // Invertir para agrupar de 3 en 3 de derecha a izquierda
    final reversed = intStr.split('').reversed.toList();
    final chunks = <String>[];

    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;
      final chunk = reversed.sublist(i, end).reversed.join('');
      chunks.insert(0, chunk);
    }

    if (chunks.length <= 1) return chunks.join('');
    if (chunks.length == 2) {
      // Miles: "50,006"
      return chunks.join(',');
    }

    // Millones o más (chunks.length >= 3):
    // chunks[chunks.length - 1] = unidades
    // chunks[chunks.length - 2] = miles
    // chunks[chunks.length - 3] = millones
    // Separador entre millones y miles es ' (apóstrofe)
    // Separador entre miles y unidades es , (coma)
    final buffer = StringBuffer();
    for (int i = 0; i < chunks.length; i++) {
      buffer.write(chunks[i]);
      if (i < chunks.length - 1) {
        final posFromRight = chunks.length - 1 - i; // 2 para millones, 1 para miles
        if (posFromRight == 2) {
          buffer.write("'"); // Apóstrofe de millones
        } else if (posFromRight == 4) {
          buffer.write("'"); // Apóstrofe de billones
        } else {
          buffer.write(','); // Coma para miles u otros
        }
      }
    }
    return buffer.toString();
  }

  /// Convierte un monto numérico a texto legal en letras (Estándar de Presupuestos Peruanos / Contraloría / S10)
  /// Ejemplo: 1325125.25 -> "SON: UN MILLÓN TRESCIENTOS VEINTICINCO MIL CIENTO VEINTICINCO Y 25/100 SOLES"
  static String numberToWords(double amount, {String currency = 'SOLES'}) {
    final absAmount = amount.abs();
    final intPart = absAmount.truncate();
    final cents = ((absAmount - intPart) * 100).round();
    final centsStr = cents.toString().padLeft(2, '0');

    final words = _convertIntegerToWords(intPart).trim();
    final currencyName = currency.toUpperCase();

    if (amount < 0) {
      return 'SON: MENOS $words Y $centsStr/100 $currencyName';
    }
    return 'SON: $words Y $centsStr/100 $currencyName';
  }

  static String _convertIntegerToWords(int n) {
    if (n == 0) return 'CERO';

    if (n >= 1000000000000) {
      final bill = n ~/ 1000000000000;
      final rest = n % 1000000000000;
      final bWord = bill == 1 ? 'UN BILLÓN' : '${_adjustApocope(_convertIntegerToWords(bill))} BILLONES';
      return rest == 0 ? bWord : '$bWord ${_convertIntegerToWords(rest)}';
    }

    if (n >= 1000000) {
      final mill = n ~/ 1000000;
      final rest = n % 1000000;
      final mWord = mill == 1 ? 'UN MILLÓN' : '${_adjustApocope(_convertIntegerToWords(mill))} MILLONES';
      return rest == 0 ? mWord : '$mWord ${_convertIntegerToWords(rest)}';
    }

    if (n >= 1000) {
      final miles = n ~/ 1000;
      final rest = n % 1000;
      final mWord = miles == 1 ? 'MIL' : '${_adjustApocope(_convertIntegerToWords(miles))} MIL';
      return rest == 0 ? mWord : '$mWord ${_convertIntegerToWords(rest)}';
    }

    if (n >= 100) {
      final cent = n ~/ 100;
      final rest = n % 100;
      if (n == 100) return 'CIEN';
      const centenas = [
        '',
        'CIENTO',
        'DOSCIENTOS',
        'TRESCIENTOS',
        'CUATROCIENTOS',
        'QUINIENTOS',
        'SEISCIENTOS',
        'SETECIENTOS',
        'OCHOCIENTOS',
        'NOVECIENTOS'
      ];
      return rest == 0 ? centenas[cent] : '${centenas[cent]} ${_convertIntegerToWords(rest)}';
    }

    if (n >= 30) {
      final dec = n ~/ 10;
      final rest = n % 10;
      const decenas = [
        '',
        '',
        '',
        'TREINTA',
        'CUARENTA',
        'CINCUENTA',
        'SESENTA',
        'SETENTA',
        'OCHENTA',
        'NOVENTA'
      ];
      return rest == 0 ? decenas[dec] : '${decenas[dec]} Y ${_convertIntegerToWords(rest)}';
    }

    if (n >= 20) {
      if (n == 20) return 'VEINTE';
      const veintis = [
        'VEINTIUNO',
        'VEINTIDÓS',
        'VEINTITRÉS',
        'VEINTICUATRO',
        'VEINTICINCO',
        'VEINTISÉIS',
        'VEINTISIETE',
        'VEINTIOCHO',
        'VEINTINUEVE'
      ];
      return veintis[n - 21];
    }

    if (n >= 10) {
      const dieces = [
        'DIEZ',
        'ONCE',
        'DOCE',
        'TRECE',
        'CATORCE',
        'QUINCE',
        'DIECISÉIS',
        'DIECISIETE',
        'DIECIOCHO',
        'DIECINUEVE'
      ];
      return dieces[n - 10];
    }

    const unidades = [
      '',
      'UN',
      'DOS',
      'TRES',
      'CUATRO',
      'CINCO',
      'SEIS',
      'SIETE',
      'OCHO',
      'NUEVE'
    ];
    return unidades[n];
  }

  /// Ajusta apócopes como "VEINTIUNO" -> "VEINTIÚN" o "Y UNO" -> "Y UN" antes de sustantivos como MIL o MILLONES
  static String _adjustApocope(String text) {
    if (text.endsWith('VEINTIUNO')) {
      return '${text.substring(0, text.length - 9)}VEINTIÚN';
    }
    if (text.endsWith('Y UNO')) {
      return '${text.substring(0, text.length - 5)}Y UN';
    }
    if (text == 'UNO') {
      return 'UN';
    }
    return text;
  }
}
