# Yanal Pro — Trade & Accounting Management System

A Flutter app for managing invoices, customers, expenses, and accounting for **Al-Ebhri Yanal Trading & Distribution**.

---

## Features

### Invoices
- Create sales invoices with auto-incrementing numbers (#1, #2, ...)
- Add multiple line items with quantity and unit price
- Discount field with live total calculation
- Payment status tracking: **Paid / Unpaid / Partial**
- Update payment status directly from the invoice details screen
- Optional notes per invoice
- Export invoices as PDF (includes invoice number, discount, payment status, signature fields)
- Bluetooth thermal printer support

### Customers
- Add customers with name and phone number
- Search within the customer list
- Swipe-to-delete

### Invoice List
- Newest invoices shown first
- Filter by payment status (All / Paid / Unpaid / Partial)
- Search by customer name
- Color-coded payment status badges
- Swipe-to-delete with confirmation

### Accounting Summary
- Total revenue, collected amount, and outstanding balance
- Total expenses and net profit
- Invoice breakdown by status (paid / partial / unpaid)
- Monthly revenue report with visual progress bars

### Expenses
- Log expenses with description, amount, and category
- Categories: Stock Purchase / Transport / Utilities / Salaries / Other
- Filter by category with a running filtered total

### Dashboard (Home Screen)
- Live stat cards: total invoices, unpaid count, revenue, customer count
- Auto-refreshes when returning from any screen

---

## Tech Stack

| Component | Technology |
|---|---|
| Framework | Flutter 3.x / Dart 3.8+ |
| Storage | SharedPreferences (local) |
| PDF Generation | `pdf` + `printing` |
| Thermal Printing | `blue_thermal_printer` (stub) |
| UI | Material Design 3 — Dark Theme |
| Font | Amiri (Arabic font for PDF output) |

---

## Project Structure

```
lib/
├── main.dart
└── screens/
    ├── welcome_screen.dart          # Dashboard + stats
    ├── new_invoice_screen.dart      # Create new invoice
    ├── invoice_list_screen.dart     # Invoice list with filters
    ├── invoice_details_screen.dart  # Details + PDF + payment update
    ├── customer_list_screen.dart    # Customer management
    ├── accounting_screen.dart       # Financial summary
    ├── expense_screen.dart          # Expense tracking
    ├── thermal_printer_service.dart
    └── thermal_print_screen.dart

packages/
└── blue_thermal_printer/           # Bluetooth printer stub package
```

---

## Data Models

**Invoice:**
```json
{
  "invoiceNumber": 1,
  "customer": "Customer Name",
  "timestamp": "2026-03-18T10:00:00.000Z",
  "items": [
    { "name": "Product", "qty": "5", "price": "10.00" }
  ],
  "discount": "5",
  "paymentStatus": "paid",
  "note": "Optional note"
}
```

**Customer:**
```json
{ "name": "Customer Name", "phone": "059xxxxxxx" }
```

**Expense:**
```json
{
  "id": "1710000000000",
  "description": "Stock purchase",
  "amount": "500",
  "category": "stock",
  "timestamp": "2026-03-18T10:00:00.000Z"
}
```

---

## Business Info

- **Company:** Al-Ebhri Yanal Trading & Distribution — Sha'ban
- **Location:** Farkhah, Salfit, Palestine
- **Phone:** 0568499052
- **Currency:** New Israeli Shekel (₪)

---

## Getting Started

```bash
flutter pub get
flutter run
```
