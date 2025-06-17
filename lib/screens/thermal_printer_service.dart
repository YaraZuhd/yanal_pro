import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class ThermalPrinterService {
  static Future<void> printInvoice(
    Map<String, dynamic> invoice,
    BluetoothDevice device,
  ) async {
    final printer = BlueThermalPrinter.instance;

    final customer = invoice['customer'] ?? invoice['name'] ?? 'غير معروف';
    final date = (invoice['timestamp'] ?? '').toString().split('T').first;
    final note = invoice['note'] ?? '';
    final items = List<Map<String, dynamic>>.from(invoice['items'] ?? []);

    double total = 0;
    final buffer = StringBuffer();

    // Header
    buffer.writeln("==============================");
    buffer.writeln("  العبهري ينال للتجارة والتوزيع");
    buffer.writeln("          - شعبان -");
    buffer.writeln("        فرخة - سلفيت");
    buffer.writeln("     الهاتف: 0568499052");
    buffer.writeln("==============================\n");

    // Title
    buffer.writeln("         فاتورة بيع         ");
    buffer.writeln("------------------------------\n");

    // Customer Info
    buffer.writeln("العميل: $customer");
    buffer.writeln("التاريخ: $date");
    if (note.isNotEmpty) buffer.writeln("ملاحظة: $note");
    buffer.writeln("\n------------------------------\n");

    // Table Header
    buffer.writeln("المنتج        ك×سعر    المجموع");
    buffer.writeln("------------------------------");

    for (var item in items) {
      final name = item['name'] ?? '';
      final qty = double.tryParse(item['qty'] ?? '0') ?? 0;
      final price = double.tryParse(item['price'] ?? '0') ?? 0;
      final subtotal = qty * price;
      total += subtotal;

      final qtyPrice = "${qty.toInt()}×${price.toStringAsFixed(2)}";
      final lineTotal = subtotal.toStringAsFixed(2);
      buffer.writeln(
        "${_padRight(name, 12)} ${_padRight(qtyPrice, 7)} ${_padLeft(lineTotal, 7)}"
      );
    }

    buffer.writeln("\n------------------------------\n");
    buffer.writeln("المجموع الكلي: ${total.toStringAsFixed(2)} شيكل");
    buffer.writeln("\n==============================\n");
    buffer.writeln("توقيع: ________________\n");
    buffer.writeln("المستلم: ______________\n");

    // Print it
    await printer.connect(device);
    printer.printCustom(buffer.toString(), 1, 1);
    printer.printNewLine();
    printer.paperCut();
  }

  static String _padRight(String text, int width) {
    return text.padRight(width).substring(0, width);
  }

  static String _padLeft(String text, int width) {
    return text.padLeft(width).substring(0, width);
  }
} 
