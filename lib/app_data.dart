import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'storage.dart';

/// وضعیت مرکزی اپلیکیشن؛ هر تغییری در داده‌ها همه صفحه‌ها را به‌روز می‌کند
class AppData extends ChangeNotifier {
  final AppStore store;

  AppData(this.store);

  List<Appt> get appts => store.appointments;
  BizSettings get settings => store.settings;

  void addAppt(Appt a) {
    store.appointments.add(a);
    unawaited(store.saveAppts());
    notifyListeners();
  }

  void updateAppt(Appt a) {
    final i = store.appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) store.appointments[i] = a;
    unawaited(store.saveAppts());
    notifyListeners();
  }

  void removeAppt(String id) {
    store.appointments.removeWhere((x) => x.id == id);
    unawaited(store.saveAppts());
    notifyListeners();
  }

  void updateSettings(BizSettings s) {
    store.settings = s;
    unawaited(store.saveSettings());
    notifyListeners();
  }

  void clearAll() {
    store.appointments.clear();
    unawaited(store.saveAppts());
    notifyListeners();
  }
}
