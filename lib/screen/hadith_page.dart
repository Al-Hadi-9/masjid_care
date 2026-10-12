import 'package:flutter/material.dart';

import '../services/hadith_api.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class HadithPage extends StatefulWidget {
  const HadithPage({super.key});

  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  bool _loading = false;
  List<Hadith> _all = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final list = await HadithApi.fetchAll();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Tr.hadithLoadFailed(context)}$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Hadith> get _filteredAll {
    if (_filter == 'all') return _all;
    if (_filter == 'bukhari') {
      return _all.where((h) => h.collection.contains('বুখারী')).toList();
    }
    return _all.where((h) => h.collection.contains('মুসলিম')).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to language changes so all UI chrome here rebuilds when
    // the user flips the toggle in Settings.
    SettingsScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: Tr.hadithTitle(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _filterChip(Tr.hadithFilterAll(context), 'all'),
                const SizedBox(width: 8),
                _filterChip(Tr.hadithFilterBukhari(context), 'bukhari'),
                const SizedBox(width: 8),
                _filterChip(Tr.hadithFilterMuslim(context), 'muslim'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildAllList(),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String key) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B5E4E) : const Color(0xFFF0F4F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1B5E4E) : const Color(0xFFDCE3E6),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF5A6B78),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAllList() {
    final list = _filteredAll;
    if (list.isEmpty) {
      return Center(
        child: Text(
          Tr.hadithNoHadiths(context),
          style: const TextStyle(color: Color(0xFF7F8C8D)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: list.length,
      itemBuilder: (context, i) => _buildHadithCard(list[i]),
    );
  }

  Widget _buildHadithCard(Hadith h) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTokens.borderLight),
        boxShadow: AppTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC8E6C9)),
                ),
                child: Text(
                  h.collection,
                  style: const TextStyle(
                    color: Color(0xFF1B5E4E),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${h.book} — ${h.chapter}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            h.bangla,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
              height: 1.6,
            ),
          ),
          if (h.arabic.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8EEF1)),
              ),
              child: Text(
                h.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1B5E4E),
                  height: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF7F8C8D)),
                const SizedBox(width: 6),
                Text(
                  h.narrator,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A6B78),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
