import 'package:flutter/material.dart';
import '../services/prayer_time_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class ForbiddenTimePage extends StatefulWidget {
  const ForbiddenTimePage({super.key});

  @override
  State<ForbiddenTimePage> createState() => _ForbiddenTimePageState();
}

class _ForbiddenTimePageState extends State<ForbiddenTimePage> {
  ForbiddenTimes? _forbiddenTimes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimings();
  }

  Future<void> _loadTimings() async {
    try {
      final timings = await PrayerTimeService.fetchTodayTimings();
      if (!mounted) return;
      setState(() {
        _forbiddenTimes = PrayerScheduleBuilder.buildForbiddenTimes(timings);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Fallback to default timings if service fails
        _forbiddenTimes = PrayerScheduleBuilder.buildForbiddenTimes(
          PrayerTimeService.fallbackTimings(),
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to language changes so titles refresh on toggle.
    SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _loading = true);
              _loadTimings();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadTimings,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildForbiddenCard(
                        Tr.forbiddenSunrise(context),
                        PrayerScheduleBuilder.formatRange(
                          _forbiddenTimes!.sunriseWindow,
                        ),
                      ),
                      _buildForbiddenCard(
                        Tr.forbiddenMidday(context),
                        PrayerScheduleBuilder.formatRange(
                          _forbiddenTimes!.middayWindow,
                        ),
                      ),
                      _buildForbiddenCard(
                        Tr.forbiddenSunset(context),
                        PrayerScheduleBuilder.formatRange(
                          _forbiddenTimes!.sunsetWindow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Tr.forbiddenTitle(context),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildForbiddenCard(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.block_rounded,
              color: Color(0xFFE11D48),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFE11D48),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
