import 'package:flutter/material.dart';
import 'screens/new_invoice_screen.dart';
import 'screens/invoice_list_screen.dart';
import 'screens/customer_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yanal Pro',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple.shade300,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '📋 Yanal Pro – الرئيسية',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إنشاء فاتورة جديدة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 50),
                ),
                onPressed: () => _navigate(context, const NewInvoiceScreen()),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('عرض كل الفواتير'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 50),
                ),
                onPressed: () => _navigate(context, const InvoiceListScreen()),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.people),
                label: const Text('إدارة العملاء'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 50),
                ),
                onPressed: () => _navigate(context, const CustomerListScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}