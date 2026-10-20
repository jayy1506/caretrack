class SlotModel {
  final String time;
  final int startMinutes;
  final bool available;
  final String? reasonUnavailable;

  SlotModel({
    required this.time,
    required this.startMinutes,
    required this.available,
    this.reasonUnavailable,
  });

  factory SlotModel.fromMap(Map<String, dynamic> map) {
    return SlotModel(
      time: map['time'] ?? '',
      startMinutes: map['startMinutes'] ?? 0,
      available: map['available'] ?? false,
      reasonUnavailable: map['reasonUnavailable'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'startMinutes': startMinutes,
      'available': available,
      if (reasonUnavailable != null) 'reasonUnavailable': reasonUnavailable,
    };
  }
}

class DaySlotsModel {
  final String date;
  final String dayName;
  final bool isOpen;
  final String? reasonClosed;
  final List<SlotModel> slots;

  DaySlotsModel({
    required this.date,
    required this.dayName,
    required this.isOpen,
    this.reasonClosed,
    required this.slots,
  });

  List<SlotModel> get availableSlots => slots.where((s) => s.available).toList();

  factory DaySlotsModel.fromMap(Map<String, dynamic> map) {
    final slotsRaw = (map['slots'] as List<dynamic>?) ?? [];
    return DaySlotsModel(
      date: map['date'] ?? '',
      dayName: map['dayName'] ?? '',
      isOpen: map['isOpen'] ?? false,
      reasonClosed: map['reasonClosed'],
      slots: slotsRaw
          .map((s) => SlotModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'dayName': dayName,
      'isOpen': isOpen,
      if (reasonClosed != null) 'reasonClosed': reasonClosed,
      'slots': slots.map((s) => s.toMap()).toList(),
    };
  }
}
