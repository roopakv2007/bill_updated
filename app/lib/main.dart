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
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      colorScheme: ColorScheme.fromSeed(seedColor: pink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F6F8),
        foregroundColor: ink,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4BDD0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF4BDD0)),
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
      const AnalyticsPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => create(),
              backgroundColor: pink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New bill'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
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
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monthBills = store.bills
        .where((b) => b.date.year == today.year && b.date.month == today.month)
        .toList();
    final total = monthBills.fold<double>(0, (v, b) => v + b.total);
    return AnimatedBuilder(
      animation: store,
      builder: (_, _) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Image.asset(
                      'assets/vin.jpg',
                      width: 38,
                      height: 38,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.content_cut, color: pink, size: 34),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GM TAILORS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: pink,
                            ),
                          ),
                          Text(
                            'Bills & business overview',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onHistory,
                      icon: const Icon(Icons.history),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [pink, Color(0xFFAD1457)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(today),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        money.format(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${monthBills.length} bills recorded this month',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.receipt_long,
                        title: 'Create bill',
                        subtitle: 'Generate invoice',
                        color: pink,
                        onTap: onCreate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_card,
                        title: 'Add income',
                        subtitle: 'No bill needed',
                        color: green,
                        onTap: onManual,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent bills',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    TextButton(
                      onPressed: onHistory,
                      child: const Text('See all'),
                    ),
                  ],
                ),
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
      ),
    );
  }
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEEF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
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
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: bill.manual
            ? const Color(0xFFEAF4DF)
            : const Color(0xFFFCE4EC),
        child: Icon(
          bill.manual ? Icons.add_card : Icons.receipt_long,
          color: bill.manual ? green : pink,
        ),
      ),
      title: Text(
        bill.customer.isEmpty
            ? (bill.manual ? 'Other income' : 'Customer')
            : bill.customer,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${bill.manual ? 'Manual entry' : 'Invoice'} · ${DateFormat('d MMM yyyy').format(bill.date)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money.format(bill.total),
            style: const TextStyle(fontWeight: FontWeight.w800),
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
        appBar: AppBar(title: const Text('Bill history')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search customer or phone',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Text('Show manual income'),
                  const Spacer(),
                  Switch(
                    value: incomeOnly,
                    onChanged: (v) => setState(() => incomeOnly = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: _EmptyState(text: 'No matching bills yet.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: list.length,
                      itemBuilder: (_, i) => BillTile(
                        bill: list[i],
                        onTap: () => showBillPreview(context, list[i]),
                        onDelete: () => store.remove(list[i]),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final monthBills = store.bills
        .where((b) => b.date.year == month.year && b.date.month == month.month)
        .toList();
    final monthly = monthBills.fold<double>(0, (s, b) => s + b.total);
    final buckets = List<double>.filled(5, 0);
    for (final b in monthBills) {
      buckets[((b.date.day - 1) ~/ 7).clamp(0, 4)] += b.total;
    }
    final maxY = (buckets.fold<double>(0, (a, b) => a > b ? a : b) * 1.25)
        .clamp(100, double.infinity)
        .toDouble();
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    final monthValues = months
        .map(
          (m) => store.bills
              .where((b) => b.date.year == m.year && b.date.month == m.month)
              .fold<double>(0, (s, b) => s + b.total),
        )
        .toList();
    return AnimatedBuilder(
      animation: store,
      builder: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Business analysis')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 25),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: month.year == now.year && month.month == now.month
                      ? null
                      : () => setState(
                          () => month = DateTime(month.year, month.month + 1),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            _Section(
              title: 'Monthly total',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    money.format(monthly),
                    style: const TextStyle(
                      color: pink,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${monthBills.length} records · ${monthBills.where((b) => b.manual).length} manual income entries',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Week by week',
              child: SizedBox(
                height: 190,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
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
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'W${v.toInt() + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < 5; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: buckets[i],
                              color: pink,
                              width: 22,
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
            ),
            _Section(
              title: 'Income sources',
              child: SizedBox(
                height: 180,
                child: monthBills.isEmpty
                    ? const Center(child: Text('No data for this month'))
                    : Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: monthBills
                                        .where((b) => !b.manual)
                                        .fold<double>(0, (s, b) => s + b.total),
                                    color: pink,
                                    title: 'Bills',
                                    radius: 52,
                                  ),
                                  PieChartSectionData(
                                    value: monthBills
                                        .where((b) => b.manual)
                                        .fold<double>(0, (s, b) => s + b.total),
                                    color: green,
                                    title: 'Manual',
                                    radius: 52,
                                  ),
                                ],
                                sectionsSpace: 3,
                                centerSpaceRadius: 35,
                              ),
                            ),
                          ),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '●  Generated bills',
                                style: TextStyle(color: pink),
                              ),
                              SizedBox(height: 12),
                              Text(
                                '●  Manual income',
                                style: TextStyle(color: green),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            _Section(
              title: 'Monthly trend · last 6 months',
              child: SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY:
                        (monthValues.fold<double>(0, (a, b) => a > b ? a : b) *
                                1.2)
                            .clamp(100, double.infinity)
                            .toDouble(),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
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
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            return i >= 0 && i < months.length
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      DateFormat('MMM').format(months[i]),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  )
                                : const SizedBox();
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: monthValues[i],
                              color: green,
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
            ),
          ],
        ),
      ),
    );
  }
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
