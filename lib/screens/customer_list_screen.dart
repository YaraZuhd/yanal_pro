import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<String> customers = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => customers = prefs.getStringList('customers') ?? []);
  }

 Future<void> _addCustomer(String name) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty || customers.contains(trimmed)) return;

  setState(() => customers.add(trimmed)); // نضيف داخل نفس الصفحة
  await _saveCustomers();
  _controller.clear();
}

  Future<void> _deleteCustomer(int index) async {
    customers.removeAt(index);
    await _saveCustomers();
    setState(() {});
  }

  Future<void> _saveCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customers', customers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة العملاء')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'اسم العميل',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addCustomer(_controller.text),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: customers.isEmpty
                  ? const Center(child: Text('لا يوجد عملاء بعد'))
                  : ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(customers[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCustomer(index),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}