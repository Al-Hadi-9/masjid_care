import 'package:cloud_firestore/cloud_firestore.dart';

import 'masjid_service.dart';

class YearFinanceSummary {
  const YearFinanceSummary({
    required this.year,
    required this.income,
    required this.expense,
    required this.openingBalance,
  });

  final int year;
  final double income;
  final double expense;

  /// Positive values are carried in as income; negative values are carried
  /// in as an expense. Zero means there was no balance from the prior year.
  final double openingBalance;
  double get balance => income - expense;
}

/// Wraps Firestore reads/writes for donations, manual income and
/// expenses. **Every** path is scoped under the active masjid so that
/// finances from one masjid never leak into another:
///
///   masjids/{masjidId}/donations/...
///   masjids/{masjidId}/manual_income/...
///   masjids/{masjidId}/expenses/...
///
/// The active id is read from [MasjidService] on every call — not
/// cached on the constructor — so swapping the active masjid (or
/// loading it asynchronously) is reflected immediately without needing
/// a fresh instance.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Firestore reserves document IDs wrapped in double underscores.
  static const _collectionMetadataId = '_collection_metadata';

  /// The masjid id this service is currently scoped to. Defaults to the
  /// service's current id at construction time, but [scopedCol] /
  /// [scopedDoc] always re-read it so a hot-swap in [MasjidService]
  /// takes effect without recreating this object.
  MasjidService get _masjid => MasjidService.instance;

  CollectionReference<Map<String, dynamic>> get _donationsRef => _firestore
      .collection('masjids')
      .doc(_masjid.masjidId)
      .collection('donations');

  CollectionReference<Map<String, dynamic>> get _manualIncomeRef => _firestore
      .collection('masjids')
      .doc(_masjid.masjidId)
      .collection('manual_income');

  CollectionReference<Map<String, dynamic>> get _expensesRef => _firestore
      .collection('masjids')
      .doc(_masjid.masjidId)
      .collection('expenses');

  /// Firestore does not retain empty collections. Keep a metadata document so
  /// the expected collections are visible after a collection was deleted.
  /// The document intentionally has no `createdAt`, so ordered finance
  /// queries exclude it automatically.
  Future<void> ensureDatabaseCollections() async {
    final batch = _firestore.batch();
    final metadata = <String, dynamic>{
      '_collectionMetadata': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.set(
      _firestore.collection('admins').doc(_collectionMetadataId),
      metadata,
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.collection('masjids').doc(_collectionMetadataId),
      metadata,
      SetOptions(merge: true),
    );

    if (_masjid.hasActiveMasjid) {
      batch.set(
        _donationsRef.doc(_collectionMetadataId),
        metadata,
        SetOptions(merge: true),
      );
      batch.set(
        _manualIncomeRef.doc(_collectionMetadataId),
        metadata,
        SetOptions(merge: true),
      );
      batch.set(
        _expensesRef.doc(_collectionMetadataId),
        metadata,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> saveDonation({
    required String donationType,
    required String paymentMethod,
    required String amount,
    required String mobileNumber,
  }) async {
    try {
      await _donationsRef.add({
        "donationType": donationType,
        "paymentMethod": paymentMethod,
        "amount": double.parse(amount),
        "mobileNumber": mobileNumber,
        "status": "Completed",
        "createdAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Donation Save Failed : $e");
    }
  }

  /// Create a Pending donation record before the user pays. Returns the
  /// document ID so the caller can flip its status to Completed/Failed/Cancelled
  /// once the gateway redirects back.
  Future<String> savePendingDonation({
    required String transactionId,
    required String donationType,
    required String amount,
    required String mobileNumber,
    String name = '',
    String email = '',
    String paymentMethod = 'SSLCommerz',
  }) async {
    try {
      final docRef = await _donationsRef.add({
        "tran_id": transactionId,
        "donationType": donationType,
        "paymentMethod": paymentMethod,
        "amount": double.parse(amount),
        "mobileNumber": mobileNumber,
        "name": name,
        "email": email,
        "status": "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception("Pending Donation Save Failed: $e");
    }
  }

  Future<void> markDonationCompleted({
    required String docId,
    required String transactionId,
    required String amount,
  }) async {
    try {
      await _donationsRef.doc(docId).update({
        "status": "Completed",
        "tran_id": transactionId,
        "completedAt": FieldValue.serverTimestamp(),
        "completedAmount": double.tryParse(amount) ?? 0,
      });
    } catch (e) {
      throw Exception("Mark Completed Failed: $e");
    }
  }

  Future<void> markDonationFailed({
    required String docId,
    required String transactionId,
  }) async {
    try {
      await _donationsRef.doc(docId).update({
        "status": "Failed",
        "tran_id": transactionId,
        "failedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Mark Failed Failed: $e");
    }
  }

  Future<void> markDonationCancelled({
    required String docId,
    required String transactionId,
  }) async {
    try {
      await _donationsRef.doc(docId).update({
        "status": "Cancelled",
        "tran_id": transactionId,
        "cancelledAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Mark Cancelled Failed: $e");
    }
  }

  Future<double> getTotalDonationAmount() async {
    // Only fetch completed donations server-side. The original code pulled
    // every document and filtered on the client, which can be megabytes of
    // data over a slow mobile connection.
    final snapshot = await _donationsRef
        .where('status', isEqualTo: 'Completed')
        .get();

    double total = 0;

    for (var doc in snapshot.docs) {
      if (doc.id == _collectionMetadataId) continue;
      total += (doc["amount"] as num).toDouble();
    }

    return total;
  }

  Future<void> addManualIncome({
    required String khat,
    required String amount,
    required String note,
    required String createdBy,
    required String createdByEmail,
    DateTime? date,
  }) async {
    try {
      final Map<String, dynamic> data = {
        "khat": khat,
        "amount": double.parse(amount),
        "note": note,
        "createdBy": createdBy,
        "createdByEmail": createdByEmail,
      };

      if (date != null) {
        data["date"] = Timestamp.fromDate(date);
        data["createdAt"] = Timestamp.fromDate(date);
      } else {
        data["createdAt"] = FieldValue.serverTimestamp();
      }

      await _manualIncomeRef.add(data);
    } catch (e) {
      throw Exception("Manual Income Save Failed: $e");
    }
  }

  Future<double> getTotalManualIncomeAmount() async {
    final snapshot = await _manualIncomeRef.get();

    double total = 0;

    for (var doc in snapshot.docs) {
      total += (doc["amount"] as num).toDouble();
    }

    return total;
  }

  /// Fetch all three dashboard totals in parallel instead of serially —
  /// cuts cold-start of AdminDashboardPage from ~3×RTT to a single RTT.
  Future<({double income, double expense})> getDashboardTotals() async {
    final summary = await getYearlyFinanceSummary(DateTime.now().year);
    return (income: summary.income, expense: summary.expense);
  }

  /// Produces calendar-year totals and materializes the prior year's net
  /// balance as a dated income or expense entry on January 1. Rollover
  /// entries use deterministic document IDs, so loading the page repeatedly
  /// never duplicates them.
  Future<List<YearFinanceSummary>> getYearlyFinanceSummaries({
    int? throughYear,
  }) async {
    final currentYear = throughYear ?? DateTime.now().year;
    final results = await Future.wait([
      _donationsRef.where('status', isEqualTo: 'Completed').get(),
      _manualIncomeRef.get(),
      _expensesRef.get(),
    ]);
    final donationDocs = results[0].docs;
    final incomeDocs = results[1].docs;
    final expenseDocs = results[2].docs;

    final incomeByYear = <int, double>{};
    final expenseByYear = <int, double>{};
    final years = <int>{currentYear};
    final rolloverYears = <int>{};

    void collect(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      Map<int, double> totals,
    ) {
      for (final doc in docs) {
        if (doc.id == _collectionMetadataId) continue;
        final data = doc.data();
        final date = _entryDate(data);
        if (date == null) continue;
        years.add(date.year);
        if (data['entryType'] == 'year_rollover') {
          rolloverYears.add(date.year);
          continue;
        }
        if (date.year > currentYear) {
          continue;
        }
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        totals.update(
          date.year,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }
    }

    collect(donationDocs, incomeByYear);
    collect(incomeDocs, incomeByYear);
    collect(expenseDocs, expenseByYear);

    final firstYear = years
        .where((year) => year <= currentYear)
        .reduce((a, b) => a < b ? a : b);
    var carriedBalance = 0.0;
    final summaries = <YearFinanceSummary>[];
    for (var year = firstYear; year <= currentYear; year++) {
      final openingBalance = carriedBalance;
      try {
        await _writeYearOpeningBalance(
          year,
          openingBalance,
          hasExistingRollover: rolloverYears.contains(year),
        );
      } catch (_) {
        // Keep showing the calculated totals if Firestore is temporarily
        // unavailable; a later load will retry writing the opening entry.
      }
      final income =
          (incomeByYear[year] ?? 0) + (openingBalance > 0 ? openingBalance : 0);
      final expense =
          (expenseByYear[year] ?? 0) +
          (openingBalance < 0 ? openingBalance.abs() : 0);
      carriedBalance = income - expense;
      summaries.add(
        YearFinanceSummary(
          year: year,
          income: income,
          expense: expense,
          openingBalance: openingBalance,
        ),
      );
    }
    return summaries.reversed.toList(growable: false);
  }

  Future<YearFinanceSummary> getYearlyFinanceSummary(int year) async {
    final summaries = await getYearlyFinanceSummaries(throughYear: year);
    return summaries.firstWhere(
      (summary) => summary.year == year,
      orElse: () => YearFinanceSummary(
        year: year,
        income: 0,
        expense: 0,
        openingBalance: 0,
      ),
    );
  }

  DateTime? _entryDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    if (createdAt is DateTime) return createdAt;
    final date = data['date'];
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    return null;
  }

  Future<void> _writeYearOpeningBalance(
    int year,
    double balance, {
    required bool hasExistingRollover,
  }) async {
    const idPrefix = 'year_opening_';
    final id = '$idPrefix$year';
    final incomeRef = _manualIncomeRef.doc(id);
    final expenseRef = _expensesRef.doc(id);
    final timestamp = Timestamp.fromDate(DateTime(year, 1, 1));
    final positive = balance > 0.005;
    final negative = balance < -0.005;
    final amount = balance.abs();
    if (!positive && !negative && !hasExistingRollover) return;

    await _firestore.runTransaction((transaction) async {
      final incomeDoc = await transaction.get(incomeRef);
      final expenseDoc = await transaction.get(expenseRef);
      if (positive) {
        final existingAmount = (incomeDoc.data()?['amount'] as num?)
            ?.toDouble();
        if (incomeDoc.exists &&
            incomeDoc.data()?['entryType'] == 'year_rollover' &&
            existingAmount != null &&
            (existingAmount - amount).abs() < 0.005 &&
            !expenseDoc.exists) {
          return;
        }
        transaction.set(incomeRef, {
          'entryType': 'year_rollover',
          'khat': 'Previous year remaining balance',
          'amount': amount,
          'note': 'Previous year (${year - 1}) remaining balance',
          'createdBy': 'System',
          'createdByEmail': '',
          'date': timestamp,
          'createdAt': timestamp,
        });
        if (expenseDoc.exists) transaction.delete(expenseRef);
      } else if (negative) {
        final existingAmount = (expenseDoc.data()?['amount'] as num?)
            ?.toDouble();
        if (expenseDoc.exists &&
            expenseDoc.data()?['entryType'] == 'year_rollover' &&
            existingAmount != null &&
            (existingAmount - amount).abs() < 0.005 &&
            !incomeDoc.exists) {
          return;
        }
        transaction.set(expenseRef, {
          'entryType': 'year_rollover',
          'khat': 'Previous year deficit',
          'amount': amount,
          'note': 'Previous year (${year - 1}) deficit',
          'createdBy': 'System',
          'createdByEmail': '',
          'date': timestamp,
          'createdAt': timestamp,
        });
        if (incomeDoc.exists) transaction.delete(incomeRef);
      } else {
        if (incomeDoc.exists) transaction.delete(incomeRef);
        if (expenseDoc.exists) transaction.delete(expenseRef);
      }
    });
  }

  Stream<QuerySnapshot> getManualIncomes({int? month, int? year}) {
    Query query = _manualIncomeRef;

    if (year != null) {
      final start = DateTime(year, month ?? 1, 1);

      final end = month == null
          ? DateTime(year + 1, 1, 1)
          : DateTime(year, month + 1, 1);

      query = query
          .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where("createdAt", isLessThan: Timestamp.fromDate(end));
    }

    return query.orderBy("createdAt", descending: true).snapshots();
  }

  Future<double> getTotalIncome() async {
    final donation = await getTotalDonationAmount();
    final manual = await getTotalManualIncomeAmount();

    return donation + manual;
  }

  Future<void> addExpense({
    required String khat,
    required String amount,
    required String note,
    required String createdBy,
    required String createdByEmail,
    DateTime? date,
  }) async {
    try {
      final Map<String, dynamic> data = {
        "khat": khat,
        "amount": double.parse(amount),
        "note": note,
        "createdBy": createdBy,
        "createdByEmail": createdByEmail,
      };

      if (date != null) {
        data["date"] = Timestamp.fromDate(date);
        data["createdAt"] = Timestamp.fromDate(date);
      } else {
        data["createdAt"] = FieldValue.serverTimestamp();
      }

      await _expensesRef.add(data);
    } catch (e) {
      throw Exception("Expense Save Failed: $e");
    }
  }

  Future<double> getTotalExpense() async {
    final snapshot = await _expensesRef.get();

    double total = 0;

    for (var doc in snapshot.docs) {
      if (doc.id == _collectionMetadataId) continue;
      total += (doc["amount"] as num).toDouble();
    }

    return total;
  }

  Stream<QuerySnapshot> getDonations({int? month, int? year}) {
    Query query = _donationsRef;

    if (year != null) {
      final start = DateTime(year, month ?? 1, 1);

      final end = month == null
          ? DateTime(year + 1, 1, 1)
          : DateTime(year, month + 1, 1);

      query = query
          .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where("createdAt", isLessThan: Timestamp.fromDate(end));
    }

    return query.orderBy("createdAt", descending: true).snapshots();
  }

  Stream<QuerySnapshot> getExpenses({int? month, int? year}) {
    Query query = _expensesRef;

    if (year != null) {
      final start = DateTime(year, month ?? 1, 1);

      final end = month == null
          ? DateTime(year + 1, 1, 1)
          : DateTime(year, month + 1, 1);

      query = query
          .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where("createdAt", isLessThan: Timestamp.fromDate(end));
    }

    return query.orderBy("createdAt", descending: true).snapshots();
  }
}
