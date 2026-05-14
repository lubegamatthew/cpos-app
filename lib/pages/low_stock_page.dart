import 'package:flutter/material.dart';
import '../main.dart';
import '../db_helper.dart';
import '../pages/inventory_page.dart';

class LowStockPage extends StatefulWidget {
  const LowStockPage({super.key});

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> {
  List<InventoryItem> _lowStockItems = [];
  List<InventoryItem> _filteredItems = [];
  bool _isLoading = true;
  bool _showDashboard = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadLowStockItems();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLowStockItems() async {
    final allItems = await DatabaseHelper.instance.getAllInventoryItems();
    final lowStock = allItems
        .where((item) => item['quantity'] as int < 10)
        .map((map) => InventoryItem.fromMap(map))
        .toList();
    lowStock.sort((a, b) => a.quantity.compareTo(b.quantity));
    setState(() {
      _lowStockItems = lowStock;
      _isLoading = false;
    });
    _filterItems();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter;

    var filtered = _lowStockItems;

    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
               item.id.toLowerCase().contains(query) ||
               item.category.toLowerCase().contains(query);
      }).toList();
    }

    if (filter == 'Critical') {
      filtered = filtered.where((item) => item.quantity <= 5).toList();
    } else if (filter == 'Low') {
      filtered = filtered.where((item) => item.quantity > 5 && item.quantity < 10).toList();
    }

    setState(() {
      _filteredItems = filtered;
    });
  }

  Map<String, dynamic> get _stats {
    final critical = _lowStockItems.where((item) => item.quantity <= 5).length;
    final low = _lowStockItems.where((item) => item.quantity > 5 && item.quantity < 10).length;
    final totalValue = _lowStockItems.fold<double>(0, (sum, item) => sum + item.totalCost);
    final avgQuantity = _lowStockItems.isNotEmpty
        ? _lowStockItems.fold<int>(0, (sum, item) => sum + item.quantity) / _lowStockItems.length
        : 0.0;

    return {
      'total': _lowStockItems.length,
      'critical': critical,
      'low': low,
      'value': totalValue,
      'avgQuantity': avgQuantity,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Low Stock Items',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDashboard ? Icons.dashboard_outlined : Icons.dashboard,
              color: Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _showDashboard = !_showDashboard;
              });
            },
            tooltip: _showDashboard ? 'Hide Dashboard' : 'Show Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadLowStockItems();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                if (_showDashboard) _buildStatsDashboard(stats),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(12, _showDashboard ? 8 : 16, 12, 80),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isCritical = item.quantity <= 5;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isCritical
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isCritical ? Icons.error_outline : Icons.warning_amber_outlined,
                                    color: isCritical ? Colors.red : Colors.orange,
                                    size: 22,
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.category} • ${item.id}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCritical
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${item.quantity} ${item.unit}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isCritical ? Colors.red : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UGX ${item.sellPrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InventoryPage()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.inventory_outlined, size: 18),
        label: const Text('Go to Inventory', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search low stock items...',
                hintStyle: const TextStyle(fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, size: 20, color: Colors.grey),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Low Stock')),
              const PopupMenuItem(value: 'Critical', child: Text('Critical (≤5)')),
              const PopupMenuItem(value: 'Low', child: Text('Low (6-9)')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stats['total']} item${stats['total'] != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Critical',
                  value: '${stats['critical']}',
                  icon: Icons.error_outline,
                  color: Colors.red,
                  subtitle: '≤5 units',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Low Stock',
                  value: '${stats['low']}',
                  icon: Icons.warning_amber_outlined,
                  color: Colors.orange,
                  subtitle: '6-9 units',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Value',
                  value: 'UGX ${(stats['value'] as double).toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.green,
                  subtitle: 'At cost',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Avg QTY',
                  value: (stats['avgQuantity'] as double).toStringAsFixed(1),
                  icon: Icons.bar_chart_outlined,
                  color: Colors.blue,
                  subtitle: 'Per item',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'No low stock items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All items have sufficient stock (≥10 units)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
