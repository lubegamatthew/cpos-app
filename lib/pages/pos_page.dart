import 'package:flutter/material.dart';
import '../main.dart';
import '../db_helper.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class CartItem {
  final InventoryItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  double get total => item.sellPrice * quantity;
  double get profit => (item.sellPrice - item.buyPrice) * quantity;
}

class _PosPageState extends State<PosPage> {
  final List<InventoryItem> _inventory = [];
  final List<CartItem> _cart = [];
  final ScrollController _scrollController = ScrollController();

  // Customer info
  final _customerNameController = TextEditingController(text: 'Walk-in Customer');
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  // Search and filter
  final _searchController = TextEditingController();
  String _selectedCategory = 'All Categories';
  bool _isProcessing = false;

  // Get categories from inventory
  List<String> get _categories {
    final cats = _inventory.map((i) => i.category).toSet().toList();
    cats.sort();
    return ['All Categories', ...cats];
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final items = await DatabaseHelper.instance.getAllInventoryItems();
    setState(() {
      _inventory.clear();
      _inventory.addAll(items.map((map) => InventoryItem.fromMap(map)));
    });
  }

  List<InventoryItem> get _filteredItems {
    var items = _inventory.where((item) => item.quantity > 0).toList();

    if (_selectedCategory != 'All Categories') {
      items = items.where((item) => item.category == _selectedCategory).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((item) =>
              item.name.toLowerCase().contains(query) ||
              item.id.toLowerCase().contains(query))
          .toList();
    }

    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  void _addToCart(InventoryItem item) {
    setState(() {
      final existing = _cart.firstWhere(
        (c) => c.item.id == item.id,
        orElse: () => CartItem(item: item),
      );
      if (_cart.any((c) => c.item.id == item.id)) {
        existing.quantity++;
      } else {
        _cart.add(CartItem(item: item));
      }
    });
    _showCartBottomSheet();
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (itemId == 'all') {
        _cart.clear();
      } else {
        _cart.removeWhere((c) => c.item.id == itemId);
      }
    });
  }

  void _updateCartQuantity(String itemId, int delta) {
    setState(() {
      final cartItem = _cart.firstWhere((c) => c.item.id == itemId);
      cartItem.quantity += delta;
      if (cartItem.quantity <= 0) {
        _cart.removeWhere((c) => c.item.id == itemId);
      }
    });
  }

  double get _subtotal => _cart.fold(0.0, (sum, c) => sum + c.total);
  double get _totalProfit => _cart.fold(0.0, (sum, c) => sum + c.profit);
  int get _itemCount => _cart.fold(0, (sum, c) => sum + c.quantity);

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now().toIso8601String();

      // Create order
      await DatabaseHelper.instance.insertOrder({
        'id': orderId,
        'customerName': _customerNameController.text.trim().isEmpty
            ? 'Walk-in Customer'
            : _customerNameController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'totalAmount': _subtotal,
        'totalProfit': _totalProfit,
        'paymentMethod': 'Cash',
        'status': 'Completed',
        'notes': _notesController.text.trim(),
        'createdAt': now,
      });

      // Create order items and update inventory
      for (final cartItem in _cart) {
        final item = cartItem.item;
        final newQty = item.quantity - cartItem.quantity;

        await DatabaseHelper.instance.insertOrderItem({
          'id': '${orderId}_${item.id}',
          'orderId': orderId,
          'inventoryId': item.id,
          'itemName': item.name,
          'quantity': cartItem.quantity,
          'buyPrice': item.buyPrice,
          'sellPrice': item.sellPrice,
          'totalCost': item.buyPrice * cartItem.quantity,
          'totalRevenue': item.sellPrice * cartItem.quantity,
          'profit': (item.sellPrice - item.buyPrice) * cartItem.quantity,
        });

        // Update inventory
        await DatabaseHelper.instance.updateItem({
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'quantity': newQty,
          'buyPrice': item.buyPrice,
          'sellPrice': item.sellPrice,
          'unit': item.unit,
          'description': item.description,
          'createdAt': item.createdAt.toIso8601String(),
        });
      }

      _cart.clear();
      _customerNameController.text = 'Walk-in Customer';
      _customerPhoneController.clear();
      _notesController.clear();

      if (mounted) {
        await _loadInventory();
        _showReceiptDialog(orderId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checkout failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CartBottomSheet(
        cartItems: _cart,
        onUpdateQuantity: _updateCartQuantity,
        onRemove: _removeFromCart,
        onCheckout: _checkout,
        isProcessing: _isProcessing,
      ),
    );
  }

  void _showReceiptDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Sale Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: $orderId', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Items: $_itemCount', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              'Total: UGX ${_subtotal.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Profit: UGX ${_totalProfit.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _loadInventory();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Inventory refreshed'),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        FloatingActionButton(
                          heroTag: 'cart_fab',
                          onPressed: _cart.isEmpty ? null : _showCartBottomSheet,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                        if (_cart.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$_itemCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedCategory = category);
                          },
                          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          checkmarkColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _inventory.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading inventory...'),
                ],
              ),
            )
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or category filter',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _PosProductCard(
                      item: item,
                      onTap: () => _addToCart(item),
                    );
                  },
                ),
      floatingActionButton: _cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await _checkout();
                if (mounted && _cart.isEmpty) {
                  _showCartBottomSheet();
                }
              },
              icon: const Icon(Icons.check_circle),
              label: Text('Checkout (UGX ${_subtotal.toStringAsFixed(0)})'),
              backgroundColor: Colors.green,
            ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _PosProductCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;

  const _PosProductCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = item.quantity < 5;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isLowStock
                      ? Colors.amber.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: isLowStock ? Colors.amber : Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Low',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'UGX ${item.sellPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.shopping_cart_outlined, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBottomSheet extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemove;
  final VoidCallback onCheckout;
  final bool isProcessing;

  const _CartBottomSheet({
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onCheckout,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = cartItems.fold(0.0, (sum, c) => sum + c.total);
    final profit = cartItems.fold(0.0, (sum, c) => sum + c.profit);
    final itemCount = cartItems.fold(0, (sum, c) => sum + c.quantity);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cart ($itemCount items)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onRemove('all');
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
               ),
               const Divider(height: 24),
               Expanded(
                child: cartItems.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFF9E9E9E)),
                            SizedBox(height: 8),
                            Text('Cart is empty', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cartItems.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cartItem = cartItems[index];
                          final item = cartItem.item;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'UGX ${item.sellPrice.toStringAsFixed(0)} each',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    onUpdateQuantity(item.id, -1);
                                    if (cartItem.quantity <= 1) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Container(
                                  width: 32,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                                  onPressed: () {
                                    if (cartItem.quantity < item.quantity) {
                                      onUpdateQuantity(item.id, 1);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Not enough stock'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    onRemove(item.id);
                                    Navigator.pop(context);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontSize: 14)),
                        Text(
                          'UGX ${subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Est. Profit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          'UGX ${profit.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isProcessing || cartItems.isEmpty ? null : onCheckout,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.payment, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Complete Sale',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
