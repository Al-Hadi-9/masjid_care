import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../widgets/app_appbar.dart';
import '../widgets/app_bottom_nav.dart';
import 'app_shell.dart';

class DonationListPage extends StatefulWidget {
  final bool readOnly;

  const DonationListPage({super.key, this.readOnly = false});

  @override
  State<DonationListPage> createState() => _DonationListPageState();
}

class _DonationListPageState extends State<DonationListPage> {
  final FirestoreService firestoreService = FirestoreService();

  int? selectedMonth;
  int? selectedYear;
  String? selectedDonationType;

  static const List<String> _monthNames = [
    "জানুয়ারি",
    "ফেব্রুয়ারি",
    "মার্চ",
    "এপ্রিল",
    "মে",
    "জুন",
    "জুলাই",
    "আগস্ট",
    "সেপ্টেম্বর",
    "অক্টোবর",
    "নভেম্বর",
    "ডিসেম্বর",
  ];

  static const List<String> _donationTypes = [
    "মসজিদ",
    "মাদ্রাসা",
    "জুমার দান",
    "যাকাত",
    "ঈদ",
    "অন্যান্য",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: 'অনুদানের তালিকা',
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E4E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'অনুদানের তালিকা',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.borderLight),
                boxShadow: AppTokens.softShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedMonth,
                          decoration: InputDecoration(
                            labelText: "Month",
                            filled: true,
                            fillColor: const Color(0xFFF6F8F9),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),

                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text("All"),
                            ),

                            ...List.generate(
                              12,
                              (i) => DropdownMenuItem<int>(
                                value: i + 1,
                                child: Text(_monthNames[i]),
                              ),
                            ),
                          ],

                          onChanged: (value) {
                            setState(() {
                              selectedMonth = value;
                            });
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedYear,
                          decoration: InputDecoration(
                            labelText: "Year",
                            filled: true,
                            fillColor: const Color(0xFFF6F8F9),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),

                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text("All"),
                            ),

                            for (int y = 2026; y <= 2035; y++)
                              DropdownMenuItem<int>(value: y, child: Text("$y")),
                          ],

                          onChanged: (value) {
                            setState(() {
                              selectedYear = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: selectedDonationType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Donation Type",
                      filled: true,
                      fillColor: const Color(0xFFF6F8F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),

                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("All"),
                      ),

                      ..._donationTypes.map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        selectedDonationType = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _combineLatest2(
                firestoreService.getDonations(
                  month: selectedMonth,
                  year: selectedYear,
                ),
                firestoreService.getManualIncomes(
                  month: selectedMonth,
                  year: selectedYear,
                ),
              ),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text("No Donation Found"));
                }

                final donationDocs = snapshot.data![0].docs;
                final manualDocs = snapshot.data![1].docs;

                final completedDonations = donationDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data["status"] ?? "";
                  return status == "Completed";
                }).toList();

                final items =
                    <_IncomeItem>[
                      ...completedDonations.map(
                        (doc) => _IncomeItem.fromDonation(
                          doc.data() as Map<String, dynamic>,
                        ),
                      ),
                      ...manualDocs.map(
                        (doc) => _IncomeItem.fromManualIncome(
                          doc.data() as Map<String, dynamic>,
                        ),
                      ),
                    ].where((item) {
                      if (selectedDonationType == null) return true;
                      return item.title == selectedDonationType;
                    }).toList();

                items.sort((a, b) {
                  final at = a.createdAt;
                  final bt = b.createdAt;
                  if (at == null && bt == null) return 0;
                  if (at == null) return 1;
                  if (bt == null) return -1;
                  return bt.compareTo(at);
                });

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "No Donation Found",
                        style: TextStyle(color: Color(0xFF7F8C8D)),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: items.length,

                  itemBuilder: (context, index) {
                    final item = items[index];

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTokens.borderLight),
                        boxShadow: AppTokens.softShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.isManual
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.isManual ? Icons.edit_note : Icons.favorite,
                              color: item.isManual
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF1B5E4E),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '৳ ${item.amount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1B5E4E),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...item.subtitleLines(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNavigationBar(context),
    );
  }

  Widget _bottomNavigationBar(BuildContext context) {
    return AppBottomNav(
      currentIndex: 1,
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).pop();
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
          (_) => false,
        );
      },
    );
  }
}

/// Combine the latest emissions of two streams into a single stream of
/// `List<QuerySnapshot>`. Emits whenever either input stream emits.
Stream<List<QuerySnapshot>> _combineLatest2(
  Stream<QuerySnapshot> a,
  Stream<QuerySnapshot> b,
) {
  late StreamController<List<QuerySnapshot>> controller;
  QuerySnapshot? lastA;
  QuerySnapshot? lastB;
  StreamSubscription<QuerySnapshot>? subA;
  StreamSubscription<QuerySnapshot>? subB;

  void tryEmit() {
    if (lastA != null && lastB != null) {
      controller.add([lastA!, lastB!]);
    }
  }

  controller = StreamController<List<QuerySnapshot>>(
    onListen: () {
      subA = a.listen((event) {
        lastA = event;
        tryEmit();
      }, onError: controller.addError);
      subB = b.listen((event) {
        lastB = event;
        tryEmit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}

class _IncomeItem {
  final String title;
  final String amount;
  final String source;
  final String? status;
  final DateTime? createdAt;
  final String? note;
  final String? createdBy;
  final String? createdByEmail;
  final bool isManual;

  _IncomeItem({
    required this.title,
    required this.amount,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.note,
    required this.createdBy,
    required this.createdByEmail,
    required this.isManual,
  });

  factory _IncomeItem.fromDonation(Map<String, dynamic> data) {
    final ts = data["createdAt"] as Timestamp?;
    return _IncomeItem(
      title: (data["donationType"] ?? "").toString(),
      amount: data["amount"]?.toString() ?? "0",
      source: (data["paymentMethod"] ?? "").toString(),
      status: (data["status"] ?? "").toString(),
      createdAt: ts?.toDate(),
      note: null,
      createdBy: null,
      createdByEmail: null,
      isManual: false,
    );
  }

  factory _IncomeItem.fromManualIncome(Map<String, dynamic> data) {
    final ts = data["createdAt"] as Timestamp?;
    return _IncomeItem(
      title: (data["khat"] ?? "").toString(),
      amount: data["amount"]?.toString() ?? "0",
      source: "Manual",
      status: "Completed",
      createdAt: ts?.toDate(),
      note: (data["note"] ?? "").toString(),
      createdBy: (data["createdBy"] ?? "").toString(),
      createdByEmail: (data["createdByEmail"] ?? "").toString(),
      isManual: true,
    );
  }

  List<Widget> subtitleLines() {
    final dateStr = createdAt != null
        ? DateFormat("dd MMM yyyy, hh:mm a").format(createdAt!)
        : "N/A";

    final lines = <Widget>[
      Text("Amount : ৳ $amount"),
      Text("Source : $source"),
      if (status != null && status!.isNotEmpty) Text("Status : $status"),
      if (note != null && note!.isNotEmpty) Text("Note : $note"),
      if (createdBy != null && createdBy!.isNotEmpty)
        Text("Created By : $createdBy"),
      if (createdByEmail != null && createdByEmail!.isNotEmpty)
        Text("Email : $createdByEmail"),
      Text("Date : $dateStr"),
    ];
    return lines;
  }
}
