import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class ThermalPrintScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const ThermalPrintScreen({super.key, required this.invoice});

  @override
  State<ThermalPrintScreen> createState() => _ThermalPrintScreenState();
}

class _ThermalPrintScreenState extends State<ThermalPrintScreen> {
  final bool simulatePrint = true; // ✅ للتجريب بدون طابعة
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;

  @override
  void initState() {
    super.initState();
    if (!simulatePrint) {
      _getDevices();
    }
  }

  void _getDevices() async {
    final availableDevices = await printer.getBondedDevices();
    setState(() {
      devices = availableDevices;
    });
  }

  void _connectAndPrint() async {
    final invoice = widget.invoice;
    final customer = invoice['customer'] ?? invoice['name'] ?? 'غير معروف';
    final date = (invoice['timestamp'] ?? '').toString().split('T').first;
    final note = invoice['note'] ?? '';
    final items = List<Map<String, dynamic>>.from(invoice['items'] ?? []);

    double total = 0;
    final buffer = StringBuffer();

    buffer.writeln("العبهري ينال للتجارة والتوزيع - شعبان");
    buffer.writeln("فرخة - سلفيت");
    buffer.writeln("الهاتف: 0568499052");
    buffer.writeln("=" * 32);
    buffer.writeln("         فاتورة بيع         ");
    buffer.writeln("=" * 32);
    buffer.writeln("العميل: $customer");
    buffer.writeln("التاريخ: $date");
    if (note.isNotEmpty) buffer.writeln("ملاحظة: $note");
    buffer.writeln("-" * 32);
    buffer.writeln("المنتج        ك×سعر   المجموع");
    buffer.writeln("-" * 32);

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

    buffer.writeln("-" * 32);
    buffer.writeln("المجموع الكلي: ${total.toStringAsFixed(2)} شيكل");
    buffer.writeln("=" * 32);
    buffer.writeln("توقيع: ________________");
    buffer.writeln("المستلم: ______________");

    if (simulatePrint) {
      _showDialog(context, buffer.toString());
    } else {
      if (selectedDevice == null) return;
      await printer.connect(selectedDevice!);
      printer.printCustom(buffer.toString(), 1, 1);
      printer.printNewLine();
      printer.paperCut();
    }
  }

  void _showDialog(BuildContext context, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('معاينة الفاتورة'),
        content: SingleChildScrollView(
          child: Text(content, textDirection: TextDirection.rtl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _padRight(String text, int width) {
    return text.padRight(width).substring(0, width);
  }

  String _padLeft(String text, int width) {
    return text.padLeft(width).substring(0, width);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طباعة حرارية')),
      body: Column(
        children: [
          if (!simulatePrint) ...[
            const SizedBox(height: 16),
            const Text('اختر طابعة متصلة عبر البلوتوث:'),
            ...devices.map((device) {
              return RadioListTile<BluetoothDevice>(
                title: Text(device.name ?? ''),
                value: device,
                groupValue: selectedDevice,
                onChanged: (val) => setState(() => selectedDevice = val),
              );
            }).toList(),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _connectAndPrint,
            child: Text(simulatePrint ? 'معاينة الفاتورة' : 'طباعة الفاتورة'),
          ),
        ],
      ),
    );
  }
}
