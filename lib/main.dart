import 'package:flutter/material.dart';

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

  final List<Order> _recentOrders = [
    Order(id: '#1001', customer: 'John Smith', amount: 45.50, status: 'Completed'),
    Order(id: '#1002', customer: 'Sarah Johnson', amount: 78.25, status: 'Completed'),
    Order(id: '#1003', customer: 'Mike Wilson', amount: 32.00, status: 'Pending'),
    Order(id: '#1004', customer: 'Emma Davis', amount: 95.75, status: 'Completed'),
    Order(id: '#1005', customer: 'Alex Brown', amount: 18.50, status: 'Completed'),
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
      body: SingleChildScrollView(
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
          value: '\$1,245.50',
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
              '\$${order.amount}',
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