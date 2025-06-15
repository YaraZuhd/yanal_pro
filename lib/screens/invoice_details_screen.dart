import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class InvoiceDetailsScreen extends StatelessWidget {
  final String jsonInvoice;

  const InvoiceDetailsScreen({super.key, required this.jsonInvoice});

  @override
  Widget build(BuildContext context) {
    final invoice = jsonDecode(jsonInvoice);
    final customer = invoice['customer'] ?? invoice['name'] ?? 'غير معروف';
    final date = (invoice['timestamp'] ?? '').toString().split('T').first;
    final note = invoice['note'] ?? '';
    final items = List<Map<String, dynamic>>.from(invoice['items'] ?? []);

    double total = items.fold(0, (sum, item) {
      final qty = double.tryParse(item['qty'] ?? '0') ?? 0;
      final price = double.tryParse(item['price'] ?? '0') ?? 0;
      return sum + (qty * price);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الفاتورة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'تحميل كـ PDF',
            onPressed: () =>
                _downloadPdf(context, customer, date, note, items, total),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العميل: $customer', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('التاريخ: $date'),
            const SizedBox(height: 8),
            if (note.isNotEmpty) Text('ملاحظة: $note'),
            const Divider(height: 32),
            const Text('المنتجات:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ...items.map((item) {
              final qty = item['qty'];
              final price = item['price'];
              final total = (double.tryParse(qty) ?? 0) *
                  (double.tryParse(price) ?? 0);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['name'] ?? ''),
                subtitle: Text(
                    'الكمية: $qty × السعر: ₪$price = ₪${total.toStringAsFixed(2)}'),
              );
            }),
            const Divider(height: 32),
            Text('المجموع الكلي: ₪${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf(
    BuildContext context,
    String customer,
    String date,
    String note,
    List<Map<String, dynamic>> items,
    double total,
  ) async {
    final fontData =
        await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('العبهري ينال للتجارة والتوزيع - شعبان',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    )),
                pw.Text('فرخة - سلفيت', style: pw.TextStyle(font: ttf)),
                pw.Text('الهاتف: +972568499052',
                    style: pw.TextStyle(font: ttf)),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 16),
                pw.Text('فاتورة بيع',
                    style: pw.TextStyle(
                        font: ttf,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Text('العميل: $customer',
                    style: pw.TextStyle(font: ttf)),
                pw.Text('التاريخ: $date', style: pw.TextStyle(font: ttf)),
                if (note.isNotEmpty)
                  pw.Text('ملاحظة: $note', style: pw.TextStyle(font: ttf)),
                pw.SizedBox(height: 16),
                pw.Text('تفاصيل المنتجات:',
                    style: pw.TextStyle(fontSize: 16, font: ttf)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: ['المنتج', 'الكمية', 'السعر', 'المجموع'],
                  data: items.map((item) {
                    final qty =
                        double.tryParse(item['qty'] ?? '0') ?? 0;
                    final price =
                        double.tryParse(item['price'] ?? '0') ?? 0;
                    final subtotal = qty * price;
                    return [
                      item['name'] ?? '',
                      item['qty'],
                      '${price.toStringAsFixed(2)} شيكل',
                      '${subtotal.toStringAsFixed(2)} شيكل',
                    ];
                  }).toList(),
                  headerStyle:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf),
                  cellStyle: pw.TextStyle(font: ttf),
                  cellAlignment: pw.Alignment.center,
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                ),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('المجموع الكلي: ${total.toStringAsFixed(2)} شيكل',
                      style: pw.TextStyle(
                          font: ttf,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 40),
                pw.Text('توقيع:',
                    style: pw.TextStyle(fontSize: 14, font: ttf)),
                pw.SizedBox(height: 40),
                pw.Text('________________________'),
                pw.SizedBox(height: 40),
                pw.Text('المستلم:',
                    style: pw.TextStyle(fontSize: 14, font: ttf)),
                pw.SizedBox(height: 40),
                pw.Text('________________________'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'فاتورة $customer.pdf',
    );
  }
}
