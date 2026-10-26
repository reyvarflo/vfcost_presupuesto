import 'package:flutter_test/flutter_test.dart';
import 'package:vfcost_presupuesto/utils/number_format_utils.dart';

void main() {
  group('NumberFormatUtils - Formato de Moneda Peruano', () {
    test('Formatea números mayores a un millón con apóstrofe y comas', () {
      expect(NumberFormatUtils.formatCurrency(1325125.25), equals("S/ 1'325,125.25"));
      expect(NumberFormatUtils.formatCurrency(21426672.57), equals("S/ 21'426,672.57"));
      expect(NumberFormatUtils.formatCurrency(1000000.00), equals("S/ 1'000,000.00"));
    });

    test('Formatea miles con comas', () {
      expect(NumberFormatUtils.formatCurrency(50006.26), equals("S/ 50,006.26"));
      expect(NumberFormatUtils.formatCurrency(12345.67), equals("S/ 12,345.67"));
      expect(NumberFormatUtils.formatCurrency(1000.00), equals("S/ 1,000.00"));
    });

    test('Formatea centenas y unidades', () {
      expect(NumberFormatUtils.formatCurrency(950.50), equals("S/ 950.50"));
      expect(NumberFormatUtils.formatCurrency(25.00), equals("S/ 25.00"));
      expect(NumberFormatUtils.formatCurrency(0.00), equals("S/ 0.00"));
    });

    test('Soporta símbolo personalizado', () {
      expect(NumberFormatUtils.formatCurrency(1325125.25, symbol: r'$'), equals(r"$ 1'325,125.25"));
      expect(NumberFormatUtils.formatNumber(1325125.25), equals("1'325,125.25"));
    });
  });

  group('NumberFormatUtils - Costo en Letras', () {
    test('Convierte 1325125.25 a letras legales peruanas', () {
      final letters = NumberFormatUtils.numberToWords(1325125.25);
      expect(
        letters,
        equals('SON: UN MILLÓN TRESCIENTOS VEINTICINCO MIL CIENTO VEINTICINCO Y 25/100 SOLES'),
      );
    });

    test('Convierte 50006.26 a letras legales peruanas', () {
      final letters = NumberFormatUtils.numberToWords(50006.26);
      expect(
        letters,
        equals('SON: CINCUENTA MIL SEIS Y 26/100 SOLES'),
      );
    });

    test('Convierte 21426672.57 a letras legales peruanas', () {
      final letters = NumberFormatUtils.numberToWords(21426672.57);
      expect(
        letters,
        equals('SON: VEINTIÚN MILLONES CUATROCIENTOS VEINTISÉIS MIL SEISCIENTOS SETENTA Y DOS Y 57/100 SOLES'),
      );
    });
  });
}
