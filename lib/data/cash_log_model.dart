import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

enum CashType { ingress, egress }

extension CashTypeExtension on CashType {
  String get displayName {
    switch (this) {
      case CashType.ingress:
        return 'Receita';
      case CashType.egress:
        return 'Despesa';
    }
  }

  String get iconCodePoint {
    switch (this) {
      case CashType.ingress:
        return '\uE8B6'; // Arrow up icon
      case CashType.egress:
        return '\uE8B7'; // Arrow down icon
    }
  }
}

class CashLog with EquatableMixin {
  final String id;
  final CashType type;
  final String? photoPath;
  final double amount;
  final String? observation;
  final String employeeName;
  final DateTime date;
  final bool isSynced;

  const CashLog({
    required this.id,
    required this.type,
    this.photoPath,
    required this.amount,
    required this.observation,
    required this.employeeName,
    required this.date,
    this.isSynced = false,
  });

  factory CashLog.create({
    required CashType type,
    String? photoPath,
    required double amount,
    String? observation,
    required String employeeName,
    DateTime? date,
    bool isSynced = false,
  }) {
    return CashLog(
      id: const Uuid().v4(),
      type: type,
      photoPath: photoPath,
      amount: amount,
      observation: observation,
      employeeName: employeeName,
      date: date ?? DateTime.now(),
      isSynced: isSynced,
    );
  }

  CashLog copyWith({
    String? id,
    CashType? type,
    String? photoPath,
    double? amount,
    String? observation,
    String? employeeName,
    DateTime? date,
    bool? isSynced,
  }) {
    return CashLog(
      id: id ?? this.id,
      type: type ?? this.type,
      photoPath: photoPath ?? this.photoPath,
      amount: amount ?? this.amount,
      observation: observation ?? this.observation,
      employeeName: employeeName ?? this.employeeName,
      date: date ?? this.date,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'photoPath': photoPath,
      'amount': amount,
      'products': observation,
      'employeeName': employeeName,
      'date': date.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  /// Cria um objeto CashLog a partir de um Map (para leitura do banco)
  factory CashLog.fromMap(Map<String, dynamic> map) {
    return CashLog(
      id: map['id'],
      type: CashType.values[map['type'] ?? 0],
      photoPath: map['photoPath'],
      amount: map['amount'],
      observation: map['observation'],
      employeeName: map['employeeName'],
      date: DateTime.parse(map['date']),
      isSynced: map['isSynced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'typeDisplay': type.displayName,
      'photoPath': photoPath,
      'amount': amount,
      'products': observation,
      'employeeName': employeeName,
      'date': date.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  @override
  List<Object?> get props => [
        id,
        type,
        photoPath,
        amount,
        observation,
        employeeName,
        date,
        isSynced,
      ];

  @override
  String toString() {
    return 'CashLog(id: $id, type: $type, amount: $amount, observation: $observation, employee: $employeeName, date: $date, synced: $isSynced)';
  }
}
