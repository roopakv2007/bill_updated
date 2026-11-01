import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const pink = Color(0xFFE91E63);
const green = Color(0xFF8BC34A);
const ink = Color(0xFF242A35);
const ledgerCanvas = Color(0xFFFBF9F5);
const ledgerSurface = Color(0xFFFFFFFF);
const ledgerInset = Color(0xFFF5F1E9);
const ledgerBorder = Color(0xFFE7E2D8);
const ledgerInk = Color(0xFF141B2D);
const ledgerMuted = Color(0xFF6F7785);
const vermilion = Color(0xFFD9381E);
const ledgerTeal = Color(0xFF238C87);
const ledgerGold = Color(0xFFD3A343);
const ledgerLeaf = Color(0xFF75A66A);
const rupees = '₹';
final money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: rupees,
  decimalDigits: 2,
);

class BillItem {
  BillItem({this.description = '', this.qty = 1, this.rate = 0});
  String description;
  double qty;
  double rate;
  double get amount => qty * rate;
  Map<String, dynamic> toJson() => {
    'description': description,
    'qty': qty,
    'rate': rate,
  };
  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    description: json['description'] ?? '',
    qty: (json['qty'] as num?)?.toDouble() ?? 1,
    rate: (json['rate'] as num?)?.toDouble() ?? 0,
  );
}

class Bill {
  Bill({
    required this.id,
    required this.customer,
    required this.phone,
    required this.date,
    required this.items,
    required this.total,
    this.note = '',
    this.manual = false,
    this.tamil = false,
  });
  String id, customer, phone, note;
  DateTime date;
  List<BillItem> items;
  double total;
  bool manual, tamil;
  Map<String, dynamic> toJson() => {
    'id': id,
    'customer': customer,
    'phone': phone,
    'date': date.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'total': total,
    'note': note,
    'manual': manual,
    'tamil': tamil,
  };
  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: j['id'],
    customer: j['customer'] ?? '',
    phone: j['phone'] ?? '',
    date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    items: ((j['items'] as List?) ?? [])
        .map((e) => BillItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    total: (j['total'] as num?)?.toDouble() ?? 0,
    note: j['note'] ?? '',
    manual: j['manual'] ?? false,
    tamil: j['tamil'] ?? false,
  );
}

class BillStore extends ChangeNotifier {
  List<Bill> bills = [];
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      bills = (jsonDecode(prefs.getString('gm_bills') ?? '[]') as List)
          .map((e) => Bill.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      bills = [];
    }
    notifyListeners();
  }

  Future<void> save(Bill bill) async {
    final i = bills.indexWhere((b) => b.id == bill.id);
    if (i < 0) {
      bills.insert(0, bill);
    } else {
      bills[i] = bill;
    }
    await _persist();
  }

  Future<void> remove(Bill bill) async {
    bills.removeWhere((b) => b.id == bill.id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'gm_bills',
      jsonEncode(bills.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }
}

final store = BillStore();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const GmApp());
}

