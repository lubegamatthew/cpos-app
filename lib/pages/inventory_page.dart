import 'package:flutter/material.dart';
import '../main.dart';
import '../db_helper.dart';

class InventoryPage extends StatefulWidget {
  final String? initialCategory;
  const InventoryPage({super.key, this.initialCategory});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

enum SortOption {
  nameAsc,
  nameDesc,
  quantityAsc,
  quantityDesc,
  priceAsc,
  priceDesc,
  valueDesc,
}

class _InventoryPageState extends State<InventoryPage> {
  final List<InventoryItem> _inventoryItems = [];
  bool _isSyncing = false;
  String _syncMessage = '';

  // For dropdown in add/edit dialog
  String? selectedCategory;

  List<String> get _categories {
    final distinct = _inventoryItems.map((e) => e.category).toSet().toList();
    if (distinct.isEmpty) {
      // fallback to hardcoded categories
      return ['All Categories', 'Engine Parts', 'Brake System', 'Electrical', 'Body & Frame', 'Suspension', 'Fuel System', 'Transmission', 'Accessories'];
    }
    distinct.sort();
    distinct.removeWhere((c) => c == 'All Categories');
    return ['All Categories', ...distinct];
  }

  final List<InventoryItem> _defaultInventoryItems = [
  // Engine Parts
    InventoryItem(id: 'INV-001', name: 'Timing chain (D&K)', category: 'Engine Parts', quantity: 10, buyPrice: 2500, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-002', name: 'Valves (D&K)', category: 'Engine Parts', quantity: 10, buyPrice: 2500, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-003', name: 'Pistons', category: 'Engine Parts', quantity: 10, buyPrice: 8300, sellPrice: 15000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-004', name: 'Piston Rings', category: 'Engine Parts', quantity: 3, buyPrice: 4000, sellPrice: 8000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-005', name: 'Gaskets (Metal)', category: 'Engine Parts', quantity: 50, buyPrice: 500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-006', name: 'Gaskets (Paper)', category: 'Engine Parts', quantity: 50, buyPrice: 500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-007', name: 'Gaskets (Magnetal)', category: 'Engine Parts', quantity: 50, buyPrice: 500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-008', name: 'Gaskets (Clutch - Verma)', category: 'Engine Parts', quantity: 10, buyPrice: 3500, sellPrice: 6000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-009', name: 'Gaskets (Magnetal - Verma)', category: 'Engine Parts', quantity: 10, buyPrice: 3000, sellPrice: 6000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-010', name: 'Block tensioner', category: 'Engine Parts', quantity: 5, buyPrice: 3500, sellPrice: 6000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-011', name: 'Oil Petrol', category: 'Engine Parts', quantity: 2, buyPrice: 35000, sellPrice: 10000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-012', name: 'Shell (1 box/12pcs)', category: 'Engine Parts', quantity: 10, buyPrice: 18500, sellPrice: 17000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-013', name: 'Oil Pumps', category: 'Engine Parts', quantity: 3, buyPrice: 7500, sellPrice: 10000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-014', name: 'Valve Seals', category: 'Engine Parts', quantity: 2, buyPrice: 4000, sellPrice: 7000, createdAt: DateTime.now()),

    // Brake System
    InventoryItem(id: 'INV-015', name: 'Brake pads (Front)', category: 'Brake System', quantity: 20, buyPrice: 3500, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-016', name: 'Brake pads (Hind)', category: 'Brake System', quantity: 20, buyPrice: 3500, sellPrice: 6000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-017', name: 'Brake shoes', category: 'Brake System', quantity: 5, buyPrice: 5000, sellPrice: 7000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-018', name: 'Brake line', category: 'Brake System', quantity: 10, buyPrice: 1500, sellPrice: 4000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-019', name: 'Brake pedal', category: 'Brake System', quantity: 5, buyPrice: 5500, sellPrice: 11000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-020', name: 'Brake fluid', category: 'Brake System', quantity: 4, buyPrice: 5000, sellPrice: 8000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-021', name: 'Brake II cable', category: 'Brake System', quantity: 10, buyPrice: 2300, sellPrice: 4000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-022', name: 'Brake springs', category: 'Brake System', quantity: 20, buyPrice: 500, sellPrice: 1000, createdAt: DateTime.now()),

    // Electrical
    InventoryItem(id: 'INV-023', name: 'Battery 2.5', category: 'Electrical', quantity: 2, buyPrice: 22000, sellPrice: 28000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-024', name: 'Battery 6.5', category: 'Electrical', quantity: 2, buyPrice: 34000, sellPrice: 45000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-025', name: 'Head bulbs', category: 'Electrical', quantity: 50, buyPrice: 700, sellPrice: 1000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-026', name: 'Tail bulbs', category: 'Electrical', quantity: 5, buyPrice: 3000, sellPrice: 1000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-027', name: 'Indicator bulb', category: 'Electrical', quantity: 10, buyPrice: 2000, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-028', name: 'Bulb holders', category: 'Electrical', quantity: 10, buyPrice: 220, sellPrice: 500, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-029', name: 'Starter Coil', category: 'Electrical', quantity: 10, buyPrice: 4000, sellPrice: 8000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-030', name: 'Main Switch (Small)', category: 'Electrical', quantity: 5, buyPrice: 3000, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-031', name: 'Main Switch (Big)', category: 'Electrical', quantity: 1, buyPrice: 9000, sellPrice: 15000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-032', name: 'Dimmer Switch (Left)', category: 'Electrical', quantity: 3, buyPrice: 15000, sellPrice: 10000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-033', name: 'Dimmer Switch (Pair)', category: 'Electrical', quantity: 1, buyPrice: 15000, sellPrice: 20000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-034', name: 'Horn (Engoombe)', category: 'Electrical', quantity: 5, buyPrice: 2500, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-035', name: 'Plug Cap', category: 'Electrical', quantity: 10, buyPrice: 1300, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-036', name: 'Plugs (Standard)', category: 'Electrical', quantity: 3, buyPrice: 1000, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-037', name: 'Plugs (CR8)', category: 'Electrical', quantity: 2, buyPrice: 12000, sellPrice: 4000, createdAt: DateTime.now()),

    // Body & Frame
    InventoryItem(id: 'INV-038', name: 'Side mirrors', category: 'Body & Frame', quantity: 10, buyPrice: 4500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-039', name: 'Silver mirror', category: 'Body & Frame', quantity: 2, buyPrice: 10000, sellPrice: 7000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-040', name: 'Seat covers (Standard)', category: 'Body & Frame', quantity: 5, buyPrice: 9000, sellPrice: 15000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-041', name: 'Tank Cover', category: 'Body & Frame', quantity: 5, buyPrice: 4500, sellPrice: 7000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-042', name: 'Foot rest', category: 'Body & Frame', quantity: 10, buyPrice: 2500, sellPrice: 6000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-043', name: 'Handle lever (Obugalo)', category: 'Body & Frame', quantity: 10, buyPrice: 2500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-044', name: 'Moulding', category: 'Body & Frame', quantity: 1, buyPrice: 8000, sellPrice: 2000, createdAt: DateTime.now()),

    // Suspension
    InventoryItem(id: 'INV-045', name: 'Ball race', category: 'Suspension', quantity: 10, buyPrice: 4000, sellPrice: 6000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-046', name: 'Sy Headlamps', category: 'Suspension', quantity: 3, buyPrice: 10000, sellPrice: 18000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-047', name: 'Fork pipes', category: 'Suspension', quantity: 1, buyPrice: 33000, sellPrice: 50000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-048', name: 'Shock absorbers', category: 'Suspension', quantity: 1, buyPrice: 45000, sellPrice: 60000, createdAt: DateTime.now()),

    // Fuel System
    InventoryItem(id: 'INV-049', name: 'Carburetor kit', category: 'Fuel System', quantity: 10, buyPrice: 3500, sellPrice: 8000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-050', name: 'Boda oil', category: 'Fuel System', quantity: 9, buyPrice: 1500, sellPrice: 3000, createdAt: DateTime.now()),

    // Transmission
    InventoryItem(id: 'INV-051', name: 'Chains (Standard)', category: 'Transmission', quantity: 2, buyPrice: 9000, sellPrice: 13000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-052', name: 'Chains (Heavy Duty)', category: 'Transmission', quantity: 3, buyPrice: 10000, sellPrice: 15000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-053', name: 'Enanga', category: 'Transmission', quantity: 2, buyPrice: 8000, sellPrice: 13000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-054', name: 'Clutch plates (K&K)', category: 'Transmission', quantity: 20, buyPrice: 3300, sellPrice: 5000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-055', name: 'Clutch plates (Kevla)', category: 'Transmission', quantity: 5, buyPrice: 6500, sellPrice: 10000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-056', name: 'Clutch plates (Yog)', category: 'Transmission', quantity: 5, buyPrice: 5000, sellPrice: 8000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-057', name: 'Clutch wire', category: 'Transmission', quantity: 100, buyPrice: 400, sellPrice: 1000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-058', name: 'Disc Complete', category: 'Transmission', quantity: 3, buyPrice: 14000, sellPrice: 25000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-059', name: 'Disc Incomplete', category: 'Transmission', quantity: 2, buyPrice: 7000, sellPrice: 15000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-060', name: 'Front sprockets', category: 'Transmission', quantity: 20, buyPrice: 1500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-061', name: 'Kickstarter', category: 'Transmission', quantity: 5, buyPrice: 7500, sellPrice: 10000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-062', name: 'Gear lever', category: 'Transmission', quantity: 5, buyPrice: 3500, sellPrice: 8000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-063', name: 'Chain adjuster', category: 'Transmission', quantity: 20, buyPrice: 1500, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-064', name: 'Acc cable', category: 'Transmission', quantity: 10, buyPrice: 2400, sellPrice: 4000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-065', name: 'Double springs', category: 'Transmission', quantity: 10, buyPrice: 500, sellPrice: 1000, createdAt: DateTime.now()),

    // Accessories
    InventoryItem(id: 'INV-066', name: 'Helmet Half (Mazuri)', category: 'Accessories', quantity: 2, buyPrice: 28000, sellPrice: 35000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-067', name: 'Helmet Full (Bajaj)', category: 'Accessories', quantity: 3, buyPrice: 25000, sellPrice: 30000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-068', name: 'Helmet Full (Other)', category: 'Accessories', quantity: 1, buyPrice: 30000, sellPrice: 40000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-069', name: 'Verma Tyre (Yellow)', category: 'Accessories', quantity: 1, buyPrice: 74000, sellPrice: 88000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-070', name: 'R2 Tyre with tube', category: 'Accessories', quantity: 1, buyPrice: 82000, sellPrice: 95000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-071', name: 'Golden Boy Tubes', category: 'Accessories', quantity: 4, buyPrice: 10000, sellPrice: 12000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-072', name: 'R2 Tubes', category: 'Accessories', quantity: 10, buyPrice: 5500, sellPrice: 10000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-073', name: 'CC Tubes', category: 'Accessories', quantity: 20, buyPrice: 2500, sellPrice: 9000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-074', name: 'CC Tyre (Front)', category: 'Accessories', quantity: 3, buyPrice: 30000, sellPrice: 42000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-075', name: 'CC Tyre (Behind)', category: 'Accessories', quantity: 3, buyPrice: 50000, sellPrice: 70000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-076', name: 'System (D&K)', category: 'Accessories', quantity: 2, buyPrice: 20000, sellPrice: 30000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-077', name: 'System (Kevla)', category: 'Accessories', quantity: 3, buyPrice: 28000, sellPrice: 35000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-078', name: 'System (Croc)', category: 'Accessories', quantity: 3, buyPrice: 28000, sellPrice: 35000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-079', name: 'System (Yog)', category: 'Accessories', quantity: 2, buyPrice: 30000, sellPrice: 35000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-080', name: 'Grease', category: 'Accessories', quantity: 3, buyPrice: 6000, sellPrice: 500, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-081', name: 'Silicon Big', category: 'Accessories', quantity: 1, buyPrice: 45000, sellPrice: 6000, createdAt: DateTime.now()),

    // Bearings
    InventoryItem(id: 'INV-082', name: 'Bearing 6304', category: 'Bearings', quantity: 20, buyPrice: 1300, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-083', name: 'Bearing 6204', category: 'Bearings', quantity: 20, buyPrice: 1100, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-084', name: 'Bearing 6301', category: 'Bearings', quantity: 20, buyPrice: 1100, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-085', name: 'Bearing 6202', category: 'Bearings', quantity: 20, buyPrice: 1100, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-086', name: 'Bearing 6201', category: 'Bearings', quantity: 20, buyPrice: 1000, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-087', name: 'Bearing 6004', category: 'Bearings', quantity: 20, buyPrice: 1100, sellPrice: 3000, createdAt: DateTime.now()),

    // Seals
    InventoryItem(id: 'INV-088', name: 'Engine Oil Seals (Set)', category: 'Seals', quantity: 5, buyPrice: 3500, sellPrice: 7000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-089', name: 'Front Fork Seals', category: 'Seals', quantity: 10, buyPrice: 1200, sellPrice: 3000, createdAt: DateTime.now()),
    InventoryItem(id: 'INV-090', name: 'Wheel Oil Seals', category: 'Seals', quantity: 10, buyPrice: 1000, sellPrice: 3000, createdAt: DateTime.now()),
  ];

  String _selectedCategory = 'All Categories';
  SortOption _sortOption = SortOption.nameAsc;
  bool _isLowStockAlertDismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    final items = await DatabaseHelper.instance.getAllInventoryItems();
    if (items.isNotEmpty) {
      setState(() {
        _inventoryItems.clear();
        _inventoryItems.addAll(
          items.map((map) => InventoryItem.fromMap(map)),
        );
      });
    }
  }

  Future<void> _syncToDatabase() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = 'Creating local storage...';
    });

    String snackMessage = '';
    Color snackColor = Colors.green;

    try {
      await Future.delayed(const Duration(seconds: 1));

      final count = await DatabaseHelper.instance.getCount();
      if (count == 0) {
        setState(() {
          _syncMessage = 'Inserting default inventory data...';
        });
        await Future.delayed(const Duration(seconds: 1));

        final batchItems = _defaultInventoryItems.map((item) => item.toMap()).toList();
        await DatabaseHelper.instance.insertAllInventoryItems(batchItems);
        setState(() {
          _syncMessage = 'Synced ${_defaultInventoryItems.length} items successfully!';
        });
      } else {
        setState(() {
          _syncMessage = 'Data already exists ($count items). Data is up to date!';
        });
      }

      await Future.delayed(const Duration(seconds: 1));
      await _loadFromDatabase();
      snackMessage = _syncMessage;
      snackColor = Colors.green;
    } catch (e) {
      setState(() {
        _syncMessage = 'Error: $e';
      });
      snackMessage = _syncMessage;
      snackColor = Colors.red;
    } finally {
      setState(() {
        _isSyncing = false;
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMessage),
            backgroundColor: snackColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, size: 24),
            SizedBox(width: 8),
            Text('Syncing Data'),
          ],
        ),
        content: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _syncMessage.isEmpty ? 'Preparing sync...' : _syncMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
    _syncToDatabase();
  }

  List<InventoryItem> get _filteredItems {
    var items = List<InventoryItem>.from(_inventoryItems);

    if (_selectedCategory != 'All Categories') {
      items = items.where((item) => item.category == _selectedCategory).toList();
    }

    switch (_sortOption) {
      case SortOption.nameAsc:
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        items.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.quantityAsc:
        items.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case SortOption.quantityDesc:
        items.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case SortOption.priceAsc:
        items.sort((a, b) => a.buyPrice.compareTo(b.buyPrice));
        break;
      case SortOption.priceDesc:
        items.sort((a, b) => b.buyPrice.compareTo(a.buyPrice));
        break;
      case SortOption.valueDesc:
        items.sort((a, b) => b.totalCost.compareTo(a.totalCost));
        break;
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
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
          'Inventory',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Icon(Icons.sync, color: _isSyncing ? Colors.blue : Colors.black54),
            onPressed: _isSyncing ? null : () => _showSyncDialog(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _InventorySearchDelegate(items: _inventoryItems),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black54),
            onPressed: _showFilterBottomSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_filteredItems.length} items',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                PopupMenuButton<SortOption>(
                  onSelected: (SortOption result) {
                    setState(() {
                      _sortOption = result;
                    });
                  },
                  icon: const Icon(Icons.sort, size: 20, color: Colors.black54),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: SortOption.nameAsc,
                      child: Text('Name (A-Z)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.nameDesc,
                      child: Text('Name (Z-A)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.quantityAsc,
                      child: Text('Quantity (Low to High)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.quantityDesc,
                      child: Text('Quantity (High to Low)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.priceAsc,
                      child: Text('Price (Low to High)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.priceDesc,
                      child: Text('Price (High to Low)'),
                    ),
                    const PopupMenuItem(
                      value: SortOption.valueDesc,
                      child: Text('Total Value (High to Low)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        setState(() {
                          _selectedCategory = category;
                        });
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_lowStockItems.isNotEmpty && !_isLowStockAlertDismissed)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_lowStockItems.length} item${_lowStockItems.length > 1 ? 's' : ''} running low on stock',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = 'All Categories';
                          _sortOption = SortOption.quantityAsc;
                        });
                      },
                      child: const Text(
                        'View',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isLowStockAlertDismissed = true;
                        });
                      },
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Container(
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
              child: Row(
                children: [
                  Expanded(
                    child: _InventoryStatCard(
                      label: 'Total Items',
                      value: _inventoryItems.length.toString(),
                      icon: Icons.inventory_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InventoryStatCard(
                      label: 'Total Value',
                      value: 'UGX ${_calculateTotalValue().toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InventoryStatCard(
                      label: 'Low Stock',
                      value: _lowStockItems.length.toString(),
                      icon: Icons.warning_amber_outlined,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.symmetric(vertical: 6)),
          SliverFillRemaining(
child: _filteredItems.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.inventory_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No data found!!',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap + to add your first spare part',
                              style: TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => _showAddEditDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Inventory'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    )
                : RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(seconds: 1));
                      setState(() {});
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
itemBuilder: (context, index) {
                         final item = _filteredItems[index];
                         return _InventoryCard(
                           item: item,
                           onTap: () => _showItemDetails(item),
                           onEdit: () => _showAddEditDialog(item: item),
                           onDelete: () => _confirmDelete(item),
                         );
                       },
                     ),
                   ),
           ),
         ],
       ),
       floatingActionButton: FloatingActionButton(
         onPressed: () => _showAddEditDialog(),
         backgroundColor: Theme.of(context).colorScheme.primary,
         foregroundColor: Colors.white,
         child: const Icon(Icons.add),
       ),
     );
   }

  List<InventoryItem> get _lowStockItems =>
      _inventoryItems.where((item) => item.quantity < 5).toList();

  double _calculateTotalValue() {
    return _inventoryItems.fold(0.0, (sum, item) => sum + item.totalCost);
  }

  void _showAddEditDialog({InventoryItem? item}) {
    final isEdit = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    // final categoryController = TextEditingController(text: item?.category ?? '');
    final quantityController = TextEditingController(text: item?.quantity.toString() ?? '');
    final buyPriceController = TextEditingController(text: item?.buyPrice.toString() ?? '');
    final sellPriceController = TextEditingController(text: item?.sellPrice.toString() ?? '');
    final unitController = TextEditingController(text: item?.unit ?? 'pcs');
    final descriptionController = TextEditingController(text: item?.description ?? '');
    selectedCategory = item?.category;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
            ),
            child: Column(
              children: [
                // App Bar
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 12,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      IconButton(
                        icon: const Icon(Icons.close, size: 24),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Spare Part' : 'Add New Spare Part',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final qty = int.parse(quantityController.text.trim());
                            final bp = double.parse(buyPriceController.text.trim());
                            final sp = double.parse(sellPriceController.text.trim());
                             final newItem = InventoryItem(
                               id: item?.id ?? 'INV-${(_inventoryItems.length + 1).toString().padLeft(3, '0')}',
                               name: nameController.text.trim(),
                               category: selectedCategory?.isNotEmpty == true ? selectedCategory! : (item?.category ?? ''),
                               quantity: qty,
                               buyPrice: bp,
                               sellPrice: sp,
                               unit: unitController.text.trim().isEmpty ? 'pcs' : unitController.text.trim(),
                               description: descriptionController.text.trim(),
                               createdAt: DateTime.now(),
                             );

                            setState(() {
                              if (isEdit) {
                                final index = _inventoryItems.indexWhere((i) => i.id == item.id);
                                if (index != -1) {
                                  _inventoryItems[index] = newItem;
                                }
                              } else {
                                _inventoryItems.add(newItem);
                              }
                            });

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit ? 'Spare part updated successfully' : 'Spare part added successfully',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(isEdit ? 'Update' : 'Add Part'),
                      ),
                    ],
                  ),
                ),
                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildCategorySelectionField(),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: nameController,
                              label: 'Item Name *',
                              hintText: 'e.g., Front Brake Disc',
                              icon: Icons.label_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Item name is required';
                                }
                                return null;
                              },
                            ),
                           const SizedBox(height: 16),
                           _buildFormField(
                             controller: quantityController,
                             label: 'Quantity *',
                             hintText: '0',
                             icon: Icons.numbers,
                             keyboardType: TextInputType.number,
                             validator: (value) {
                               if (value == null || value.trim().isEmpty) {
                                 return 'Required';
                               }
                               final parsed = int.tryParse(value);
                               if (parsed == null || parsed < 0) {
                                 return 'Must be valid number';
                               }
                               return null;
                             },
                           ),
                           const SizedBox(height: 16),
                           _buildFormField(
                             controller: unitController,
                             label: 'Unit',
                             hintText: 'pcs',
                             icon: Icons.straighten_outlined,
                           ),
                           const SizedBox(height: 16),
                           _buildFormField(
                             controller: buyPriceController,
                             label: 'Buy Price *',
                             hintText: '0.00',
                             icon: Icons.attach_money_outlined,
                             keyboardType: const TextInputType.numberWithOptions(decimal: true),
                             validator: (value) {
                               if (value == null || value.trim().isEmpty) {
                                 return 'Required';
                               }
                               final parsed = double.tryParse(value);
                               if (parsed == null || parsed < 0) {
                                 return 'Must be valid number';
                               }
                               return null;
                             },
                           ),
                           const SizedBox(height: 16),
                           _buildFormField(
                             controller: sellPriceController,
                             label: 'Selling Price *',
                             hintText: '0.00',
                             icon: Icons.price_change_outlined,
                             keyboardType: const TextInputType.numberWithOptions(decimal: true),
                             validator: (value) {
                               if (value == null || value.trim().isEmpty) {
                                 return 'Required';
                               }
                               final parsed = double.tryParse(value);
                               if (parsed == null || parsed < 0) {
                                 return 'Must be valid number';
                               }
                               return null;
                             },
                           ),
                           const SizedBox(height: 16),
                           _buildFormField(
                             controller: descriptionController,
                             label: 'Description',
                             hintText: 'Optional (e.g., compatible models)',
                             icon: Icons.description_outlined,
                             maxLines: 2,
                           ),
                           const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    double fontSize = 13,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        prefixIcon: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }

  Widget _buildCategorySelectionField() {
    return InkWell(
      onTap: () async {
        debugPrint('Opening category selection modal...');
        final String? selected = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final bool isSelected = selectedCategory == category;
                        return ListTile(
                          title: Text(category),
                          selected: isSelected,
                          tileColor: isSelected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                              : null,
                          onTap: () {
                            debugPrint('Category tapped: $category');
                            Navigator.pop(context, category);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
        debugPrint('Modal returned: $selected');
        // Debug: Print what we got
        debugPrint('Category selected: $selected');
        if (selected != null && selected.isNotEmpty) {
          debugPrint('Updating selectedCategory to: $selected');
          setState(() {
            selectedCategory = selected;
          });
        } else {
          debugPrint('No category selected or empty string');
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Category *',
          hintText: 'Select category',
          prefixIcon: Icon(Icons.category_outlined, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: Colors.white,
          filled: true,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCategory ?? 'Select category',
                style: TextStyle(
                  fontSize: 13,
                  color: selectedCategory == null
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showItemDetails(InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_outlined,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            item.category,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.quantity < 5
                            ? Colors.amber.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.quantity < 5 ? 'Low Stock' : 'In Stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.quantity < 5 ? Colors.amber : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _DetailRow(
                  icon: Icons.numbers,
                  label: 'Quantity',
                  value: '${item.quantity} ${item.unit}',
                ),
                _DetailRow(
                  icon: Icons.attach_money,
                  label: 'Buy Price',
                  value: 'UGX ${item.buyPrice.toStringAsFixed(0)}',
                ),
                _DetailRow(
                  icon: Icons.price_change_outlined,
                  label: 'Sell Price',
                  value: 'UGX ${item.sellPrice.toStringAsFixed(0)}',
                ),
                _DetailRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Cost',
                  value: 'UGX ${item.totalCost.toStringAsFixed(0)}',
                ),
                _DetailRow(
                  icon: Icons.trending_up,
                  label: 'Total Sell',
                  value: 'UGX ${item.totalSell.toStringAsFixed(0)}',
                ),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Added On',
                  value: _formatDate(item.createdAt),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddEditDialog(item: item);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(item);
                        },
                        icon: const Icon(Icons.delete_outlined),
                        label: const Text('Delete'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Spare Part'),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _inventoryItems.removeWhere((i) => i.id == item.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Spare part deleted'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Category',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                        Navigator.pop(context);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// =============================================
// Helper Widgets (outside of _InventoryPageState)
// =============================================

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventoryCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getCategoryColor(item.category).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: _getCategoryColor(item.category),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text('  •  '),
                        Flexible(
                          child: Text(
                            item.quantity < 5
                                ? '${item.quantity} ${item.unit} (low)'
                                : '${item.quantity} ${item.unit}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: item.quantity < 5 ? Colors.amber : Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'UGX ${item.buyPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'UGX ${item.totalCost.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.black45),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outlined, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Engine Parts':
        return Colors.blue;
      case 'Brake System':
        return Colors.red;
      case 'Electrical':
        return Colors.amber;
      case 'Body & Frame':
        return Colors.grey;
      case 'Suspension':
        return Colors.green;
      case 'Fuel System':
        return Colors.orange;
      case 'Transmission':
        return Colors.purple;
      case 'Accessories':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }
}

class _InventoryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InventoryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _InventorySearchDelegate extends SearchDelegate<InventoryItem?> {
  final List<InventoryItem> items;

  _InventorySearchDelegate({required this.items});

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  String? get searchFieldLabel => 'Search spare parts...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = items
        .where((item) =>
            item.name.toLowerCase().contains(query.toLowerCase()) ||
            item.category.toLowerCase().contains(query.toLowerCase()) ||
            item.id.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
],
      ),
    );
  }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return Card(
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getCategoryColor(item.category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_outlined, color: _getCategoryColor(item.category), size: 18),
            ),
            title: Text(item.name),
            subtitle: Text('${item.category}  •  UGX ${item.buyPrice.toStringAsFixed(0)}  •  ${item.quantity} in stock'),
            onTap: () {
              close(context, item);
            },
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? items
        : items
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.category.toLowerCase().contains(query.toLowerCase()))
            .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: const Icon(Icons.inventory_outlined, size: 20),
          title: Text(item.name),
          subtitle: Text(item.category),
          onTap: () {
            query = item.name;
          },
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Engine Parts':
        return Colors.blue;
      case 'Brake System':
        return Colors.red;
      case 'Electrical':
        return Colors.amber;
      case 'Body & Frame':
        return Colors.grey;
      case 'Suspension':
        return Colors.green;
      case 'Fuel System':
        return Colors.orange;
      case 'Transmission':
        return Colors.purple;
      case 'Accessories':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }
}

IconData _getCategoryIcon(String category) {
  switch (category) {
    case 'Engine Parts':
      return Icons.engineering;
    case 'Brake System':
      return Icons.warning_amber;
    case 'Electrical':
      return Icons.electrical_services;
    case 'Body & Frame':
      return Icons.directions_car;
    case 'Suspension':
      return Icons.air;
    case 'Fuel System':
      return Icons.local_gas_station;
    case 'Transmission':
      return Icons.settings_input_component;
    case 'Accessories':
      return Icons.dashboard;
    default:
      return Icons.inventory_outlined;
  }
}