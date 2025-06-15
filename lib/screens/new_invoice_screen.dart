import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'invoice_details_screen.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  String? selectedCustomer;
  List<String> customers = [];

  List<Map<String, String>> items = [
    {'name': '', 'qty': '', 'price': ''},
  ];

  @override
  void initState() {
    super.initState();
    final stored = html.window.localStorage['customers'];
    if (stored != null) {
      customers = stored.split(',');
    }
  }

  void _showAddCustomerDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'اسم العميل',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('إضافة'),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && !customers.contains(name)) {
                customers.add(name);
                html.window.localStorage['customers'] = customers.join(',');
                setState(() {
                  selectedCustomer = name;
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _saveInvoice() {
    if (!_formKey.currentState!.validate()) return;

    final invoice = {
      'customer': selectedCustomer,
      'note': _noteController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'items': items
    };

    final stored = html.window.localStorage['invoices'];
    List<String> invoices = [];
    if (stored != null) {
      invoices = List<String>.from(jsonDecode(stored));
    }
    invoices.add(jsonEncode(invoice));
    html.window.localStorage['invoices'] = jsonEncode(invoices);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تم الحفظ'),
        content: const Text('تم حفظ الفاتورة بنجاح!'),
        actions: [
          TextButton(
            child: const Text('عرض الفاتورة'),
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailsScreen(jsonInvoice: jsonEncode(invoice)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة جديدة'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField2<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'اختر العميل',
                        border: OutlineInputBorder(),
                      ),
                      items: customers
                          .map((name) =>
                              DropdownMenuItem(value: name, child: Text(name)))
                          .toList(),
                      value: selectedCustomer,
                      onChanged: (value) =>
                          setState(() => selectedCustomer = value),
                      validator: (value) =>
                          value == null ? 'اختر العميل' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    tooltip: 'إضافة عميل جديد',
                    onPressed: _showAddCustomerDialog,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'اسم المنتج',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: items[index]['name'],
                              onChanged: (value) => items[index]['name'] = value,
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'أدخل اسم المنتج'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'الكمية',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: items[index]['qty'],
                              onChanged: (value) => items[index]['qty'] = value,
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'أدخل الكمية'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'سعر الوحدة',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: items[index]['price'],
                              onChanged: (value) =>
                                  items[index]['price'] = value,
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'أدخل السعر'
                                      : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                items.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      items.add({'name': '', 'qty': '', 'price': ''});
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveInvoice,
                child: const Text('حفظ الفاتورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}