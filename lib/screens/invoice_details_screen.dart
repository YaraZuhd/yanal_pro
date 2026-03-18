import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'thermal_printer_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final String jsonInvoice;

  const InvoiceDetailsScreen({super.key, required this.jsonInvoice});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  late Map<String, dynamic> invoice;
  late String customer;
  late String date;
  late String note;
  late List<Map<String, dynamic>> items;
  late double subtotal;
  late double discount;
  late double total;
  late String paymentStatus;

  @override
  void initState() {
    super.initState();
    _parseInvoice(widget.jsonInvoice);
  }

  void _parseInvoice(String json) {
    invoice = jsonDecode(json) as Map<String, dynamic>;
    customer = invoice['customer'] ?? invoice['name'] ?? 'غير معروف';
    date = (invoice['timestamp'] ?? '').toString().split('T').first;
    note = invoice['note'] ?? '';
    items = List<Map<String, dynamic>>.from(invoice['items'] ?? []);
    discount = double.tryParse(invoice['discount']?.toString() ?? '0') ?? 0;
    subtotal = items.fold(0, (sum, item) {
      final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      return sum + qty * price;
    });
    total = (subtotal - discount).clamp(0, double.infinity);
    paymentStatus = invoice['paymentStatus'] ?? 'unpaid';
  }

  Future<void> _updatePaymentStatus(String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('invoices') ?? [];

    final timestamp = invoice['timestamp']?.toString() ?? '';
    final invoiceNumber = invoice['invoiceNumber'];

    final updatedList = rawList.map((raw) {
      try {
        final inv = jsonDecode(raw) as Map<String, dynamic>;
        final matches = invoiceNumber != null
            ? inv['invoiceNumber'] == invoiceNumber
            : inv['timestamp']?.toString() == timestamp;
        if (matches) {
          inv['paymentStatus'] = newStatus;
          return jsonEncode(inv);
        }
      } catch (_) {}
      return raw;
    }).toList();

    await prefs.setStringList('invoices', updatedList);

    setState(() {
      paymentStatus = newStatus;
      invoice['paymentStatus'] = newStatus;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديث حالة الدفع إلى: ${_statusLabel(newStatus)}')),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'دفع جزئي';
      default:
        return 'غير مدفوع';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Future<void> _printThermal() async {
    try {
      final printer = BlueThermalPrinter.instance;
      final devices = await printer.getBondedDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد طابعات بلوتوث متصلة')),
        );
        return;
      }
      await ThermalPrinterService.printInvoice(invoice, devices.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في الطباعة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = invoice['invoiceNumber'];
    final statusColor = _statusColor(paymentStatus);

    return Scaffold(
      appBar: AppBar(
        title: Text(number != null ? 'فاتورة #$number' : 'تفاصيل الفاتورة'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'طباعة حرارية',
            onPressed: _printThermal,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'تحميل PDF',
            onPressed: () => _downloadPdf(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          customer,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          _statusLabel(paymentStatus),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(date, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.notes, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(note, style: const TextStyle(color: Colors.grey))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Payment status update
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تحديث حالة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statusButton('paid', 'مدفوع', Colors.green),
                      const SizedBox(width: 8),
                      _statusButton('partial', 'جزئي', Colors.orange),
                      const SizedBox(width: 8),
                      _statusButton('unpaid', 'غير مدفوع', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Items card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المنتجات:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Divider(),
                  ...items.map((item) {
                    final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
                    final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                    final lineTotal = qty * price;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              '${qty % 1 == 0 ? qty.toInt() : qty} × ₪${price.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₪${lineTotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الفرعي:'),
                      Text('₪${subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  if (discount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الخصم:', style: TextStyle(color: Colors.orange)),
                        Text('-₪${discount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الكلي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      Text(
                        '₪${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String value, String label, Color color) {
    final isSelected = paymentStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: isSelected ? null : () => _updatePaymentStatus(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: isSelected ? color : Colors.grey.shade600, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);

      final number = invoice['invoiceNumber'];
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Text(
                    'العبهري ينال للتجارة والتوزيع - شعبان',
                    style: pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('فرخة - سلفيت', style: pw.TextStyle(font: ttf)),
                  pw.Text('الهاتف: 0568499052', style: pw.TextStyle(font: ttf)),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 12),

                  // Title + number
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'فاتورة بيع',
                        style: pw.TextStyle(font: ttf, fontSize: 22, fontWeight: pw.FontWeight.bold),
                      ),
                      if (number != null)
                        pw.Text(
                          'رقم: #$number',
                          style: pw.TextStyle(font: ttf, fontSize: 14),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 12),

                  pw.Text('العميل: $customer', style: pw.TextStyle(font: ttf, fontSize: 13)),
                  pw.Text('التاريخ: $date', style: pw.TextStyle(font: ttf, fontSize: 13)),
                  pw.Text(
                    'حالة الدفع: ${_statusLabel(paymentStatus)}',
                    style: pw.TextStyle(font: ttf, fontSize: 13),
                  ),
                  if (note.isNotEmpty)
                    pw.Text('ملاحظة: $note', style: pw.TextStyle(font: ttf, fontSize: 12)),

                  pw.SizedBox(height: 16),

                  // Items table
                  pw.Table.fromTextArray(
                    headers: ['المنتج', 'الكمية', 'سعر الوحدة ₪', 'المجموع ₪'],
                    data: items.map((item) {
                      final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
                      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                      final lineTotal = qty * price;
                      return [
                        item['name'] ?? '',
                        qty % 1 == 0 ? qty.toInt().toString() : qty.toString(),
                        price.toStringAsFixed(2),
                        lineTotal.toStringAsFixed(2),
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf),
                    cellStyle: pw.TextStyle(font: ttf),
                    cellAlignment: pw.Alignment.center,
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  ),

                  pw.SizedBox(height: 8),

                  // Totals
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('المجموع الفرعي: ${subtotal.toStringAsFixed(2)} ₪',
                            style: pw.TextStyle(font: ttf)),
                        if (discount > 0)
                          pw.Text('الخصم: -${discount.toStringAsFixed(2)} ₪',
                              style: pw.TextStyle(font: ttf)),
                        pw.Divider(),
                        pw.Text(
                          'المجموع الكلي: ${total.toStringAsFixed(2)} ₪',
                          style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('توقيع البائع:', style: pw.TextStyle(font: ttf)),
                          pw.SizedBox(height: 30),
                          pw.Text('________________________'),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('توقيع المستلم:', style: pw.TextStyle(font: ttf)),
                          pw.SizedBox(height: 30),
                          pw.Text('________________________'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: number != null ? 'فاتورة_#$number.pdf' : 'فاتورة_$customer.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء PDF: $e')),
      );
    }
  }
}
