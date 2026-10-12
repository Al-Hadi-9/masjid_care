import 'package:flutter/material.dart';
import '../widgets/app_appbar.dart';

class IslamicEventPage extends StatelessWidget {
  const IslamicEventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(title: AppAppBar.kMasjidName),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E4E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "আসন্ন ইসলামিক ইভেন্ট",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          buildEventCard(
            month: "ফেব্রুয়ারি",
            day: "৮/৯",
            title: "পবিত্র রমজান শুরু",
            highlight: true,
          ),

          buildEventCard(month: "মার্চ", day: "০৬", title: "লাইলাতুল কদর"),

          buildEventCard(month: "মার্চ", day: "১০", title: "ঈদুল ফিতর"),

          buildEventCard(month: "মে", day: "১৭", title: "ঈদুল আযহা"),

          buildEventCard(month: "জুন", day: "১৭", title: "আশুরা"),
        ],
      ),
    );
  }

  Widget buildEventCard({
    required String month,
    required String day,
    required String title,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? const Color(0xFF1B5E4E).withValues(alpha: 0.3)
              : const Color(0xFFE8EEF1),
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? const Color(0xFF1B5E4E).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 78,
              decoration: BoxDecoration(
                gradient: highlight
                    ? const LinearGradient(
                        colors: [Color(0xFF0F4538), Color(0xFF1B5E4E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: highlight ? null : const Color(0xFFF1F8F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlight
                      ? Colors.transparent
                      : const Color(0xFF1B5E4E).withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: highlight
                          ? const Color(0xFF008000)
                          : const Color(0xFF1B5E4E),
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: highlight
                          ? Colors.white70
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '২০২৭',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: highlight
                          ? Colors.white70
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (highlight)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: const Text(
                            'বিশেষ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
