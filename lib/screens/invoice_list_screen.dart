import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'invoice_details_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<String> rawInvoices = [];
  List<String> filteredInvoices = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadInvoices() {
    final stored = html.window.localStorage['invoices'];
    if (stored != null) {
      try {
        rawInvoices = List<String>.from(jsonDecode(stored));
      } catch (_) {
        rawInvoices = [];
      }
    }
    filteredInvoices = List.from(rawInvoices);
    setState(() {});
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    filteredInvoices = rawInvoices.where((raw) {
      final invoice = jsonDecode(raw);
      final name = invoice['customer'] ?? invoice['name'] ?? '';
      return name.toLowerCase().contains(query);
    }).toList();
    setState(() {});
  }

  void _deleteInvoice(int index) {
    final rawToDelete = filteredInvoices[index];
    rawInvoices.remove(rawToDelete);
    filteredInvoices.removeAt(index);
    html.window.localStorage['invoices'] = jsonEncode(rawInvoices);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كل الفواتير'),
        actions: [
          if (rawInvoices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('تأكيد'),
                    content: const Text('هل أنت متأكد من حذف جميع الفواتير؟'),
                    actions: [
                      TextButton(
                        child: const Text('إلغاء'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: const Text('حذف الكل'),
                        onPressed: () {
                          html.window.localStorage.remove('invoices');
                          Navigator.pop(context);
                          setState(() {
                            rawInvoices.clear();
                            filteredInvoices.clear();
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: rawInvoices.isEmpty
          ? const Center(child: Text('لا توجد فواتير محفوظة.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث باسم العميل...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredInvoices.isEmpty
                      ? const Center(child: Text('لا توجد نتائج.'))
                      : ListView.builder(
                          itemCount: filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final raw = filteredInvoices[index];
                            final invoice = jsonDecode(raw);
                            final isNew = invoice.containsKey('items');
                            final name = invoice['customer'] ?? invoice['name'] ?? 'غير معروف';
                            final date = (invoice['timestamp'] ?? '').toString().split('T').first;

                            double total = 0;
                            if (isNew) {
                              final items = List<Map<String, dynamic>>.from(invoice['items']);
                              total = items.fold<double>(
                                0,
                                (sum, item) {
                                  final qty = double.tryParse(item['qty'] ?? '0') ?? 0;
                                  final price = double.tryParse(item['price'] ?? '0') ?? 0;
                                  return sum + (qty * price);
                                },
                              );
                            } else {
                              total = double.tryParse(invoice['amount'] ?? '0') ?? 0;
                            }

                            return ListTile(
                              title: Text(name),
                              subtitle: Text('₪ ${total.toStringAsFixed(2)} - $date'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteInvoice(index),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailsScreen(jsonInvoice: raw),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
