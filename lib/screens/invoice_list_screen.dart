import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'invoice_details_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<String> _rawInvoices = [];
  List<String> _filteredInvoices = [];
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all'; // all | paid | unpaid | partial

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('invoices') ?? [];
    // Show newest first
    _rawInvoices = raw.reversed.toList();
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInvoices = _rawInvoices.where((raw) {
        try {
          final inv = jsonDecode(raw) as Map<String, dynamic>;
          final name = (inv['customer'] ?? inv['name'] ?? '').toString().toLowerCase();
          final status = inv['paymentStatus'] ?? 'unpaid';

          final matchesSearch = query.isEmpty || name.contains(query);
          final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

          return matchesSearch && matchesStatus;
        } catch (_) {
          return false;
        }
      }).toList();
    });
  }

  Future<void> _deleteInvoice(int filteredIndex) async {
    final rawToDelete = _filteredInvoices[filteredIndex];
    _rawInvoices.remove(rawToDelete);
    _filteredInvoices.removeAt(filteredIndex);

    final prefs = await SharedPreferences.getInstance();
    // Restore original order (newest-first is just display; save reversed)
    await prefs.setStringList('invoices', _rawInvoices.reversed.toList());
    setState(() {});
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف جميع الفواتير؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف الكل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('invoices');
      if (!mounted) return;
      setState(() {
        _rawInvoices.clear();
        _filteredInvoices.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الفواتير (${_rawInvoices.length})'),
        centerTitle: true,
        actions: [
          if (_rawInvoices.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'حذف الكل',
              onPressed: _confirmDeleteAll,
            ),
        ],
      ),
      body: _rawInvoices.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('لا توجد فواتير محفوظة', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث باسم العميل...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),

                // Status filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'الكل', Colors.grey),
                        const SizedBox(width: 8),
                        _filterChip('unpaid', 'غير مدفوع', Colors.red),
                        const SizedBox(width: 8),
                        _filterChip('paid', 'مدفوع', Colors.green),
                        const SizedBox(width: 8),
                        _filterChip('partial', 'جزئي', Colors.orange),
                      ],
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: _filteredInvoices.isEmpty
                      ? const Center(child: Text('لا توجد نتائج'))
                      : ListView.builder(
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            return _buildInvoiceTile(index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String value, String label, Color color) {
    final selected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _applyFilters();
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : null, fontWeight: selected ? FontWeight.bold : null),
      side: BorderSide(color: selected ? color : Colors.grey.shade600),
    );
  }

  Widget _buildInvoiceTile(int index) {
    try {
      final raw = _filteredInvoices[index];
      final inv = jsonDecode(raw) as Map<String, dynamic>;
      final name = inv['customer'] ?? inv['name'] ?? 'غير معروف';
      final date = (inv['timestamp'] ?? '').toString().split('T').first;
      final number = inv['invoiceNumber'];
      final status = inv['paymentStatus'] ?? 'unpaid';

      final items = List<Map<String, dynamic>>.from(inv['items'] ?? []);
      final subtotal = items.fold<double>(0, (sum, item) {
        final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        return sum + qty * price;
      });
      final discount = double.tryParse(inv['discount']?.toString() ?? '0') ?? 0;
      final total = (subtotal - discount).clamp(0.0, double.infinity);

      Color statusColor;
      String statusLabel;
      IconData statusIcon;
      switch (status) {
        case 'paid':
          statusColor = Colors.green;
          statusLabel = 'مدفوع';
          statusIcon = Icons.check_circle;
          break;
        case 'partial':
          statusColor = Colors.orange;
          statusLabel = 'جزئي';
          statusIcon = Icons.timelapse;
          break;
        default:
          statusColor = Colors.red;
          statusLabel = 'غير مدفوع';
          statusIcon = Icons.cancel;
      }

      return Dismissible(
        key: ValueKey(raw),
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
              title: const Text('حذف الفاتورة'),
              content: Text('هل تريد حذف فاتورة $name؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حذف', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => _deleteInvoice(index),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.12),
              child: number != null
                  ? Text('#$number', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold))
                  : Icon(Icons.receipt, color: statusColor, size: 18),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(date, style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₪${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 3),
                    Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11)),
                  ],
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailsScreen(jsonInvoice: raw),
                ),
              );
              // Reload in case payment status was updated
              _loadInvoices();
            },
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
