import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF1DB954),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String audioPath;
  final String? albumArt;

  Song({
    required this.title,
    required this.artist,
    required this.audioPath,
    this.albumArt,
  });
}

class AudioManager {
  static final AudioPlayer player = AudioPlayer();
  static Song? currentSong;
  static bool isPlaying = false;
  static Duration duration = Duration.zero;
  static Duration position = Duration.zero;

  static List<Song> playlist = [];
  static int currentIndex = 0;
  static bool isLooping = false;

  static void init() {
    player.onDurationChanged.listen((d) {
      duration = d;
    });
    player.onPositionChanged.listen((p) {
      position = p;
    });
    player.onPlayerStateChanged.listen((state) {
      isPlaying = state == PlayerState.playing;
    });
    player.onPlayerComplete.listen((_) async {
      if (isLooping) {
        await player.seek(Duration.zero);
        await player.resume();
      } else {
        await next();
      }
    });
  }

  static Future<void> playSong(Song song, {List<Song>? queue}) async {
    try {
      debugPrint('▶️ playSong called: ${song.audioPath}');
      if (queue != null) {
        playlist = queue;
        currentIndex = playlist.indexWhere(
          (s) => s.audioPath == song.audioPath,
        );
      }
      if (currentSong?.audioPath != song.audioPath) {
        await player.stop();
        debugPrint('   stop() done');
        await player.play(AssetSource(song.audioPath));
        debugPrint('   play() done');
        currentSong = song;
      } else {
        await player.resume();
        debugPrint('   resume() done');
      }
      isPlaying = true;
    } catch (e, st) {
      debugPrint('❌ playSong ERROR: $e');
      debugPrint('$st');
    }
  }

  static Future<void> togglePlayPause() async {
    if (player.state == PlayerState.playing) {
      await player.pause();
      isPlaying = false;
    } else {
      await player.resume();
      isPlaying = true;
    }
  }

  static Future<void> next() async {
    if (playlist.isEmpty) return;
    currentIndex = (currentIndex + 1) % playlist.length;
    final song = playlist[currentIndex];
    await player.stop();
    await player.play(AssetSource(song.audioPath));
    currentSong = song;
    isPlaying = true;
  }

  static Future<void> previous() async {
    if (playlist.isEmpty) return;
    currentIndex = (currentIndex - 1 + playlist.length) % playlist.length;
    final song = playlist[currentIndex];
    await player.stop();
    await player.play(AssetSource(song.audioPath));
    currentSong = song;
    isPlaying = true;
  }

  static void toggleLoop() {
    isLooping = !isLooping;
  }

  static Future<void> stop() async {
    await player.stop();
    isPlaying = false;
    currentSong = null;
    duration = Duration.zero;
    position = Duration.zero;
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // ============================================================
  // UPDATED: Tumutugma na sa existing filenames mo
  // (song1.mp3, song2.mp3, song3.mp3, song4.mp3, song5.mp3)
  // ============================================================
  final List<Song> _songs = [
    Song(
      title: '21 (You)',
      artist: 'damianx',
      audioPath: 'song5.mp3',
    ),
    Song(
      title: 'ILYSB',
      artist: 'LANY',
      audioPath: 'song1.mp3',
    ),
    Song(
      title: 'Malibu Nights',
      artist: 'LANY',
      audioPath: 'song2.mp3',
    ),
    Song(
      title: 'Super Far',
      artist: 'LANY',
      audioPath: 'song3.mp3',
    ),
    Song(
      title: 'Thru These Tears',
      artist: 'LANY',
      audioPath: 'song4.mp3',
    ),
  ];

  @override
  void initState() {
    super.initState();
    AudioManager.init();
    _checkAssets();
  }

  // Diagnostic: I-check kung nandiyan lahat ng audio files
  Future<void> _checkAssets() async {
    const files = [
      'song1.mp3',
      'song2.mp3',
      'song3.mp3',
      'song4.mp3',
      'song5.mp3',
    ];
    for (final name in files) {
      try {
        await rootBundle.load('assets/audio/$name');
        debugPrint('✅ FOUND: $name');
      } catch (e) {
        debugPrint('❌ MISSING: $name — $e');
      }
    }
  }

  void _openPlayer(Song song) async {
    await AudioManager.playSong(song, queue: _songs);
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _backToLibrary() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        LibraryScreen(
          songs: _songs,
          onSongTap: _openPlayer,
          onOpenPlayer: () {
            setState(() {
              _selectedIndex = 1;
            });
          },
        ),
        AudioPlayerScreen(onBack: _backToLibrary),
      ],
    );
  }
}

class LibraryScreen extends StatefulWidget {
  final List<Song> songs;
  final Function(Song) onSongTap;
  final VoidCallback onOpenPlayer;

