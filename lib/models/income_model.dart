class IncomeModel {
  final String khat;
  final double amount;
  final String note;
  final String createdBy;

  IncomeModel({
    required this.khat,
    required this.amount,
    required this.note,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      "khat": khat,
      "amount": amount,
      "note": note,
      "createdBy": createdBy,
    };
  }
}