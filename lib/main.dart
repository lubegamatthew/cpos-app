import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
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
      ),
      home: const POSDashboard(),
    );
  }
}

class POSDashboard extends StatefulWidget {
  const POSDashboard({super.key});

  @override
  State<POSDashboard> createState() => _POSDashboardState();
}

class Order {
  final String id;
  final String customer;
  final double amount;
  final String status;

  Order({
    required this.id,
    required this.customer,
    required this.amount,
    required this.status,
  });
}

class _POSDashboardState extends State<POSDashboard> {
  int _selectedIndex = 0;
  bool _sidebarOpen = false;
  bool _financialReportsExpanded = false;

  final List<Order> _recentOrders = [
    Order(id: '#1001', customer: 'John Smith', amount: 125000, status: 'Completed'),
    Order(id: '#1002', customer: 'Sarah Johnson', amount: 285000, status: 'Completed'),
    Order(id: '#1003', customer: 'Mike Wilson', amount: 45000, status: 'Pending'),
    Order(id: '#1004', customer: 'Emma Davis', amount: 187500, status: 'Completed'),
    Order(id: '#1005', customer: 'Alex Brown', amount: 68000, status: 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Point of Sale',
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderStats(),
                const SizedBox(height: 24),
                _buildSectionHeader('Quick Actions', onViewAll: () {}),
                const SizedBox(height: 12),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildSectionHeader('Recent Orders'),
                const SizedBox(height: 12),
                _buildRecentOrders(),
              ],
            ),
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
      bottomNavigationBar: NavigationBar(
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
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Reports',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
      ),
    );
  }

  Widget _buildHeaderStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          title: 'Today\'s Revenue',
          value: 'UGX 4,581,250',
          trend: '+12% from yesterday',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Total Orders',
          value: '24',
          trend: '+8% from yesterday',
          icon: Icons.shopping_cart_outlined,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Customers',
          value: '18',
          trend: '+5 new today',
          icon: Icons.people_outline,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Low Stock Items',
          value: '3',
          trend: 'Need attention',
          icon: Icons.inventory_2_outlined,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View All')),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _QuickActionItem(
              icon: Icons.point_of_sale,
              label: 'New Sale',
              color: Theme.of(context).colorScheme.primary,
            ),
            _QuickActionItem(
              icon: Icons.receipt_long,
              label: 'Invoices',
              color: Colors.indigo,
            ),
            _QuickActionItem(
              icon: Icons.people,
              label: 'Customers',
              color: Colors.teal,
            ),
            _QuickActionItem(
              icon: Icons.inventory,
              label: 'Inventory',
              color: Colors.amber,
            ),
            _QuickActionItem(
              icon: Icons.category,
              label: 'Categories',
              color: Colors.deepOrange,
            ),
            _QuickActionItem(
              icon: Icons.payment,
              label: 'Payments',
              color: Colors.green,
            ),
            _QuickActionItem(
              icon: Icons.bar_chart,
              label: 'Reports',
              color: Colors.purple,
            ),
            _QuickActionItem(
              icon: Icons.settings,
              label: 'Settings',
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentOrders.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final order = _recentOrders[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(order.status).withValues(alpha: 0.1),
              child: Icon(
                Icons.receipt_outlined,
                color: _getStatusColor(order.status),
              ),
            ),
            title: Text(
              '${order.id} - ${order.customer}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              order.status,
              style: TextStyle(
                color: _getStatusColor(order.status),
                fontSize: 12,
              ),
            ),
            trailing: Text(
              'UGX ${order.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          );
        },
      ),
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
            padding: const EdgeInsets.all(24),
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                  icon: Icons.inventory_2_outlined,
                  title: 'Products',
                  selected: _selectedIndex == 2,
                  onTap: () => _selectNavItem(2),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  selected: _selectedIndex == 3,
                  onTap: () => _selectNavItem(3),
                ),
                _FinancialReportsDropdown(
                  expanded: _financialReportsExpanded,
                  onToggle: () {
                    setState(() {
                      _financialReportsExpanded = !_financialReportsExpanded;
                    });
                  },
                ),
                if (_financialReportsExpanded) ...[
                  _SidebarSubItem(
                    icon: Icons.account_balance_outlined,
                    title: 'Balance Sheet',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.trending_up_outlined,
                    title: 'Income Statement',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.attach_money_outlined,
                    title: 'Cash Flow Statement',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.bar_chart_outlined,
                    title: 'Profit & Loss',
                    onTap: () {},
                  ),
                  _SidebarSubItem(
                    icon: Icons.assessment_outlined,
                    title: 'Sales Report',
                    onTap: () {},
                  ),
                ],
                _SidebarItem(
                  icon: Icons.people_outline,
                  title: 'Customers',
                  selected: false,
                  onTap: () {},
                ),
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
  final String trend;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
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
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _FinancialReportsDropdown extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _FinancialReportsDropdown({
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.bar_chart_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        'Financial Reports',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        expanded ? Icons.expand_less : Icons.expand_more,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onToggle,
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
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      onTap: onTap,
    );
  }
}