  const LibraryScreen({
    super.key,
    required this.songs,
    required this.onSongTap,
    required this.onOpenPlayer,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    _positionSub = AudioManager.player.onPositionChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _durationSub = AudioManager.player.onDurationChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  List<Song> get _filteredSongs {
    if (_searchQuery.isEmpty) return widget.songs;
    return widget.songs.where((song) {
      return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          song.artist.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _filteredSongs;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search songs or artist...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text(
                'YOUR LIBRARY',
                style: TextStyle(fontSize: 14, letterSpacing: 2),
              ),
        leading: IconButton(
          icon: Icon(_isSearching ? Icons.arrow_back : Icons.library_music),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: songs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 60, color: Colors.grey.shade700),
                        const SizedBox(height: 12),
                        Text(
                          'No songs found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Songs (${songs.length})',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...songs.map((song) => _buildSongTile(song)),
                    ],
                  ),
          ),
          if (AudioManager.currentSong != null) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildSongTile(Song song) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1DB954), Color(0xFF0D5C2A)],
          ),
          image: song.albumArt != null
              ? DecorationImage(
                  image: AssetImage(song.albumArt!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: song.albumArt == null
            ? const Icon(Icons.music_note, color: Colors.white, size: 30)
            : null,
      ),
      title: Text(
        song.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      ),
      trailing: const Icon(Icons.play_circle_outline,
          color: Color(0xFF1DB954), size: 32),
      onTap: () => widget.onSongTap(song),
    );
  }

  Widget _buildMiniPlayer() {
    final song = AudioManager.currentSong!;
    final duration = AudioManager.duration;
    final position = AudioManager.position;

    final double progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: widget.onOpenPlayer,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          border: Border(
            top: BorderSide(color: Colors.grey.shade800),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade800,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1DB954),
                ),
              ),
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  image: song.albumArt != null
                      ? DecorationImage(
                          image: AssetImage(song.albumArt!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  gradient: song.albumArt == null
                      ? const LinearGradient(
                          colors: [Color(0xFF1DB954), Color(0xFF0D5C2A)],
                        )
                      : null,
                ),
                child: song.albumArt == null
                    ? const Icon(Icons.music_note,
                        color: Colors.white, size: 22)
                    : null,
              ),
              title: Text(
                song.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(
                  AudioManager.player.state == PlayerState.playing
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () async {
                  await AudioManager.togglePlayPause();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioPlayerScreen extends StatefulWidget {
  final VoidCallback onBack;
  const AudioPlayerScreen({super.key, required this.onBack});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    AudioManager.player.onDurationChanged.listen((d) {
      if (mounted) setState(() {});
    });

    AudioManager.player.onPositionChanged.listen((p) {
      if (mounted) setState(() {});
    });

    AudioManager.player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {});
      if (state == PlayerState.playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });

    AudioManager.player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {});
      _rotationController.stop();
      _rotationController.reset();
    });
  }

  void stopAudio() async {
    await AudioManager.stop();
    _rotationController.stop();
    _rotationController.reset();
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Widget _buildDisc() {
    final song = AudioManager.currentSong;
    final albumArt = song?.albumArt;
    return RotationTransition(
      turns: _rotationController,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 25,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              albumArt != null
                  ? Image.asset(albumArt,
                      width: 260, height: 260, fit: BoxFit.cover)
                  : Container(
                      width: 260,
                      height: 260,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFFB71C1C),
                            Color(0xFFD32F2F),
                            Color(0xFF8B0000),
                          ],
                          stops: [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.cyan.withValues(alpha: 0.06),
                      Colors.purple.withValues(alpha: 0.06),
                      Colors.pink.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
              for (final size in [230.0, 200.0, 170.0, 140.0, 110.0])
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8),
                  ),
                ),
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey.shade700, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTonearm(bool isPlaying) {
    return Transform.rotate(
      angle: isPlaying ? 0.35 : 0.6,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
              ),
            ),
          ),
          Container(
            width: 4,
            height: 95,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE0E0E0), Color(0xFF757575)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 18,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF424242),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = AudioManager.currentSong;
    final isPlaying = AudioManager.player.state == PlayerState.playing;
    final duration = AudioManager.duration;
    final position = AudioManager.position;
    final isLooping = AudioManager.isLooping;

    if (song == null) {
      return const Scaffold(
        body: Center(
          child: Text('No song playing',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'NOW PLAYING',
          style: TextStyle(fontSize: 12, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Expanded(
              flex: 5,
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildDisc(),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildTonearm(isPlaying),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFFFEB3B),
                      shadows: [
                        Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(1, 1)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFFFEB3B),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade800,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: position.inSeconds.toDouble().clamp(
                          0,
                          duration.inSeconds.toDouble(),
                        ),
                    max: duration.inSeconds.toDouble() > 0
                        ? duration.inSeconds.toDouble()
                        : 1,
                    onChanged: (value) async {
                      await AudioManager.player
                          .seek(Duration(seconds: value.toInt()));
                      setState(() {});
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      Text(_formatDuration(duration),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    isLooping ? Icons.repeat_one : Icons.repeat,
                    color: isLooping ? const Color(0xFF1DB954) : Colors.grey,
                  ),
                  iconSize: 26,
                  onPressed: () {
                    AudioManager.toggleLoop();
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 40),
                  onPressed: () async {
                    await AudioManager.previous();
                    setState(() {});
                  },
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: isPlaying
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFF1DB954).withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ]
                        : [],
                  ),
                  child: IconButton(
                    iconSize: 45,
                    padding: const EdgeInsets.all(12),
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                    ),
                    onPressed: () async {
                      await AudioManager.togglePlayPause();
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white, size: 40),
                  onPressed: () async {
                    await AudioManager.next();
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.grey),
                  iconSize: 26,
                  onPressed: stopAudio,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}