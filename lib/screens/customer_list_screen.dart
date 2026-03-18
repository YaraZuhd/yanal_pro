import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  // Each entry: {name: String, phone: String}
  List<Map<String, String>> customers = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('customers') ?? [];
    final loaded = raw.map((item) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        return {
          'name': (data['name'] ?? item).toString(),
          'phone': (data['phone'] ?? '').toString(),
        };
      } catch (_) {
        // Legacy plain string customer
        return {'name': item, 'phone': ''};
      }
    }).toList();

    if (!mounted) return;
    setState(() {
      customers = loaded;
      _filtered = List.from(customers);
    });
  }

  void _applySearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = customers.where((c) {
        return c['name']!.toLowerCase().contains(q) || c['phone']!.contains(q);
      }).toList();
    });
  }

  Future<void> _saveCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'customers',
      customers.map((c) => jsonEncode(c)).toList(),
    );
  }

  Future<void> _addCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) return;
    if (customers.any((c) => c['name'] == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العميل موجود مسبقاً')),
      );
      return;
    }

    setState(() {
      customers.add({'name': name, 'phone': phone});
      _filtered = List.from(customers);
    });
    await _saveCustomers();
    _nameController.clear();
    _phoneController.clear();
  }

  Future<void> _deleteCustomer(int filteredIndex) async {
    final customer = _filtered[filteredIndex];
    customers.removeWhere((c) => c['name'] == customer['name']);
    _filtered.removeAt(filteredIndex);
    setState(() {});
    await _saveCustomers();
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
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
            const Text('إضافة عميل جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم العميل *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
                onPressed: () {
                  Navigator.pop(context);
                  _addCustomer();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('العملاء (${customers.length})'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('عميل جديد'),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'بحث...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          // List
          Expanded(
            child: customers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لا يوجد عملاء بعد', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _filtered.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          return Dismissible(
                            key: ValueKey(c['name']),
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
                                  title: const Text('حذف العميل'),
                                  content: Text('حذف ${c['name']}؟'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) => _deleteCustomer(index),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  c['name']!.isNotEmpty ? c['name']![0] : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: c['phone']!.isNotEmpty
                                  ? Row(
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(c['phone']!, style: const TextStyle(fontSize: 12)),
                                      ],
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteCustomer(index),
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
}
