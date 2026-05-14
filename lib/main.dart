import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/inventory_page.dart';
import 'pages/loading_page.dart';
import 'pages/pos_page.dart';
import 'pages/sales_page.dart';
import 'db_helper.dart';
import 'sales_bus.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      log(
        'Flutter Error: ${details.exception}',
        name: 'cpos',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    runApp(const MyApp());
  }, (error, stack) {
    log(
      'Unhandled Exception: $error',
      name: 'cpos',
      error: error,
      stackTrace: stack,
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

@override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPOS - Point of Sale',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStatePropertyAll(
            const TextStyle(fontSize: 10),
          ),
        ),
      ),
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const LoadingPage(),
        '/dashboard': (context) => const POSDashboard(),
      },
    );
  }
}

class POSDashboard extends StatefulWidget {
  const POSDashboard({super.key});

  @override
  State<POSDashboard> createState() => _POSDashboardState();
}

class InventoryItem {
  String id;
  String name;
  String category;
  int quantity;
  double buyPrice;
  double sellPrice;
  String unit;
  String description;
  DateTime createdAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.buyPrice,
    required this.sellPrice,
    this.unit = 'pcs',
    this.description = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
      'unit': unit,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
      buyPrice: map['buyPrice'],
      sellPrice: map['sellPrice'],
      unit: map['unit'] ?? 'pcs',
      description: map['description'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? buyPrice,
    double? sellPrice,
    String? unit,
    String? description,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  double get totalCost => quantity * buyPrice;
  double get totalSell => quantity * sellPrice;
  double get profit => totalSell - totalCost;
}

enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense,
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double debit;
  final double credit;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.debit = 0,
    this.credit = 0,
  });

  double get balance {
    switch (type) {
      case AccountType.asset:
      case AccountType.expense:
        return debit - credit;
      case AccountType.liability:
      case AccountType.equity:
      case AccountType.revenue:
        return credit - debit;
    }
  }
}

class JournalEntry {
  final String id;
  final DateTime date;
  final String description;
  final List<EntryLine> lines;

  JournalEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.lines,
  });

  void validate() {
    final totalDebit = lines.where((l) => l.isDebit).fold(0.0, (sum, l) => sum + l.amount);
    final totalCredit = lines.where((l) => !l.isDebit).fold(0.0, (sum, l) => sum + l.amount);
    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception('Journal entry does not balance: Debit=$totalDebit, Credit=$totalCredit');
    }
  }
}

class EntryLine {
  final String accountId;
  final double amount;
  final bool isDebit;

  EntryLine({
    required this.accountId,
    required this.amount,
    required this.isDebit,
  });
}

class AccountingService {
  final Map<String, Account> _accounts = {};
  final List<JournalEntry> _journalEntries = [];

  void addAccount(Account account) {
    _accounts[account.id] = account;
  }

  void addJournalEntry(JournalEntry entry) {
    entry.validate();
    _journalEntries.add(entry);
  }

  Account? getAccount(String id) => _accounts[id];

  List<Account> getAccountsByType(AccountType type) {
    return _accounts.values.where((a) => a.type == type).toList();
  }

  double getTotalAssets() {
    return getAccountsByType(AccountType.asset).fold(0.0, (sum, a) => sum + a.balance);
  }

  double getTotalLiabilities() {
    return getAccountsByType(AccountType.liability).fold(0.0, (sum, a) => sum + a.balance);
  }

  double getTotalEquity() {
    return getAccountsByType(AccountType.equity).fold(0.0, (sum, a) => sum + a.balance);
  }

  double getTotalRevenue() {
    return getAccountsByType(AccountType.revenue).fold(0.0, (sum, a) => sum + a.balance);
  }

  double getTotalExpenses() {
    return getAccountsByType(AccountType.expense).fold(0.0, (sum, a) => sum + a.balance);
  }

  double getNetIncome() {
    return getTotalRevenue() - getTotalExpenses();
  }

  bool isTrialBalanceBalanced() {
    final totalDebits = _accounts.values.fold(0.0, (sum, a) {
      if (a.type == AccountType.asset || a.type == AccountType.expense) {
        return sum + a.debit;
      }
      return sum;
    });
    final totalCredits = _accounts.values.fold(0.0, (sum, a) {
      if (a.type == AccountType.liability || a.type == AccountType.equity || a.type == AccountType.revenue) {
        return sum + a.credit;
      }
      return sum;
    });
    return (totalDebits - totalCredits).abs() < 0.01;
  }
}