class GmApp extends StatelessWidget {
  const GmApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GM Tailors Bills',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: ledgerCanvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: vermilion,
        surface: ledgerCanvas,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ledgerCanvas,
        foregroundColor: ledgerInk,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ledgerSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ledgerBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ledgerBorder),
        ),
      ),
    ),
    home: const HomeShell(),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  void create({Bill? bill, bool manual = false}) async {
    final result = await Navigator.push<Bill>(
      context,
      MaterialPageRoute(
        builder: (_) => BillEditor(initial: bill, manual: manual),
      ),
    );
    if (result != null) {
      await store.save(result);
      if (mounted) await showBillPreview(context, result);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(
        onCreate: () => create(),
        onManual: () => create(manual: true),
        onHistory: () => setState(() => tab = 1),
      ),
      HistoryPage(onEdit: (b) => create(bill: b)),
      AnalyticsPage(onManual: () => create(manual: true)),
      const SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => create(),
              backgroundColor: vermilion,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New bill'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: ledgerSurface,
        indicatorColor: const Color(0xFFFBE5DF),
        elevation: 0,
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.onCreate,
    required this.onManual,
    required this.onHistory,
  });
  final VoidCallback onCreate, onManual, onHistory;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) {
      final today = DateTime.now();
      final monthBills = store.bills
          .where(
            (b) => b.date.year == today.year && b.date.month == today.month,
          )
          .toList();
      final total = monthBills.fold<double>(0, (v, b) => v + b.total);
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: ledgerInset,
                        border: Border.all(color: ledgerBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/vin.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.content_cut,
                          color: vermilion,
                          size: 25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GM TAILORS',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: ledgerInk,
                            ),
                          ),
                          Text(
                            'Your business, well measured.',
                            style: TextStyle(color: ledgerMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: ledgerInset,
                        foregroundColor: ledgerInk,
                      ),
                      onPressed: onHistory,
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: ledgerInk,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF31394A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: Color(0xFFD9CDBA),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            DateFormat('MMMM yyyy').format(today).toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFD9CDBA),
                              fontSize: 11,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.ssid_chart,
                            size: 18,
                            color: Color(0xFFFF927B),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Income recorded',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        money.format(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: const Color(0xFF3A4251)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 16,
                            color: Color(0xFFFF927B),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${monthBills.length} records this month',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${monthBills.where((b) => b.manual).length} manual',
                            style: const TextStyle(
                              color: Color(0xFF9DD3C8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_to_photos_outlined,
                        title: 'Create bill',
                        subtitle: 'Build an invoice',
                        color: vermilion,
                        onTap: onCreate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_card_outlined,
                        title: 'Add income',
                        subtitle: 'Record without a bill',
                        color: ledgerTeal,
                        onTap: onManual,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 27),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent activity',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: ledgerInk,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'A running record of your shop',
                          style: TextStyle(color: ledgerMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: onHistory,
                      style: TextButton.styleFrom(foregroundColor: vermilion),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (store.bills.isEmpty)
                  const _EmptyState(
                    text: 'Your saved bills and income will appear here.',
                  )
                else
                  ...store.bills
                      .take(4)
                      .map(
                        (b) => BillTile(
                          bill: b,
                          onTap: () => showBillPreview(context, b),
                          onDelete: () => store.remove(b),
                        ),
                      ),
              ]),
            ),
          ),
        ],
      );
    },
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: ledgerSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ledgerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ledgerInk,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: ledgerMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: ledgerSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ledgerBorder),
    ),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: ledgerMuted),
      ),
    ),
  );
}

class BillTile extends StatelessWidget {
  const BillTile({
    super.key,
    required this.bill,
    required this.onTap,
    required this.onDelete,
  });
  final Bill bill;
  final VoidCallback onTap, onDelete;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: ledgerSurface,
      border: Border.all(color: ledgerBorder),
      borderRadius: BorderRadius.circular(15),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(12, 3, 4, 3),
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bill.manual
              ? const Color(0xFFE6F1EE)
              : const Color(0xFFFBE5DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          bill.manual ? Icons.add_card_outlined : Icons.receipt_long_outlined,
          color: bill.manual ? ledgerTeal : vermilion,
          size: 20,
        ),
      ),
      title: Text(
        bill.customer.isEmpty
            ? (bill.manual ? 'Other income' : 'Customer')
            : bill.customer,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ledgerInk,
          fontSize: 14,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${bill.manual ? 'Manual entry' : 'Invoice'}  ·  ${DateFormat('d MMM yyyy').format(bill.date)}',
          style: const TextStyle(color: ledgerMuted, fontSize: 11),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money.format(bill.total),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ledgerInk,
              fontSize: 12,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete this record?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (yes == true) onDelete();
              } else if (v == 'edit') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BillEditor(initial: bill, manual: bill.manual),
                  ),
                ).then((updated) {
                  if (updated is Bill) store.save(updated);
                });
              }
            },
            itemBuilder: (_) => [
              if (!bill.manual)
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    ),
  );
}

