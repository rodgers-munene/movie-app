import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'views/splash_screen.dart';
import 'dart:convert';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/services.dart';
import 'views/homescreen.dart';
import 'views/search_movies_screen.dart';
import 'views/recommendation_movies_screen.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- API Key ---
final String kApiKey = dotenv.env['API_KEY'] ?? '';

// --- Reusable API Functions ---
Future<String?> fetchTrailer(int movieId, String apiKey) async {
  final uri = Uri.https('api.themoviedb.org', '/3/movie/$movieId/videos', {
    'api_key': apiKey,
  });

  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final videos = data['results'] as List;
      final trailer = videos.firstWhere(
        (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
        orElse: () => videos.firstWhere(
          (v) => v['type'] == 'Teaser' && v['site'] == 'YouTube',
          orElse: () => videos.firstWhere(
            (v) => v['site'] == 'YouTube',
            orElse: () => null,
          ),
        ),
      );
      return trailer?['key'];
    }
    print(
      'Failed to fetch trailer for $movieId (status ${response.statusCode})',
    );
    return null;
  } catch (e) {
    print('Error fetching trailer for $movieId: $e');
    return null;
  }
}

void playTrailer(BuildContext context, String videoId) {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
  ]);

  final controller = YoutubePlayerController(
    key: videoId,
    params: const YoutubePlayerParams(
      showControls: true,
      showFullscreenButton: true,
      mute: false,
      strictRelatedVideos: true,
    ),
  );

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * (9 / 16),
              child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
            ),
          ),
          Positioned(
            top: 8.0,
            right: 8.0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.of(context).pop();
                SystemChrome.setPreferredOrientations(DeviceOrientation.values);
              },
              padding: const EdgeInsets.all(8.0),
              color: Colors.black54,
              iconSize: 28.0,
              alignment: Alignment.topRight,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K Movies',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[900],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
          titleMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white70,
          iconColor: Colors.white70,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // <— show splash first
      routes: {'/main': (_) => const MainScreen()},
    );
  }
}

// --- Main Screen with Curved Navigation & PageView ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final PageController _pageController = PageController();
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  ); // ✅ initialized here

  final List<Widget> _screens = [
    HomeScreen(apiKey: kApiKey),
    SearchScreen(apiKey: kApiKey),
    RecommendationScreen(apiKey: kApiKey),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
    _tabController.index = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: ConvexAppBar(
        height: 60,
        controller: _tabController,
        backgroundColor: Colors.grey[900],
        activeColor: Colors.purple,
        color: Colors.white,
        style: TabStyle.react,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.search, title: 'Search'),
          TabItem(icon: Icons.favorite_border_outlined, title: 'Favourite'),
        ],
        initialActiveIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
