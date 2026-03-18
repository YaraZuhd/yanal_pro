import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'new_invoice_screen.dart';
import 'invoice_list_screen.dart';
import 'customer_list_screen.dart';
import 'accounting_screen.dart';
import 'expense_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _invoiceCount = 0;
  int _unpaidCount = 0;
  double _totalRevenue = 0;
  int _customerCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final rawInvoices = prefs.getStringList('invoices') ?? [];
    final rawCustomers = prefs.getStringList('customers') ?? [];

    int unpaid = 0;
    double revenue = 0;

    for (final raw in rawInvoices) {
      try {
        final inv = jsonDecode(raw) as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(inv['items'] ?? []);
        double subtotal = items.fold(0.0, (sum, item) {
          final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          return sum + qty * price;
        });
        final discount = double.tryParse(inv['discount']?.toString() ?? '0') ?? 0;
        revenue += (subtotal - discount).clamp(0.0, double.infinity);
        if ((inv['paymentStatus'] ?? 'unpaid') != 'paid') unpaid++;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _invoiceCount = rawInvoices.length;
      _unpaidCount = unpaid;
      _totalRevenue = revenue;
      _customerCount = rawCustomers.length;
      _loading = false;
    });
  }

  Future<void> _navigate(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, color: Colors.deepPurpleAccent),
            SizedBox(width: 8),
            Text('Yanal Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const Text(
                'العبهري ينال للتجارة والتوزيع',
                style: TextStyle(fontSize: 15, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const Text(
                'فرخة - سلفيت | 0568499052',
                style: TextStyle(fontSize: 12, color: Colors.white38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Stats Grid
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildStatsGrid(),

              const SizedBox(height: 24),

              // Invoice actions
              _sectionLabel('الفواتير'),
              const SizedBox(height: 8),
              _buildMenuTile(
                icon: Icons.add_circle,
                label: 'إنشاء فاتورة جديدة',
                subtitle: 'إضافة فاتورة بيع جديدة',
                color: Colors.deepPurpleAccent,
                onTap: () => _navigate(const NewInvoiceScreen()),
              ),
              _buildMenuTile(
                icon: Icons.receipt_long,
                label: 'كل الفواتير',
                subtitle: 'عرض وإدارة الفواتير',
                color: Colors.blueAccent,
                onTap: () => _navigate(const InvoiceListScreen()),
              ),
              _buildMenuTile(
                icon: Icons.people,
                label: 'إدارة العملاء',
                subtitle: 'عرض وإضافة العملاء',
                color: Colors.tealAccent,
                onTap: () => _navigate(const CustomerListScreen()),
              ),

              const SizedBox(height: 16),

              // Accounting actions
              _sectionLabel('الحسابات'),
              const SizedBox(height: 8),
              _buildMenuTile(
                icon: Icons.bar_chart,
                label: 'ملخص الحسابات',
                subtitle: 'الإيرادات والمصروفات والأرباح',
                color: Colors.greenAccent,
                onTap: () => _navigate(const AccountingScreen()),
              ),
              _buildMenuTile(
                icon: Icons.payments,
                label: 'المصروفات',
                subtitle: 'تسجيل ومتابعة المصروفات',
                color: Colors.redAccent,
                onTap: () => _navigate(const ExpenseScreen()),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _buildStatCard('الفواتير', '$_invoiceCount', Icons.receipt, Colors.blueAccent),
        _buildStatCard(
          'غير مدفوعة',
          '$_unpaidCount',
          Icons.pending_actions,
          _unpaidCount > 0 ? Colors.orangeAccent : Colors.grey,
        ),
        _buildStatCard('الإيرادات', '₪${_totalRevenue.toStringAsFixed(0)}', Icons.trending_up, Colors.greenAccent),
        _buildStatCard('العملاء', '$_customerCount', Icons.people, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
