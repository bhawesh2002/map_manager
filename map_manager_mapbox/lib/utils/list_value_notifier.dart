import 'package:flutter/foundation.dart';

class ListValueNotifier<T> extends ChangeNotifier {
  List<T> _value;
  ListValueNotifier(this._value);
  List<T> get value => _value;
  set value(List<T> val) {
    if (_value == val) {
      return;
    }
    _value = val;
    notifyListeners();
  }

  void add(T val) {
    _value.add(val);
    notifyListeners();
  }

  void remove(T val) {
    _value.remove(val);
    notifyListeners();
  }

  void addAll(List<T> list) {
    _value.addAll(list);
    notifyListeners();
  }

  void clear() {
    _value = [];
    notifyListeners();
  }
}
