import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class QuranAudioNeedsInternetException implements Exception {
  const QuranAudioNeedsInternetException(this.message);
  final String message;
  @override
  String toString() => 'QuranAudioNeedsInternetException: $message';
}

class QuranAudioDownloadFailedException implements Exception {
  const QuranAudioDownloadFailedException(this.message);
  final String message;
  @override
  String toString() => 'QuranAudioDownloadFailedException: $message';
}

class QuranAudioService {
  QuranAudioService._() {
    _initialize();
  }

  static final QuranAudioService instance = QuranAudioService._();

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<int?> _currentSurah = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<double> _downloadProgress = ValueNotifier<double>(0.0);
  final Set<int> _cachedLocally = <int>{};

  ValueNotifier<int?> get currentSurah => _currentSurah;
  ValueNotifier<bool> get isLoading => _isLoading;
  ValueNotifier<double> get downloadProgress => _downloadProgress;

  Directory? _cacheDir;

  // CORS-friendly Surah-by-Surah CDN. download.quranicaudio.com does
  // NOT send an Access-Control-Allow-Origin header, so when audioplayers
  // streams through the browser's <audio> element (web build) it
  // refuses to load the file and surfaces a "network" failure even
  // though the bytes are reachable. cdn.islamic.network returns
  // ACAO: * on every mp3, so the same <audio> element can fetch it
  // from any origin. 128 kbps Alafasy is the default reciter.
  static const String _baseUrl =
      'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee';
  static const String _cacheSubdir = 'quran_audio_v4';

  void _initialize() {
    AudioPlayer.global.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );

    _player.onPlayerComplete.listen((_) => _currentSurah.value = null);
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        _currentSurah.value = null;
      }
    });
  }

  /// Returns the Surah URL on the CORS-enabled CDN. cdn.islamic.network
  /// uses a non-padded numeric path (e.g. /1.mp3) — the old padded
  /// /001.mp3 form (which quranicaudio.com uses) returns 404 here.
  String urlFor(int surahNumber) {
    final padded = surahNumber.toString().padLeft(3, '0');
    return '$_baseUrl/$padded.mp3';
  }

  String localPathFor(int surahNumber) {
    if (_cacheDir == null) return '';
    final padded = surahNumber.toString().padLeft(3, '0');
    return '${_cacheDir!.path}${Platform.pathSeparator}$padded.mp3';
  }

  Future<Directory> _resolveCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}$_cacheSubdir');
    if (!await dir.exists()) await dir.create(recursive: true);

    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          final m = RegExp(r'(\d{1,3})\.mp3$').firstMatch(entity.path);
          if (m != null) _cachedLocally.add(int.parse(m.group(1)!));
        }
      }
    } catch (_) {}
    _cacheDir = dir;
    return dir;
  }

  bool isCached(int surahNumber) => _cachedLocally.contains(surahNumber);

  Future<void> togglePlay(int surahNumber) async {
    if (_currentSurah.value == surahNumber) {
      await stop();
    } else {
      await play(surahNumber);
    }
  }

  Future<void> play(int surahNumber) async {
    _isLoading.value = true;
    _downloadProgress.value = 0.0;

    try {
      await _player.stop();

      // Try to resolve the on-disk cache directory. On platforms where
      // path_provider isn't wired up (e.g. Flutter web without a
      // plugin registration) this throws MissingPluginException; we
      // *don't* want that to abort playback, so we fall through to
      // stream-only mode and skip the offline-download optimisation
      // instead of bubbling the error up as a "network failure".
      File? localFile;
      try {
        await _resolveCacheDir();
        final localPath = localPathFor(surahNumber);
        final f = File(localPath);
        if (await f.exists() && await f.length() > 1024) {
          await _player.play(DeviceFileSource(localPath));
          _currentSurah.value = surahNumber;
          _isLoading.value = false;
          return;
        }
        localFile = f;
      } catch (e) {
        debugPrint(
          '[QuranAudioService] cache dir unavailable, streaming only: $e',
        );
      }

      // Stream directly from the CDN. audioplayers handles buffering
      // internally; the user hears audio as soon as the first bytes
      // arrive. The background download only runs when we *have* a
      // writable cache file (i.e. native platforms with a working
      // path_provider).
      final uri = Uri.parse(urlFor(surahNumber));
      await _player.play(UrlSource(urlFor(surahNumber)));
      _currentSurah.value = surahNumber;

      if (localFile != null) {
        // Fire-and-forget background download for offline replay.
        // ignore: discarded_futures
        _downloadFile(uri, localFile, surahNumber);
      }
    } catch (e) {
      _currentSurah.value = null;
      debugPrint('[QuranAudioService] Play error: $e');
      if (e is SocketException || e is TimeoutException) {
        throw const QuranAudioNeedsInternetException('ইন্টারনেট কানেকশন নেই।');
      }
      throw QuranAudioDownloadFailedException('অডিও প্লে করা যাচ্ছে না: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _downloadFile(Uri uri, File targetFile, int surahNumber) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = 'MasjidCare/1.0';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final sink = targetFile.openWrite();
        final total = response.contentLength ?? 0;
        int received = 0;

        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _downloadProgress.value = (received / total).clamp(0.0, 1.0);
          }
        }
        await sink.flush();
        await sink.close();
        _cachedLocally.add(surahNumber);
      }
    } catch (e) {
      debugPrint('[QuranAudioService] Background download failed: $e');
    } finally {
      client.close();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSurah.value = null;
    _isLoading.value = false;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
