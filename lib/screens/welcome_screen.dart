import 'package:flutter/material.dart';
import 'new_invoice_screen.dart';
import 'invoice_list_screen.dart';
import 'customer_list_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
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
            Text(
              'Yanal Pro – الرئيسية',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '✨ أهلًا ينال',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildButton(
                  context,
                  label: 'إنشاء فاتورة جديدة',
                  icon: Icons.add,
                  onPressed: () => _navigate(context, const NewInvoiceScreen()),
                ),
                const SizedBox(height: 16),
                _buildButton(
                  context,
                  label: 'عرض كل الفواتير',
                  icon: Icons.receipt_long,
                  onPressed: () => _navigate(context, const InvoiceListScreen()),
                ),
                const SizedBox(height: 16),
                _buildButton(
                  context,
                  label: 'إدارة العملاء',
                  icon: Icons.people,
                  onPressed: () => _navigate(context, const CustomerListScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context,
      {required String label, required IconData icon, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(250, 50),
        backgroundColor: const Color.fromARGB(255, 227, 223, 237),
        foregroundColor: const Color.fromARGB(255, 108, 30, 122),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}