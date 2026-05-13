import 'package:flutter/foundation.dart';

class SalesBus {
  SalesBus._internal();
  static final SalesBus _instance = SalesBus._internal();
  factory SalesBus() => _instance;

  final ValueNotifier<bool> _salesUpdatedNotifier = ValueNotifier<bool>(false);

  void notifySalesUpdated() {
    _salesUpdatedNotifier.value = !_salesUpdatedNotifier.value;
  }

  void addListener(VoidCallback listener) {
    _salesUpdatedNotifier.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _salesUpdatedNotifier.removeListener(listener);
  }
}