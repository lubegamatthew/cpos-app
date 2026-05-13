import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../main.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final Set<int> _expandedPanels = {};

  String _formatCurrency(double value) {
    return 'UGX ${value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Sales',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getSalesWithItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading sales data...'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sales recorded yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sales will appear here once checkout is completed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          final sales = snapshot.data!;

          // Pre-compute sections
          final totalSales = sales.fold<double>(
            0,
            (sum, s) =>
                sum +
                ((s['order'] as Map<String, dynamic>)['totalAmount']
                    as double),
          );
          final totalProfit = sales.fold<double>(
            0,
            (sum, s) =>
                sum +
                ((s['order'] as Map<String, dynamic>)['totalProfit']
                    as double),
          );
          final totalItems = sales.fold<int>(
            0,
            (sum, s) {
              final items = s['items'] as List<Map<String, dynamic>>;
              return sum +
                  items.fold<int>(
                    0,
                    (sum, i) => sum + (i['quantity'] as int),
                  );
            },
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expandable summary cards
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Total Sales tile
                      _buildExpansionTile(
                        title: 'Total Sales',
                        value: _formatCurrency(totalSales),
                        icon: Icons.receipt_outlined,
                        color: Colors.green,
                        index: 0,
                        child: _buildSalesDetailTable(sales),
                      ),
                      const Divider(height: 1),
                      // Total Profit tile
                      _buildExpansionTile(
                        title: 'Total Profit',
                        value: _formatCurrency(totalProfit),
                        icon: Icons.trending_up,
                        color: Colors.blue,
                        index: 1,
                        child: _buildProfitDetailTable(sales),
                      ),
                      const Divider(height: 1),
                      // Items Sold tile
                      _buildExpansionTile(
                        title: 'Items Sold',
                        value: '$totalItems',
                        icon: Icons.shopping_bag_outlined,
                        color: Colors.orange,
                        index: 2,
                        child: _buildItemsDetailTable(sales),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Full sales history table
                Text(
                  'All Sales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTableHeader(),
                      ...sales.asMap().entries.map((entry) {
                        final index = entry.key;
                        final sale = entry.value;
                        final order =
                            sale['order'] as Map<String, dynamic>;
                        final items =
                            sale['items'] as List<Map<String, dynamic>>;
                        final isLast = index == sales.length - 1;
                        return _buildTableRow(
                          order: order,
                          items: items,
                          isLast: isLast,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required int index,
    required Widget child,
  }) {
    final isExpanded = _expandedPanels.contains(index);
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: ValueKey(index),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedPanels.add(index);
            } else {
              _expandedPanels.remove(index);
            }
          });
        },
        leading: Icon(icon, color: color, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isExpanded
                  ? Icons.expand_less
                  : Icons.expand_more,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesDetailTable(List<Map<String, dynamic>> sales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent orders included in this total:',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...sales.take(10).map((sale) {
          final order = sale['order'] as Map<String, dynamic>;
          final items = sale['items'] as List<Map<String, dynamic>>;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order['id'],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  order['customerName'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  _formatCurrency(order['totalAmount']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
        if (sales.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '...and ${sales.length - 10} more',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildProfitDetailTable(List<Map<String, dynamic>> sales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profit breakdown by order:',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...sales.take(10).map((sale) {
          final order = sale['order'] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${order['id']} — ${order['customerName']}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  _formatCurrency(order['totalProfit']),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          );
        }),
        if (sales.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '...and ${sales.length - 10} more',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildItemsDetailTable(List<Map<String, dynamic>> sales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itemised breakdown across all orders:',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...sales.take(5).expand((sale) {
          final items = sale['items'] as List<Map<String, dynamic>>;
          final orderId = (sale['order'] as Map<String, dynamic>)['id'];
          return items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '[$orderId] ${item['itemName']}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    'x${item['quantity']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          });
        }),
        if (sales.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '...and ${sales.length - 5} more orders',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Order ID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Date & Time',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Items',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> items,
    required bool isLast,
  }) {
    final orderId = order['id'] as String;
    final customer = order['customerName'] as String;
    final totalAmount = order['totalAmount'] as double;
    final createdAt = order['createdAt'] as String;

    final dateTime = DateTime.tryParse(createdAt);
    final formattedDate =
        dateTime != null ? _formatDateTime(dateTime) : createdAt;

    return Column(
      children: [
        InkWell(
          onTap: () {
            // Show order detail dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text('Order $orderId'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Customer: $customer'),
                    Text('Date: $formattedDate'),
                    const Divider(),
                    ...items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['itemName']} x${item['quantity']}',
                                ),
                              ),
                              Text(
                                _formatCurrency(
                                    item['totalRevenue'] as double),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          _formatCurrency(totalAmount),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    orderId.length > 12
                        ? orderId.substring(0, 12)
                        : orderId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(totalAmount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}