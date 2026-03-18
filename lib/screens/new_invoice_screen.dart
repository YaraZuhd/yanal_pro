import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'invoice_details_screen.dart';
import 'customer_list_screen.dart';

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  String? selectedCustomer;
  List<String> customers = [];
  String _paymentStatus = 'unpaid';

  // Each row: name, qty, price controllers
  final List<List<TextEditingController>> _itemControllers = [];

  @override
  void initState() {
    super.initState();
    _addItemRow();
    _loadCustomers();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _discountController.dispose();
    for (final row in _itemControllers) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addItemRow() {
    _itemControllers.add([
      TextEditingController(), // name
      TextEditingController(), // qty
      TextEditingController(), // price
    ]);
  }

  void _removeItemRow(int index) {
    if (_itemControllers.length <= 1) return;
    for (final c in _itemControllers[index]) {
      c.dispose();
    }
    setState(() => _itemControllers.removeAt(index));
  }

  Future<void> _loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('customers') ?? [];
    final names = raw.map((c) {
      try {
        final data = jsonDecode(c) as Map<String, dynamic>;
        return data['name'] as String? ?? c;
      } catch (_) {
        return c;
      }
    }).toList();

    if (!mounted) return;
    setState(() => customers = names);
  }

  double get _subtotal {
    double total = 0;
    for (final row in _itemControllers) {
      final qty = double.tryParse(row[1].text) ?? 0;
      final price = double.tryParse(row[2].text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  double get _discount => (double.tryParse(_discountController.text) ?? 0).clamp(0, double.infinity);

  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم العميل *',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            child: const Text('إضافة'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty || customers.contains(name)) {
                if (mounted) Navigator.pop(context);
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              final rawList = prefs.getStringList('customers') ?? [];
              rawList.add(jsonEncode({'name': name, 'phone': phoneCtrl.text.trim()}));
              await prefs.setStringList('customers', rawList);
              if (!mounted) return;
              setState(() {
                customers.add(name);
                selectedCustomer = name;
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<int> _getNextInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt('invoice_counter') ?? 0) + 1;
    await prefs.setInt('invoice_counter', next);
    return next;
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار العميل')),
      );
      return;
    }

    final invoiceNumber = await _getNextInvoiceNumber();

    final items = _itemControllers
        .map((row) => {
              'name': row[0].text.trim(),
              'qty': row[1].text.trim(),
              'price': row[2].text.trim(),
            })
        .toList();

    final invoice = {
      'invoiceNumber': invoiceNumber,
      'customer': selectedCustomer,
      'note': _noteController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'items': items,
      'discount': _discountController.text.trim().isEmpty ? '0' : _discountController.text.trim(),
      'paymentStatus': _paymentStatus,
    };

    final prefs = await SharedPreferences.getInstance();
    final invoices = prefs.getStringList('invoices') ?? [];
    invoices.add(jsonEncode(invoice));
    await prefs.setStringList('invoices', invoices);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تم الحفظ ✓'),
        content: Text('تم حفظ الفاتورة رقم #$invoiceNumber بنجاح!'),
        actions: [
          TextButton(
            child: const Text('فاتورة جديدة'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const NewInvoiceScreen()),
              );
            },
          ),
          TextButton(
            child: const Text('عرض الفاتورة'),
            onPressed: () {
              Navigator.pop(context);
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer selection
            _buildCustomerRow(),
            const SizedBox(height: 20),

            // Items header
            const Row(
              children: [
                Icon(Icons.shopping_cart, size: 18),
                SizedBox(width: 6),
                Text('المنتجات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // Item rows
            ...List.generate(_itemControllers.length, (i) => _buildItemRow(i)),

            // Add item button
            TextButton.icon(
              onPressed: () => setState(_addItemRow),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('إضافة منتج'),
            ),

            const Divider(height: 32),

            // Totals
            _buildTotalSection(),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),

            const SizedBox(height: 16),

            // Payment status
            _buildPaymentStatusSection(),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saveInvoice,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الفاتورة', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerRow() {
    return Row(
      children: [
        Expanded(
          child: customers.isEmpty
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('إضافة أول عميل'),
                  onPressed: _showAddCustomerDialog,
                )
              : DropdownButtonFormField2<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'اختر العميل',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: customers
                      .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  value: selectedCustomer,
                  onChanged: (v) => setState(() => selectedCustomer = v),
                  validator: (v) => v == null ? 'اختر العميل' : null,
                ),
        ),
        IconButton(
          icon: const Icon(Icons.person_add_alt),
          tooltip: 'عميل جديد',
          onPressed: _showAddCustomerDialog,
        ),
        IconButton(
          icon: const Icon(Icons.manage_accounts),
          tooltip: 'إدارة العملاء',
          onPressed: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
            _loadCustomers();
          },
        ),
      ],
    );
  }

  Widget _buildItemRow(int index) {
    final row = _itemControllers[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: row[0],
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row[1],
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    if (double.tryParse(v) == null) return 'رقم';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: row[2],
                  decoration: const InputDecoration(
                    labelText: 'السعر ₪',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    if (double.tryParse(v) == null) return 'رقم';
                    return null;
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: _itemControllers.length > 1 ? Colors.red : Colors.grey,
                  size: 20,
                ),
                onPressed: _itemControllers.length > 1 ? () => _removeItemRow(index) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع الفرعي:', style: TextStyle(fontSize: 14)),
                Text('₪${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('الخصم ₪:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _discountController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                        return 'رقم غير صالح';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع الكلي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '₪${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, size: 18),
                SizedBox(width: 6),
                Text('حالة الدفع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statusChip('unpaid', 'غير مدفوع', Colors.red),
                const SizedBox(width: 8),
                _statusChip('paid', 'مدفوع', Colors.green),
                const SizedBox(width: 8),
                _statusChip('partial', 'دفع جزئي', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String value, String label, Color color) {
    final selected = _paymentStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.grey.shade600, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
