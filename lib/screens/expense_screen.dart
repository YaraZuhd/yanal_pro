import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Map<String, dynamic>> _expenses = [];
  double _total = 0;
  String _categoryFilter = 'all';

  static const _categories = {
    'stock': ('شراء بضاعة', Icons.inventory),
    'transport': ('نقل وتوصيل', Icons.local_shipping),
    'utilities': ('فواتير ومرافق', Icons.electrical_services),
    'salary': ('رواتب', Icons.people),
    'other': ('أخرى', Icons.attach_money),
  };

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('expenses') ?? [];
    final loaded = <Map<String, dynamic>>[];
    double total = 0;

    for (final item in raw) {
      try {
        final exp = jsonDecode(item) as Map<String, dynamic>;
        loaded.add(exp);
        total += double.tryParse(exp['amount']?.toString() ?? '0') ?? 0;
      } catch (_) {}
    }

    // Sort newest first
    loaded.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

    if (!mounted) return;
    setState(() {
      _expenses = loaded;
      _total = total;
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('expenses', _expenses.map((e) => jsonEncode(e)).toList());
  }

  List<Map<String, dynamic>> get _filtered {
    if (_categoryFilter == 'all') return _expenses;
    return _expenses.where((e) => (e['category'] ?? 'other') == _categoryFilter).toList();
  }

  double get _filteredTotal {
    return _filtered.fold(0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));
  }

  void _showAddDialog() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'other';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إضافة مصروف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'الوصف *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'المبلغ ₪ *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Row(
                      children: [
                        Icon(e.value.$2, size: 18),
                        const SizedBox(width: 8),
                        Text(e.value.$1),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setSheet(() => category = v ?? 'other'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
                onPressed: () async {
                  final desc = descCtrl.text.trim();
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (desc.isEmpty || amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال الوصف والمبلغ بشكل صحيح')),
                    );
                    return;
                  }
                  _expenses.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'description': desc,
                    'amount': amount.toString(),
                    'category': category,
                    'timestamp': DateTime.now().toIso8601String(),
                  });
                  await _saveAll();
                  await _loadExpenses();
                  if (mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteExpense(String id) async {
    _expenses.removeWhere((e) => e['id'] == id);
    await _saveAll();
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المصروفات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة مصروف'),
      ),
      body: Column(
        children: [
          // Total banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payments, color: Colors.red),
                    SizedBox(width: 8),
                    Text('إجمالي المصروفات', style: TextStyle(fontSize: 15)),
                  ],
                ),
                Text(
                  '₪${_total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),

          // Category filter chips
          if (_expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _catChip('all', 'الكل', Icons.list),
                    ..._categories.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _catChip(e.key, e.value.$1, e.value.$2),
                        )),
                  ],
                ),
              ),
            ),

          if (_categoryFilter != 'all' && _expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المجموع المصفّى:', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  Text('₪${_filteredTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),

          const SizedBox(height: 4),

          Expanded(
            child: _expenses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.money_off, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لا توجد مصروفات مسجلة', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _filtered.isEmpty
                    ? const Center(child: Text('لا توجد مصروفات في هذا التصنيف'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (ctx, i) {
                          final exp = _filtered[i];
                          final cat = exp['category'] ?? 'other';
                          final catInfo = _categories[cat] ?? ('أخرى', Icons.attach_money);
                          final date = (exp['timestamp'] ?? '').toString().split('T').first;
                          final amount = double.tryParse(exp['amount']?.toString() ?? '0') ?? 0;

                          return Dismissible(
                            key: ValueKey(exp['id'] ?? exp['timestamp']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('حذف المصروف'),
                                  content: Text('حذف "${exp['description']}"؟'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('إلغاء')),
                                    TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) => _deleteExpense(exp['id'] ?? ''),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                child: Icon(catInfo.$2, color: Colors.red, size: 20),
                              ),
                              title: Text(exp['description'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${catInfo.$1} · $date',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₪${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _deleteExpense(exp['id'] ?? ''),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String value, String label, IconData icon) {
    final selected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(icon, size: 14, color: selected ? Colors.red : null),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _categoryFilter = value),
        selectedColor: Colors.red.withOpacity(0.15),
        checkmarkColor: Colors.red,
        side: BorderSide(color: selected ? Colors.red : Colors.grey.shade600),
      ),
    );
  }
}
