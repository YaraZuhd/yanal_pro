import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  double _totalRevenue = 0;
  double _totalPaid = 0;
  double _totalUnpaid = 0;
  double _totalExpenses = 0;
  int _invoiceCount = 0;
  int _paidCount = 0;
  int _unpaidCount = 0;
  int _partialCount = 0;
  List<Map<String, dynamic>> _recentInvoices = [];
  Map<String, double> _monthlyRevenue = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final rawInvoices = prefs.getStringList('invoices') ?? [];
    final rawExpenses = prefs.getStringList('expenses') ?? [];

    double revenue = 0, paid = 0, unpaid = 0, expenses = 0;
    int paidCount = 0, unpaidCount = 0, partialCount = 0;
    final List<Map<String, dynamic>> allInvoices = [];
    final Map<String, double> monthly = {};

    for (final raw in rawInvoices) {
      try {
        final inv = jsonDecode(raw) as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(inv['items'] ?? []);
        final subtotal = items.fold<double>(0, (sum, item) {
          final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          return sum + qty * price;
        });
        final discount = double.tryParse(inv['discount']?.toString() ?? '0') ?? 0;
        final total = (subtotal - discount).clamp(0.0, double.infinity);

        revenue += total;
        final status = inv['paymentStatus'] ?? 'unpaid';

        if (status == 'paid') {
          paid += total;
          paidCount++;
        } else if (status == 'partial') {
          partialCount++;
          unpaid += total;
        } else {
          unpaid += total;
          unpaidCount++;
        }

        // Monthly breakdown
        final ts = inv['timestamp']?.toString() ?? '';
        if (ts.length >= 7) {
          final monthKey = ts.substring(0, 7); // YYYY-MM
          monthly[monthKey] = (monthly[monthKey] ?? 0) + total;
        }

        allInvoices.add({...inv, '_total': total});
      } catch (_) {}
    }

    for (final raw in rawExpenses) {
      try {
        final exp = jsonDecode(raw) as Map<String, dynamic>;
        expenses += double.tryParse(exp['amount']?.toString() ?? '0') ?? 0;
      } catch (_) {}
    }

    // Sort recent by timestamp desc, take 6
    allInvoices.sort((a, b) =>
        (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

    // Sort monthly keys
    final sortedMonthly = Map.fromEntries(
      monthly.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );

    if (!mounted) return;
    setState(() {
      _totalRevenue = revenue;
      _totalPaid = paid;
      _totalUnpaid = unpaid;
      _totalExpenses = expenses;
      _invoiceCount = rawInvoices.length;
      _paidCount = paidCount;
      _unpaidCount = unpaidCount;
      _partialCount = partialCount;
      _recentInvoices = allInvoices.take(6).toList();
      _monthlyRevenue = sortedMonthly;
      _loading = false;
    });
  }

  String _monthLabel(String key) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final parts = key.split('-');
    if (parts.length == 2) {
      final m = int.tryParse(parts[1]) ?? 0;
      if (m >= 1 && m <= 12) return '${months[m]} ${parts[0]}';
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final net = _totalPaid - _totalExpenses;
    final isProfit = net >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص الحسابات'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _statCard('إجمالي الإيرادات', '₪${_totalRevenue.toStringAsFixed(2)}', Icons.trending_up, Colors.blueAccent),
                      _statCard('المحصّل', '₪${_totalPaid.toStringAsFixed(2)}', Icons.check_circle, Colors.greenAccent),
                      _statCard('المستحق', '₪${_totalUnpaid.toStringAsFixed(2)}', Icons.pending_actions, Colors.orangeAccent),
                      _statCard('المصروفات', '₪${_totalExpenses.toStringAsFixed(2)}', Icons.payments, Colors.redAccent),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Net balance
                  Card(
                    color: isProfit ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isProfit ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isProfit ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                                color: isProfit ? Colors.green : Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              const Text('صافي الربح', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(
                            '${isProfit ? '+' : ''}₪${net.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isProfit ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Invoice breakdown
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إحصائيات الفواتير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _statRow('إجمالي الفواتير', '$_invoiceCount', Icons.receipt_long, Colors.blue),
                          _statRow('مدفوعة', '$_paidCount', Icons.check_circle, Colors.green),
                          _statRow('دفع جزئي', '$_partialCount', Icons.timelapse, Colors.orange),
                          _statRow('غير مدفوعة', '$_unpaidCount', Icons.cancel, Colors.red),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Monthly breakdown
                  if (_monthlyRevenue.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الإيرادات الشهرية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ..._monthlyRevenue.entries.take(6).map((e) {
                              final maxVal = _monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
                              final ratio = maxVal > 0 ? e.value / maxVal : 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_monthLabel(e.key), style: const TextStyle(fontSize: 13)),
                                        Text('₪${e.value.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: Colors.grey.shade800,
                                      color: Theme.of(context).colorScheme.primary,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recent invoices
                  if (_recentInvoices.isNotEmpty) ...[
                    const Text('آخر الفواتير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._recentInvoices.map(_recentInvoiceTile),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 26),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _recentInvoiceTile(Map<String, dynamic> inv) {
    final customer = inv['customer'] ?? 'غير معروف';
    final total = (inv['_total'] as double?) ?? 0.0;
    final status = inv['paymentStatus'] ?? 'unpaid';
    final date = (inv['timestamp'] ?? '').toString().split('T').first;
    final number = inv['invoiceNumber'];

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusLabel = 'مدفوع';
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusLabel = 'جزئي';
        break;
      default:
        statusColor = Colors.red;
        statusLabel = 'غير مدفوع';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.12),
          child: number != null
              ? Text('#$number', style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold))
              : Icon(Icons.receipt, color: statusColor, size: 16),
        ),
        title: Text(customer, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date, style: const TextStyle(fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₪${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
