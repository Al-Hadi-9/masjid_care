import 'package:flutter/material.dart';
import 'quran_page.dart';
import 'hadith_page.dart';
import 'islamic_books_page.dart';
import 'dua_zikir_page.dart';
import '../services/settings_service.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    // Subscribe to language changes so the library title and card labels
    // flip between Bangla and English when the user toggles Settings.
    SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      // Persistent AppBar/BottomNav live in [AppShell].
      body: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
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
                  Text(
                    Tr.libraryTitle(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.90,
                  children: [
                    _buildLibraryCard(
                      Tr.libraryQuran(context),
                      Icons.menu_book_rounded,
                      const Color(0xFF1B5E4E),
                      const Color(0xFFE8F5E9),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuranPage()),
                        );
                      },
                    ),

                    _buildLibraryCard(
                      Tr.libraryHadith(context),
                      Icons.auto_stories_rounded,
                      const Color(0xFF2E7D32),
                      const Color(0xFFE8F5E9),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HadithPage()),
                        );
                      },
                    ),

                    _buildLibraryCard(
                      Tr.libraryBooks(context),
                      Icons.book_rounded,
                      const Color(0xFF2563EB),
                      const Color(0xFFEFF6FF),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IslamicBooksPage(),
                          ),
                        );
                      },
                    ),

                    _buildLibraryCard(
                      Tr.libraryDuaZikir(context),
                      Icons.volunteer_activism_rounded,
                      const Color(0xFF8B5CF6),
                      const Color(0xFFF5F3FF),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DuaZikirPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryCard(
    String title,
    IconData icon,
    Color iconColor,
    Color iconBg,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF3F5F8),
                Color(0xFFE2E7EC),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.45, 1.0],
            ),
            border: Border.all(
              color: const Color(0xFFCFD8DF),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      iconBg,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 2,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 36),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