class _POSDashboardState extends State<POSDashboard> {
  int _selectedIndex = 0;
  bool _sidebarOpen = false;
  bool _financialReportsExpanded = false;
  bool _lowStockExpanded = false;
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  Map<String, dynamic> _stats = {
    'todaySales': 0.0,
    'todayOrders': 0,
    'itemsSold': 0,
    'lowStock': 0,
    'weeklyProfit': 0.0,
  };
  final SalesBus _salesBus = SalesBus();

  @override
  void initState() {
    super.initState();
    _salesBus.addListener(_onSalesUpdated);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _salesBus.removeListener(_onSalesUpdated);
    super.dispose();
  }

  void _onSalesUpdated() {
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final orders = await DatabaseHelper.instance.getAllOrders();
    final inventory = await DatabaseHelper.instance.getAllInventoryItems();
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    // Today's stats
    double todaySales = 0;
    int todayOrders = 0;
    int itemsSold = 0;
    
    for (final order in orders) {
      final createdAt = DateTime.tryParse(order['createdAt'] ?? '');
      if (createdAt != null && createdAt.isAfter(todayStart)) {
        todaySales += (order['totalAmount'] as double);
        todayOrders += 1;
      }
    }
    
    // Calculate items sold today
    for (final order in orders) {
      final createdAt = DateTime.tryParse(order['createdAt'] ?? '');
      if (createdAt != null && createdAt.isAfter(todayStart)) {
        final items = await DatabaseHelper.instance.getOrderItems(order['id']);
        for (final item in items) {
          itemsSold += (item['quantity'] as int);
        }
      }
    }
    
    // Low stock items (quantity < 10)
    final lowStockItems = inventory.where((item) => (item['quantity'] as int) < 10).toList();
    
    // Weekly profit
    double weeklyProfit = 0;
    for (final order in orders) {
      final createdAt = DateTime.tryParse(order['createdAt'] ?? '');
      if (createdAt != null && createdAt.isAfter(weekStartDate)) {
        weeklyProfit += (order['totalProfit'] as double);
      }
    }
    
    // Recent orders (most recent 5)
    final recentOrders = orders.take(5).toList();
    
    if (!mounted) return;
    
    setState(() {
      _recentOrders = recentOrders;
      _lowStockItems = lowStockItems;
      _stats = {
        'todaySales': todaySales,
        'todayOrders': todayOrders,
        'itemsSold': itemsSold,
        'lowStock': lowStockItems.length,
        'weeklyProfit': weeklyProfit,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'POS',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _sidebarOpen = true;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
children: [
                  _buildDashboardBody(),
                  _buildPosBody(),
                  _buildInventoryBody(),
                  _buildSalesBody(),
                  _buildReportsBody(),
                  _buildExpensesBody(),
                ],
          ),
          if (_sidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _sidebarOpen = false),
              child: Container(
                color: Colors.black54,
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _sidebarOpen ? 0 : -280,
            top: 0,
            bottom: 0,
            child: _buildSidebar(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedIndex == 0
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
destinations: const [
                 NavigationDestination(
                   icon: Icon(Icons.dashboard_outlined),
                   label: 'Dashboard',
                 ),
                 NavigationDestination(
                   icon: Icon(Icons.point_of_sale_outlined),
                   label: 'POS',
                 ),
                 NavigationDestination(
                   icon: Icon(Icons.inventory_outlined),
                   label: 'Inventory',
                 ),
                 NavigationDestination(
                   icon: Icon(Icons.receipt_long_outlined),
                   label: 'Sales',
                 ),
                 NavigationDestination(
                   icon: Icon(Icons.bar_chart_outlined),
                   label: 'Reports',
                 ),
                 NavigationDestination(
                   icon: Icon(Icons.money_outlined),
                   label: 'Expenses',
                 ),
               ],
            )
          : null,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CPOS',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Point of Sale System',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const ClampingScrollPhysics(),
              cacheExtent: 500.0,
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  selected: _selectedIndex == 0,
                  onTap: () => _selectNavItem(0),
                ),
                _SidebarItem(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Point of Sale',
                  selected: _selectedIndex == 1,
                  onTap: () => _selectNavItem(1),
                ),
_SidebarItem(
                   icon: Icons.inventory_outlined,
                   title: 'Inventory',
                   selected: _selectedIndex == 2,
                   onTap: () => _selectNavItem(2),
                 ),
                 _SidebarItem(
                   icon: Icons.receipt_long_outlined,
                   title: 'Sales',
                   selected: _selectedIndex == 3,
                   onTap: () => _selectNavItem(3),
                 ),
                _SidebarItem(
                  icon: Icons.attach_money_outlined,
                  title: 'Expenses',
                  selected: _selectedIndex == 4,
                  onTap: () => _selectNavItem(4),
                ),
                _SidebarItem(
                  icon: Icons.bar_chart_outlined,
                  title: 'Financial Reports',
                  selected: false,
                  onTap: () {
                    setState(() {
                      _financialReportsExpanded = !_financialReportsExpanded;
                    });
                  },
                  trailing: Icon(
                    _financialReportsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_financialReportsExpanded) ...[
                  _SidebarSubItem(
                    icon: Icons.account_balance_outlined,
                    title: 'Balance Sheet',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.trending_up_outlined,
                    title: 'Profit & Loss Statement',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.attach_money_outlined,
                    title: 'Cash Flow Statement',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.assessment_outlined,
                    title: 'Sales Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.inventory_outlined,
                    title: 'Stock Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.people_outline,
                    title: 'Debtors Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.people_outline,
                    title: 'Creditors Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.money_outlined,
                    title: 'Expense Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'Daily Transaction Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Purchase Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Low Stock Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.swap_horiz_outlined,
                    title: 'Stock Movement Report',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.scale_outlined,
                    title: 'Trial Balance',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.description_outlined,
                    title: 'General Ledger',
                    onTap: () {},
                  ),
                ],
                 _SidebarItem(
                   icon: Icons.category_outlined,
                   title: 'Categories',
                   selected: false,
                   onTap: () {},
                 ),
                 _SidebarItem(
                   icon: Icons.payment_outlined,
                   title: 'Payments',
                   selected: false,
                   onTap: () {},
                 ),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Low Stock',
                  selected: _lowStockExpanded,
                   onTap: () {
                     setState(() {
                       _lowStockExpanded = !_lowStockExpanded;
                     });
                   },
                  trailing: _lowStockItems.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Text(
                            '${_lowStockItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : null,
                ),
                  if (_lowStockExpanded) ...[
                    ..._lowStockItems.map((item) {
                      final quantity = item['quantity'] as int;
                      final isCritical = quantity <= 5;
                      return _SidebarSubItem(
                        icon: isCritical ? Icons.error_outline : Icons.warning_amber_outlined,
                        title: '${item['name']} ($quantity left)',
                        onTap: () {},
                      );
                    }),
                  ],
                 _SidebarItem(
                   icon: Icons.settings_outlined,
                   title: 'Settings',
                   selected: false,
                   onTap: () {},
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and time header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    DateTime.now().toString().split(' ')[0],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.point_of_sale,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'CPOS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick stats grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                title: 'Today\'s Sales',
                value: 'UGX ${(_stats['todaySales'] as double).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                icon: Icons.attach_money,
                color: Colors.green,
                subtitle: '${_stats['todayOrders']} sale(s)',
              ),
              _StatCard(
                title: 'Items Sold',
                value: '${_stats['itemsSold']}',
                icon: Icons.shopping_bag_outlined,
                color: Colors.blue,
                subtitle: 'Today',
              ),
              _StatCard(
                title: 'Low Stock',
                value: '${_stats['lowStock']}',
                icon: Icons.inventory_2_outlined,
                color: Colors.orange,
                subtitle: 'Items below threshold',
              ),
              _StatCard(
                title: 'Weekly Profit',
                value: 'UGX ${(_stats['weeklyProfit'] as double).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                icon: Icons.trending_up,
                color: Colors.purple,
                subtitle: 'This week',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Sales',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: _recentOrders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No recent sales',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentOrders.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final order = _recentOrders[index];
                      final createdAt = DateTime.tryParse(order['createdAt'] ?? '');
                      final formattedDate = createdAt != null
                          ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year.toString().substring(2)}'
                          : 'N/A';
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(order['status'] ?? 'Completed').withValues(alpha: 0.1),
                          child: Icon(
                            Icons.receipt_outlined,
                            color: _getStatusColor(order['status'] ?? 'Completed'),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${order['id']} - ${order['customerName']}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        subtitle: Text(
                          formattedDate,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Text(
                          'UGX ${(order['totalAmount'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildPosBody() {
    return const PosPage();
  }

Widget _buildInventoryBody() {
     return const InventoryPage();
   }

   Widget _buildSalesBody() {
     return const SalesPage();
   }

  Widget _buildReportsBody() {
    return const Center(
      child: Text('Reports - Coming Soon'),
    );
  }

  Widget _buildExpensesBody() {
    return const Center(
      child: Text('Expenses - Coming Soon'),
    );
  }

  void _selectNavItem(int index) {
    setState(() {
      _selectedIndex = index;
      _sidebarOpen = false;
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: trailing,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _SidebarSubItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SidebarSubItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: Icon(
        icon,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      onTap: onTap,
    );
  }
}