class BillEditor extends StatefulWidget {
  const BillEditor({super.key, this.initial, this.manual = false});
  final Bill? initial;
  final bool manual;
  @override
  State<BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends State<BillEditor> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      note = TextEditingController(),
      incomeAmount = TextEditingController(),
      count = TextEditingController();
  final List<Map<String, TextEditingController>> rows = [];
  bool tamil = false;
  bool get manual => widget.initial?.manual ?? widget.manual;
  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    tamil = b?.tamil ?? false;
    name.text = b?.customer ?? '';
    phone.text = b?.phone ?? '';
    note.text = b?.note ?? '';
    incomeAmount.text = b?.manual == true ? '${b!.total}' : '';
    final list = b?.items ?? [BillItem()];
    for (final i in list) {
      rows.add(_row(i));
    }
    count.text = '${rows.length}';
  }

  Map<String, TextEditingController> _row([BillItem? i]) => {
    'd': TextEditingController(text: i?.description ?? ''),
    'q': TextEditingController(text: i == null ? '1' : '${i.qty}'),
    'r': TextEditingController(text: i == null ? '' : '${i.rate}'),
  };
  double _total() => rows.fold(
    0,
    (sum, r) =>
        sum +
        ((double.tryParse(r['q']!.text) ?? 0) *
            (double.tryParse(r['r']!.text) ?? 0)),
  );
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    note.dispose();
    incomeAmount.dispose();
    count.dispose();
    for (final r in rows) {
      for (final c in r.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  String l(String en, String ta) => tamil ? ta : en;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.initial == null
            ? l(
                manual ? 'Add income' : 'Create invoice',
                manual ? 'வருமானம் சேர்க்க' : 'பில் உருவாக்கவும்',
              )
            : l('Edit invoice', 'பில்லை திருத்து'),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => tamil = !tamil),
          child: Text(tamil ? 'English' : 'தமிழ்'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
      children: [
        _Section(
          title: l('Customer details', 'வாடிக்கையாளர் விவரங்கள்'),
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: l(
                    manual ? 'Name / source (optional)' : 'Customer name',
                    manual
                        ? 'பெயர் / மூலம் (விருப்பம்)'
                        : 'வாடிக்கையாளர் பெயர்',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l(
                    'Phone number (optional)',
                    'தொலைபேசி எண் (விருப்பம்)',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (manual)
          _Section(
            title: l('Income details', 'வருமான விவரங்கள்'),
            child: Column(
              children: [
                TextField(
                  controller: incomeAmount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l('Amount (₹)', 'தொகை (₹)'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: l('Note', 'குறிப்பு')),
                ),
              ],
            ),
          ),
        if (!manual) ...[
          _Section(
            title: l('Items', 'பொருட்கள்'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l('Number of items', 'பொருட்களின் எண்ணிக்கை')}: ${rows.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: rows.length > 1
                          ? () {
                              setState(() {
                                final r = rows.removeLast();
                                for (final c in r.values) {
                                  c.dispose();
                                }
                                count.text = '${rows.length}';
                              });
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: rows.length < 15
                          ? () {
                              setState(() {
                                rows.add(_row());
                                count.text = '${rows.length}';
                              });
                            }
                          : null,
                      icon: const Icon(Icons.add_circle_outline, color: pink),
                    ),
                  ],
                ),
                TextField(
                  controller: count,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l(
                      'Set item count (1–15)',
                      'பொருட்களின் எண்ணிக்கை (1–15)',
                    ),
                  ),
                  onChanged: (v) {
                    final n = (int.tryParse(v) ?? rows.length).clamp(1, 15);
                    setState(() {
                      while (rows.length < n) {
                        rows.add(_row());
                      }
                      while (rows.length > n) {
                        final r = rows.removeLast();
                        for (final c in r.values) {
                          c.dispose();
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                ...rows.asMap().entries.map(
                  (entry) => _ItemRow(
                    index: entry.key,
                    row: entry.value,
                    tamil: tamil,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!manual)
          _Section(
            title: l('Invoice total', 'மொத்த தொகை'),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l('Total amount', 'மொத்த தொகை')),
                    Text(
                      money.format(_total()),
                      style: const TextStyle(
                        color: pink,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${l('In words', 'வார்த்தைகளில்')}: ${_amountWords(_total(), tamil)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: () {
              final items = manual
                  ? <BillItem>[]
                  : rows
                        .map(
                          (r) => BillItem(
                            description: r['d']!.text.trim(),
                            qty: double.tryParse(r['q']!.text) ?? 0,
                            rate: double.tryParse(r['r']!.text) ?? 0,
                          ),
                        )
                        .where((i) => i.description.isNotEmpty || i.amount > 0)
                        .toList();
              final total = manual
                  ? (double.tryParse(incomeAmount.text) ?? 0)
                  : _total();
              if (total <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l(
                        'Enter an amount greater than zero',
                        'பூஜ்ஜியத்தை விட அதிக தொகையை உள்ளிடவும்',
                      ),
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(
                context,
                Bill(
                  id:
                      widget.initial?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  customer: name.text.trim(),
                  phone: phone.text.trim(),
                  date: widget.initial?.date ?? DateTime.now(),
                  items: items,
                  total: total,
                  note: note.text.trim(),
                  manual: manual,
                  tamil: tamil,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: pink),
            child: Text(
              l(
                manual ? 'Save income' : 'Generate bill',
                manual ? 'வருமானத்தை சேமி' : 'பில் உருவாக்கு',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.index,
    required this.row,
    required this.tamil,
    required this.onChanged,
  });
  final int index;
  final Map<String, TextEditingController> row;
  final bool tamil;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    Widget field(String key, String en, String ta, {TextInputType? type}) =>
        TextField(
          controller: row[key],
          keyboardType: type,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(labelText: tamil ? ta : en),
        );
    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF4BDD0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${tamil ? 'பொருள்' : 'Item'} ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: pink,
                ),
              ),
              const Spacer(),
              Text(
                '$rupees${((double.tryParse(row['q']!.text) ?? 0) * (double.tryParse(row['r']!.text) ?? 0)).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          field('d', 'Description', 'விவரம்'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: field('q', 'Qty', 'அளவு', type: TextInputType.number),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  'r',
                  'Rate',
                  'விலை',
                  type: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.onEdit});
  final ValueChanged<Bill> onEdit;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String query = '';
  bool incomeOnly = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) {
      final list = store.bills
          .where(
            (b) =>
                (!incomeOnly || b.manual) &&
                ('${b.customer} ${b.phone}'.toLowerCase().contains(
                  query.toLowerCase(),
                )),
          )
          .toList();
      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const Text(
              'THE LEDGER',
              style: TextStyle(
                color: vermilion,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Bills & income',
              style: TextStyle(
                color: ledgerInk,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Every transaction, in one place.',
              style: TextStyle(color: ledgerMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ledgerSurface,
                border: Border.all(color: ledgerBorder),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricMini(
                      label: 'RECORDS',
                      value: '${store.bills.length}',
                      color: ledgerInk,
                    ),
                  ),
                  Container(width: 1, height: 40, color: ledgerBorder),
                  Expanded(
                    child: _MetricMini(
                      label: 'ALL TIME',
                      value: money.format(
                        store.bills.fold<double>(0, (sum, b) => sum + b.total),
                      ),
                      color: vermilion,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: ledgerMuted),
                hintText: 'Search name or phone',
                hintStyle: const TextStyle(color: ledgerMuted, fontSize: 13),
                filled: true,
                fillColor: ledgerSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: ledgerBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: ledgerBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FilterChip(
                  label: 'All records',
                  selected: !incomeOnly,
                  onTap: () => setState(() => incomeOnly = false),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Manual income',
                  selected: incomeOnly,
                  onTap: () => setState(() => incomeOnly = true),
                ),
                const Spacer(),
                Text(
                  '${list.length} shown',
                  style: const TextStyle(color: ledgerMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              const _EmptyState(text: 'No matching bills yet.')
            else
              ...list.map(
                (bill) => BillTile(
                  bill: bill,
                  onTap: () => showBillPreview(context, bill),
                  onDelete: () => store.remove(bill),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.onManual});
  final VoidCallback onManual;
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool weeklyView = false;
  int selectedWeek = 0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, _) {
      final monthBills = store.bills
          .where(
            (b) => b.date.year == month.year && b.date.month == month.month,
          )
          .toList();
      final monthly = monthBills.fold<double>(0, (s, b) => s + b.total);
      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final weekCount = (daysInMonth + 6) ~/ 7;
      final selectedWeekIndex = selectedWeek.clamp(0, weekCount - 1);
      final weeklyTotals = List<double>.generate(weekCount, (i) {
        final start = i * 7 + 1;
        final end = (start + 6).clamp(start, daysInMonth);
        return monthBills
            .where((b) => b.date.day >= start && b.date.day <= end)
            .fold<double>(0, (sum, b) => sum + b.total);
      });
      final weekStart = selectedWeekIndex * 7 + 1;
      final weekEnd = (weekStart + 6).clamp(weekStart, daysInMonth);
      final chartLabels = weeklyView
          ? List.generate(weekEnd - weekStart + 1, (i) {
              final date = DateTime(month.year, month.month, weekStart + i);
              return DateFormat('E').format(date).substring(0, 1);
            })
          : List.generate(weekCount, (i) => 'W${i + 1}');
      final chartValues = weeklyView
          ? List<double>.generate(weekEnd - weekStart + 1, (i) {
              final day = weekStart + i;
              return monthBills
                  .where((b) => b.date.day == day)
                  .fold<double>(0, (sum, b) => sum + b.total);
            })
          : weeklyTotals;
      final chartMax =
          (chartValues.fold<double>(0, (a, b) => a > b ? a : b) * 1.25)
              .clamp(100, double.infinity)
              .toDouble();
      final previousMonth = DateTime(month.year, month.month - 1);
      final previousTotal = store.bills
          .where(
            (b) =>
                b.date.year == previousMonth.year &&
                b.date.month == previousMonth.month,
          )
          .fold<double>(0, (sum, b) => sum + b.total);
      final changeText = previousTotal == 0
          ? (monthly > 0 ? 'New this month' : 'No change yet')
          : '${monthly >= previousTotal ? '+' : ''}${(((monthly - previousTotal) / previousTotal) * 100).toStringAsFixed(1)}% vs last month';
      final invoiceTotal = monthBills
          .where((b) => !b.manual)
          .fold<double>(0, (sum, b) => sum + b.total);
      final manualTotal = monthly - invoiceTotal;
      final categoryTotals = <String, double>{};
      for (final bill in monthBills) {
        if (bill.manual) {
          categoryTotals.update(
            'Manual income',
            (value) => value + bill.total,
            ifAbsent: () => bill.total,
          );
          continue;
        }
        var itemTotal = 0.0;
        for (final item in bill.items) {
          final label = item.description.trim().isEmpty
              ? 'Unlabelled item'
              : item.description.trim();
          itemTotal += item.amount;
          categoryTotals.update(
            label,
            (value) => value + item.amount,
            ifAbsent: () => item.amount,
          );
        }
        final remainder = bill.total - itemTotal;
        if (remainder > .009) {
          categoryTotals.update(
            'Other bill amount',
            (value) => value + remainder,
            ifAbsent: () => remainder,
          );
        }
      }
      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      const categoryColors = [
        vermilion,
        ledgerTeal,
        ledgerGold,
        ledgerLeaf,
        Color(0xFF7886A0),
      ];
      final categoryRows = sortedCategories.take(4).toList();
      final otherCategories = sortedCategories
          .skip(4)
          .fold<double>(0, (sum, entry) => sum + entry.value);
      if (otherCategories > 0) {
        categoryRows.add(MapEntry('Other', otherCategories));
      }
      final average = monthBills.isEmpty ? 0.0 : monthly / monthBills.length;
      final recentMonths = List.generate(
        6,
        (i) => DateTime(month.year, month.month - 5 + i),
      );
      final recentValues = recentMonths
          .map(
            (m) => store.bills
                .where((b) => b.date.year == m.year && b.date.month == m.month)
                .fold<double>(0, (sum, b) => sum + b.total),
          )
          .toList();
      final trendMax =
          (recentValues.fold<double>(0, (a, b) => a > b ? a : b) * 1.25)
              .clamp(100, double.infinity)
              .toDouble();
      final rangeText =
          '${DateFormat('d MMM').format(DateTime(month.year, month.month, weekStart))} – ${DateFormat('d MMM').format(DateTime(month.year, month.month, weekEnd))}';
      final selectedWeekTotal = weeklyTotals[selectedWeekIndex];

      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'THE LEDGER',
                        style: TextStyle(
                          color: vermilion,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Business overview',
                        style: TextStyle(
                          color: ledgerInk,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.6,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: ledgerInset),
                  onPressed: widget.onManual,
                  icon: const Icon(Icons.add, color: vermilion),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          month = DateTime(month.year, month.month - 1);
                          selectedWeek = 0;
                        }),
                        icon: const Icon(Icons.chevron_left, color: ledgerInk),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat('MMMM yyyy').format(month),
                            style: const TextStyle(
                              color: ledgerInk,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            month.year == DateTime.now().year &&
                                month.month == DateTime.now().month
                            ? null
                            : () => setState(() {
                                month = DateTime(month.year, month.month + 1);
                                selectedWeek = 0;
                              }),
                        icon: const Icon(Icons.chevron_right, color: ledgerInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'MONTHLY INCOME',
                    style: TextStyle(
                      color: Color(0xFFD9CDBA),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    money.format(monthly),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        previousTotal == 0 || monthly >= previousTotal
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: const Color(0xFFFF9A82),
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        changeText,
                        style: const TextStyle(
                          color: Color(0xFFFFB09D),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${monthBills.length} records',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0xFF3A4251)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DarkMetric(
                          label: 'GENERATED BILLS',
                          value: money.format(invoiceTotal),
                          dot: const Color(0xFFFF927B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DarkMetric(
                          label: 'MANUAL INCOME',
                          value: money.format(manualTotal),
                          dot: const Color(0xFF82C7B9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _LedgerCard(
                    child: _MetricMini(
                      label: 'BILLS THIS MONTH',
                      value: '${monthBills.length}',
                      color: ledgerInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LedgerCard(
                    child: _MetricMini(
                      label: 'AVERAGE RECORD',
                      value: money.format(average),
                      color: ledgerTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Income rhythm',
                    style: TextStyle(
                      color: ledgerInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFFFBE5DF)
                          : ledgerSurface,
                    ),
                    foregroundColor: WidgetStateProperty.all(ledgerInk),
                  ),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Month')),
                    ButtonSegment(value: true, label: Text('Week')),
                  ],
                  selected: {weeklyView},
                  onSelectionChanged: (selection) => setState(() {
                    weeklyView = selection.first;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          weeklyView ? 'Daily income' : 'Week by week',
                          style: const TextStyle(
                            color: ledgerInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        weeklyView
                            ? rangeText
                            : DateFormat('MMM').format(month),
                        style: const TextStyle(
                          color: ledgerMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (weeklyView) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: selectedWeekIndex == 0
                              ? null
                              : () => setState(() => selectedWeek--),
                          icon: const Icon(Icons.chevron_left, size: 19),
                        ),
                        Text(
                          'Week ${selectedWeek + 1} · ${money.format(selectedWeekTotal)}',
                          style: const TextStyle(
                            color: ledgerMuted,
                            fontSize: 11,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: selectedWeekIndex >= weekCount - 1
                              ? null
                              : () => setState(() => selectedWeek++),
                          icon: const Icon(Icons.chevron_right, size: 19),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 176,
                    child: chartValues.isEmpty
                        ? const Center(child: Text('No data for this period'))
                        : BarChart(
                            BarChartData(
                              maxY: chartMax,
                              alignment: BarChartAlignment.spaceAround,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                  color: ledgerBorder,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) =>
                                          BarTooltipItem(
                                            money.format(rod.toY),
                                            const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      return i >= 0 && i < chartLabels.length
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                chartLabels[i],
                                                style: const TextStyle(
                                                  color: ledgerMuted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            )
                                          : const SizedBox();
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (int i = 0; i < chartValues.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: chartValues[i],
                                        color: weeklyView
                                            ? ledgerTeal
                                            : vermilion,
                                        width: weeklyView ? 14 : 24,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                  if (!weeklyView) ...[
                    const SizedBox(height: 5),
                    for (int i = 0; i < weeklyTotals.length; i++)
                      _WeekRow(
                        label: 'Week ${i + 1}',
                        range:
                            '${i * 7 + 1}–${(i * 7 + 7).clamp(i * 7 + 1, daysInMonth)} ${DateFormat('MMM').format(month)}',
                        value: weeklyTotals[i],
                        maximum: monthly,
                        active: i == selectedWeekIndex,
                        onTap: () => setState(() {
                          selectedWeek = i;
                          weeklyView = true;
                        }),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Income by item & entry type',
                    style: TextStyle(
                      color: ledgerInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (monthly == 0 || categoryRows.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No income recorded for this month',
                          style: TextStyle(color: ledgerMuted),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 142,
                          height: 142,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 39,
                              sections: [
                                for (int i = 0; i < categoryRows.length; i++)
                                  PieChartSectionData(
                                    value: categoryRows[i].value,
                                    color: categoryColors[i],
                                    title:
                                        '${(categoryRows[i].value / monthly * 100).round()}%',
                                    radius: 26,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              for (int i = 0; i < categoryRows.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _SourceLegend(
                                  label: categoryRows[i].key,
                                  amount: categoryRows[i].value,
                                  color: categoryColors[i],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _LedgerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Six month trend',
                    style: TextStyle(
                      color: ledgerInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 155,
                    child: BarChart(
                      BarChartData(
                        maxY: trendMax,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              const FlLine(color: ledgerBorder, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                return i >= 0 && i < recentMonths.length
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Text(
                                          DateFormat('MMM')
                                              .format(recentMonths[i]),
                                          style: const TextStyle(
                                            color: ledgerMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      )
                                    : const SizedBox();
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < recentValues.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: recentValues[i],
                                  color: i == recentValues.length - 1
                                      ? vermilion
                                      : ledgerLeaf,
                                  width: 17,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onManual,
              style: FilledButton.styleFrom(
                backgroundColor: vermilion,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text(
                'Record new income',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        const Text(
          'YOUR WORKSPACE',
          style: TextStyle(
            color: vermilion,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Settings',
          style: TextStyle(
            color: ledgerInk,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your shop details and app preferences.',
          style: TextStyle(color: ledgerMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _LedgerCard(
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: ledgerInset,
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/vin.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.content_cut, color: vermilion),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GM TAILORS',
                      style: TextStyle(
                        color: ledgerInk,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Morai, Chennai',
                      style: TextStyle(color: ledgerMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.checkroom_outlined, color: ledgerTeal),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsRow(
          icon: Icons.translate,
          title: 'Invoice language',
          subtitle: 'Choose English or Tamil when creating each bill',
        ),
        _SettingsRow(
          icon: Icons.storage_outlined,
          title: 'Your bill records',
          subtitle: 'Saved on this device and available in History',
        ),
        _SettingsRow(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Bill template',
          subtitle: 'Original GM Tailors invoice layout is preserved',
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'GM Tailors Bills  ·  Version 1.0.0',
            style: TextStyle(color: ledgerMuted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ledgerSurface,
      border: Border.all(color: ledgerBorder),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ledgerInset,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: vermilion, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ledgerInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: ledgerMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ledgerSurface,
      border: Border.all(color: ledgerBorder),
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A141B2D),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _MetricMini extends StatelessWidget {
  const _MetricMini({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ledgerMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({
    required this.label,
    required this.value,
    required this.dot,
  });
  final String label, value;
  final Color dot;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SourceLegend extends StatelessWidget {
  const _SourceLegend({
    required this.label,
    required this.amount,
    required this.color,
  });
  final String label;
  final double amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: ledgerMuted, fontSize: 10),
            ),
            const SizedBox(height: 3),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                money.format(amount),
                style: const TextStyle(
                  color: ledgerInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.label,
    required this.range,
    required this.value,
    required this.maximum,
    required this.active,
    required this.onTap,
  });
  final String label, range;
  final double value, maximum;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: TextStyle(
                color: active ? vermilion : ledgerInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range,
                  style: const TextStyle(color: ledgerMuted, fontSize: 9),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: maximum == 0 ? 0 : (value / maximum).clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: ledgerInset,
                    color: active ? vermilion : ledgerTeal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 85,
            child: Text(
              money.format(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ledgerInk,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? ledgerInk : ledgerSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? ledgerInk : ledgerBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : ledgerMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Future<void> showBillPreview(BuildContext context, Bill bill) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BillPreview(bill: bill),
  );
}

Future<void> _editBill(BuildContext context, Bill bill) async {
  final navigator = Navigator.of(context);
  navigator.pop();
  final updated = await navigator.push<Bill>(
    MaterialPageRoute(
      builder: (_) => BillEditor(initial: bill, manual: bill.manual),
    ),
  );
  if (updated != null) await store.save(updated);
}

class BillPreview extends StatelessWidget {
  const BillPreview({super.key, required this.bill});
  final Bill bill;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .92,
    maxChildSize: .97,
    builder: (context, sc) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bill preview',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit bill',
                  onPressed: () => _editBill(context, bill),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: InvoicePaper(bill: bill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _printBill(bill),
                icon: const Icon(Icons.download),
                label: const Text('Download / Print PDF'),
                style: FilledButton.styleFrom(backgroundColor: pink),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class InvoicePaper extends StatelessWidget {
  const InvoicePaper({super.key, required this.bill});
  final Bill bill;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: const [
        BoxShadow(
          color: Color(0x17000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      border: Border.all(color: const Color(0xFFF4BDD0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          'assets/vin.jpg',
          height: 48,
          errorBuilder: (_, _, _) => const SizedBox(height: 10),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 48,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
            const SizedBox(width: 8),
            const Text(
              'GM TAILORS',
              style: TextStyle(
                color: pink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'ஸ்ரீ முனிஸ்வரர் துணை\nPlot no 62, 3rd cross street, bethel garden, anna nagar, morai chennai-55\n9043943533, 9003770263 · GMtailor9021@gmail.com',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, height: 1.5),
        ),
        const SizedBox(height: 18),
        Text(
          bill.tamil ? 'வாடிக்கையாளர் விவரங்கள்' : 'Customer Details',
          style: TextStyle(
            color: pink,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const Divider(color: pink),
        Text('${bill.tamil ? 'பெயர்' : 'Name'}: ${bill.customer}'),
        Text('${bill.tamil ? 'தொலைபேசி எண்' : 'Phone'}: ${bill.phone}'),
        Text(
          DateFormat('dd MMM yyyy').format(bill.date),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 14),
        if (!bill.manual)
          Table(
            border: TableBorder.all(color: const Color(0xFFF4BDD0)),
            columnWidths: const {
              0: FixedColumnWidth(30),
              1: FlexColumnWidth(4),
              2: FixedColumnWidth(38),
              3: FixedColumnWidth(68),
              4: FixedColumnWidth(78),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFFFF8FA)),
                children:
                    (bill.tamil
                            ? ['வ.எண்', 'விவரம்', 'அளவு', 'விலை', 'தொகை']
                            : [
                                'Sl.No.',
                                'Description',
                                'Qty.',
                                'Rate',
                                'Amount',
                              ])
                        .map(
                          (x) => Padding(
                            padding: const EdgeInsets.all(5),
                            child: Text(
                              x,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              ...bill.items.asMap().entries.map(
                (e) => TableRow(
                  children:
                      [
                            (e.key + 1).toString(),
                            e.value.description,
                            '${e.value.qty}',
                            money.format(e.value.rate),
                            money.format(e.value.amount),
                          ]
                          .map(
                            (x) => Padding(
                              padding: const EdgeInsets.all(5),
                              child: Text(
                                x,
                                style: const TextStyle(fontSize: 8),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        if (bill.manual)
          Text('${bill.tamil ? 'வருமானம்' : 'Manual income'} · ${bill.note}'),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${bill.tamil ? 'மொத்தம்' : 'Total'}: ${money.format(bill.total)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: pink,
              fontSize: 14,
            ),
          ),
        ),
        const Divider(color: pink),
        Text(
          '${bill.tamil ? 'வார்த்தைகளில்' : 'Rupees in words'}: ${_amountWords(bill.total, bill.tamil)}',
          style: const TextStyle(fontSize: 9),
        ),
        if (!bill.manual) ...[
          const SizedBox(height: 22),
          Text(
            bill.tamil ? 'இணைய வழி பணம்:' : 'Online Payment:',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Center(
            child: Image.asset(
              'assets/gpay.png',
              height: 115,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
          ),
        ],
      ],
    ),
  );
}

Future<void> _printBill(Bill b) async {
  final doc = pw.Document();
  final tamilFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil.ttf'),
  );
  final logo = await imageFromAssetBundle('assets/logo.png')
      .catchError((_) => pw.MemoryImage(Uint8List(0)));
  final deity = await imageFromAssetBundle('assets/vin.jpg')
      .catchError((_) => pw.MemoryImage(Uint8List(0)));
  final qr = await imageFromAssetBundle('assets/gpay.png')
      .catchError((_) => pw.MemoryImage(Uint8List(0)));
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(base: tamilFont, bold: tamilFont),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#F4BDD0')),
        ),
        padding: const pw.EdgeInsets.all(22),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Image(deity, height: 55)),
            pw.SizedBox(height: 7),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(logo, height: 50),
                pw.SizedBox(width: 10),
                pw.Text(
                  'GM TAILORS',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#E91E63'),
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'ஸ்ரீ முனிஸ்வரர் துணை\nPlot no 62, 3rd cross street, bethel garden, anna nagar, morai chennai-55\n9043943533, 9003770263 · GMtailor9021@gmail.com',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              b.tamil ? 'வாடிக்கையாளர் விவரங்கள்' : 'Customer Details',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#E91E63'),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Divider(color: PdfColor.fromHex('#F4BDD0')),
            pw.Text('${b.tamil ? 'பெயர்' : 'Name'}: ${b.customer}'),
            pw.Text('${b.tamil ? 'தொலைபேசி எண்' : 'Phone'}: ${b.phone}'),
            pw.Text(
              DateFormat('dd MMM yyyy').format(b.date),
              textAlign: pw.TextAlign.right,
            ),
            pw.SizedBox(height: 12),
            if (!b.manual)
              pw.TableHelper.fromTextArray(
                headers: b.tamil
                    ? ['வ.எண்', 'விவரம்', 'அளவு', 'விலை', 'தொகை']
                    : ['Sl.No.', 'Description', 'Qty.', 'Rate', 'Amount'],
                data: b.items
                    .asMap()
                    .entries
                    .map(
                      (e) => [
                        (e.key + 1).toString(),
                        e.value.description,
                        '${e.value.qty}',
                        money.format(e.value.rate),
                        money.format(e.value.amount),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                border: pw.TableBorder.all(color: PdfColor.fromHex('#F4BDD0')),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF8FA'),
                ),
              ),
            if (b.manual)
              pw.Text('${b.tamil ? 'வருமானம்' : 'Manual income'}: ${b.note}'),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${b.tamil ? 'மொத்தம்' : 'Total'}: ${money.format(b.total)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 15,
                  color: PdfColor.fromHex('#E91E63'),
                ),
              ),
            ),
            pw.Divider(color: PdfColor.fromHex('#F4BDD0')),
            pw.Text(
              '${b.tamil ? 'வார்த்தைகளில்' : 'Rupees in words'}: ${_amountWords(b.total, b.tamil)}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Spacer(),
            if (!b.manual)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    b.tamil ? 'இணைய வழி பணம்:' : 'Online Payment:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Image(qr, height: 100),
                ],
              ),
          ],
        ),
      ),
    ),
  );
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

String _amountWords(double v, bool tamil) {
  final whole = v.floor();
  if (tamil) return 'ரூபாய் $whole மட்டும்';
  if (whole == 0) return 'Zero Rupees Only';
  if (whole < 1000) return '${_under1000(whole)} Rupees Only';
  return '$whole Rupees Only';
}

String _under1000(int n) {
  const ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];
  if (n < 20) return ones[n];
  if (n < 100) {
    return '${tens[n ~/ 10]}${n % 10 == 0 ? '' : ' ${ones[n % 10]}'}';
  }
  return '${ones[n ~/ 100]} Hundred${n % 100 == 0 ? '' : ' ${_under1000(n % 100)}'}';
}
