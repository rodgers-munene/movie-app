import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'movie_detail_and_play_screen.dart';
// Assuming this has playTrailer, fetchTrailer etc.

// --- 03) Recommendation Screen (Using TFLite and TMDB) ---

class ModelScoreItem {
  final int index;
  final double score;
  final int? tmdbId;
  final String? title;
  ModelScoreItem(this.index, this.score, {this.tmdbId, this.title});
}

class RecommendationScreen extends StatefulWidget {
  final String apiKey;
  const RecommendationScreen({super.key, required this.apiKey});

  @override
  _RecommendationScreenState createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final TextEditingController _titleController = TextEditingController();
  late Interpreter _interpreter;
  late List<Map<String, dynamic>> _moviesData;
  Future<List<Movie>>? _recommendedMoviesFuture;
  String _statusMessage = 'Load model and enter a movie title.';
  bool _isModelLoading = true;
  String _currentRecommendationTitle = '';
  List<_RecommendedMovieDisplayItem> _latestRecommendedDisplayItems = [];

  static const Color _scaffoldBgColor = Color(0xFF0D1117);
  static const Color _cardBgColor = Color(0xFF161B22);
  static const Color _accentColor = Color(0xFF58A6FF);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.blueGrey[200]!;

  @override
  void initState() {
    super.initState();
    _initModel();
    _titleController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onSearchTextChanged);
    _titleController.dispose();
    // Ensure interpreter is initialized before trying to close it
    if (!_isModelLoading && _interpreter.address != 0) {
      _interpreter.close();
    }
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initModel() async {
    try {
      setState(() {
        _isModelLoading = true;
        _statusMessage = 'Initializing AI model & movie data...';
      });

      String jsonString = await rootBundle.loadString('assets/movies_vectors.json');
      _moviesData = List<Map<String, dynamic>>.from(json.decode(jsonString));
      print('Loaded ${_moviesData.length} movies from JSON.');

      final modelFile = await rootBundle.load('assets/similarity_model.tflite');
      final modelBytes = modelFile.buffer.asUint8List();
      _interpreter = Interpreter.fromBuffer(modelBytes);
      print('TFLite model loaded.');

      setState(() {
        _isModelLoading = false;
        _statusMessage = 'AI model ready. Enter a movie title.';
      });

    } catch (e) {
      print('Error in _initModel: $e');
      if (mounted) {
        setState(() {
          _isModelLoading = false;
          _statusMessage = 'Error initializing AI: ${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}...';
        });
      }
    }
  }

  Future<void> _getRecommendations(String title) async {
    // Check if model is truly ready
    if (_isModelLoading || (_interpreter.address == 0 && title.trim().isNotEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model is still loading, please wait.', style: TextStyle(color: _textColor)), backgroundColor: _cardBgColor),
        );
      }
      return;
    }

    final trimmedTitle = title.trim();

    // If the title is empty, reset the screen to its initial state
    if (trimmedTitle.isEmpty) {
      if (mounted) {
        setState(() {
          _recommendedMoviesFuture = null;
          _latestRecommendedDisplayItems = [];
          _statusMessage = 'Please enter a movie title to search.'; // Or 'AI model ready...'
          _currentRecommendationTitle = '';
        });
      }
      return;
    }

    // Avoid re-searching if results are already displayed for the same title
    if (trimmedTitle.toLowerCase() == _currentRecommendationTitle.toLowerCase() &&
        _recommendedMoviesFuture != null &&
        _latestRecommendedDisplayItems.isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _recommendedMoviesFuture = null; // Indicate loading for new recommendations
        _latestRecommendedDisplayItems = []; // Clear previous display items
        _statusMessage = 'Finding recommendations for "$trimmedTitle"...';
        _currentRecommendationTitle = trimmedTitle;
      });
    }

    try {
      var selectedMovie = _moviesData.firstWhere(
            (m) => m['title'].toString().toLowerCase() == trimmedTitle.toLowerCase(),
        orElse: () => throw Exception('Movie "$trimmedTitle" not found in our local dataset.'),
      );
      List<double> inputVector = List<double>.from(selectedMovie['vector']);

      var input = [inputVector];
      var output = List.generate(1, (_) => List<double>.filled(_moviesData.length, 0.0));
      _interpreter.run(input, output);
      List<double> scores = output[0];

      List<ModelScoreItem> indexedScores = List.generate(
        _moviesData.length,
            (i) {
          final movieData = _moviesData[i];
          return ModelScoreItem(i, scores[i], tmdbId: movieData['id'] as int?, title: movieData['title'] as String?);
        },
      );

      indexedScores.sort((a, b) => b.score.compareTo(a.score));

      var topRecommendationsData = indexedScores
          .where((s) => s.tmdbId != selectedMovie['id'])
          .where((s) => s.tmdbId != null && s.title != null && s.score > 0.1)
          .take(40)
          .toList();

      List<Future<Movie?>> tmdbFutures = topRecommendationsData.map((item) async {
        if (item.tmdbId == null) return null;
        return _fetchMovieById(item.tmdbId!, item.score);
      }).toList();

      List<Movie?> tmdbMovies = await Future.wait(tmdbFutures);

      List<_RecommendedMovieDisplayItem> displayItems = [];
      for (int i = 0; i < tmdbMovies.length; i++) {
        final movie = tmdbMovies[i];
        final scoreItem = topRecommendationsData[i];
        if (movie != null && movie.posterPath.isNotEmpty) {
          displayItems.add(_RecommendedMovieDisplayItem(movie: movie, similarityScore: scoreItem.score));
        }
      }

      if (mounted) {
        setState(() {
          _latestRecommendedDisplayItems = displayItems;
          _recommendedMoviesFuture = Future.value(displayItems.map((item) => item.movie).toList());

          if (displayItems.isEmpty) {
            _statusMessage = 'No strong recommendations found for "$trimmedTitle". Try another title!';
          } else {
            _statusMessage = ''; // Clear status message if results are found
          }
        });
      }

    } catch (e) {
      print('Error in _getRecommendations: $e');
      if (mounted) {
        setState(() {
          _recommendedMoviesFuture = Future.value([]); // Reset to empty future on error
          _latestRecommendedDisplayItems = [];
          _statusMessage = 'Error: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<Movie?> _fetchMovieById(int movieId, double score) async {
    final uri = Uri.https(
      'api.themoviedb.org',
      '/3/movie/$movieId',
      {'api_key': widget.apiKey, 'language': 'en-US'},
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Movie.fromJson(json);
      } else {
        print('Failed to fetch movie $movieId by ID (status ${response.statusCode})');
        return null;
      }
    } catch (e) {
      print('Error fetching movie $movieId by ID: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the model is fully initialized and ready for use.
    bool modelReady = !_isModelLoading && _interpreter.address != 0;

    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        title: Text(
          'MovieMatch AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: _textColor),
        ),
        backgroundColor: _scaffoldBgColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                'Enter a movie title and our AI will find similar ones for you.',
                style: TextStyle(fontSize: 16, color: _secondaryTextColor, height: 1.4),
              ),
              const SizedBox(height: 24),

              // --- Input Section ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      // For a filled look with InputBorder.none, you might add decoration here:
                      // decoration: BoxDecoration(
                      //   color: Color(0xFF21262D), // Example subtle background
                      //   borderRadius: BorderRadius.circular(8.0), // Example radius
                      // ),
                      // padding: EdgeInsets.symmetric(horizontal: 8.0), // Padding if container has bg
                      child: TextField(
                        controller: _titleController,
                        autofocus: false,
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'e.g., Interstellar, Inception...', // Kept as per your code
                          hintStyle: const TextStyle(color: Colors.white70, fontSize: 16),
                          border: InputBorder.none, // No visible border line
                          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 24),
                          suffixIcon: _titleController.text.isNotEmpty
                              ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                _titleController.clear(); // Clears the text field
                                _getRecommendations(''); // Resets the recommendation state
                                // The listener _onSearchTextChanged will call setState
                                // and hide the clear button.
                              }
                          ) : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        onSubmitted: (title) {
                          if (modelReady) {
                            _getRecommendations(title.trim());
                          }
                        },
                        textInputAction: TextInputAction.search,
                        enabled: modelReady, // Enable only when model is fully ready
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: !modelReady // Disable if model is not ready
                        ? null
                        : () {
                      FocusScope.of(context).unfocus();
                      _getRecommendations(_titleController.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(18),
                      elevation: 2,
                    ),
                    child: !modelReady && _isModelLoading // Show spinner only during initial model load
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: _textColor.withOpacity(0.7)),
                    )
                        : Icon(Icons.arrow_forward_ios_rounded, color: _textColor, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Status/Input Movie Info ---
              // Show status message if not initializing model OR if it's an error during init
              if (_statusMessage.isNotEmpty && (!(_isModelLoading && _statusMessage.toLowerCase().contains('initializing')) || _statusMessage.toLowerCase().contains('error')))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Center(
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _statusMessage.toLowerCase().contains('error') || _statusMessage.toLowerCase().contains('not found')
                            ? Colors.redAccent[100]?.withOpacity(0.9)
                            : _secondaryTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

              // Specific loader for initial model loading
              if (_isModelLoading && _statusMessage.toLowerCase().contains('initializing') && !_statusMessage.toLowerCase().contains('error'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: _accentColor),
                        const SizedBox(height: 15),
                        Text(
                          _statusMessage,
                          style: TextStyle(color: _secondaryTextColor, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              if (_currentRecommendationTitle.isNotEmpty && _latestRecommendedDisplayItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Recommendations for "$_currentRecommendationTitle":',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textColor),
                  ),
                ),

              // --- Results Section ---
              Expanded(
                child: _buildRecommendationsList(modelReady),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsList(bool modelReady) {
    // If model is not ready and we are not showing the specific init loader above,
    // don't attempt to build list or show other loaders.
    if (!modelReady && !(_isModelLoading && _statusMessage.toLowerCase().contains('initializing'))) {
      // Status message for "Error initializing AI" or "Model loading..." is handled in the main column.
      return const SizedBox.shrink();
    }

    // If the future is null (initial state after model load or after clearing) and no items,
    // status message above handles "Please enter a movie title".
    if (_recommendedMoviesFuture == null && _latestRecommendedDisplayItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Movie>>(
      future: _recommendedMoviesFuture,
      builder: (context, snapshot) {
        // Show loading spinner while fetching recommendations (after model is loaded)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accentColor));
        }

        if (snapshot.hasError) {
          // Error for fetching recommendations is usually set in _statusMessage
          // and displayed by the Text widget in the main Column.
          print('Recommendations List FutureBuilder error: ${snapshot.error}');
          return const SizedBox.shrink(); // Let main status message handle display.
        }

        // If future is resolved, but display items are empty (e.g., "No results found")
        if (_latestRecommendedDisplayItems.isEmpty) {

          if (_currentRecommendationTitle.isNotEmpty && _statusMessage.isEmpty) {

            return Center(
              child: Text(
                'No similar movies found for "$_currentRecommendationTitle".',
                style: TextStyle(color: _secondaryTextColor, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }
          return const SizedBox.shrink(); // Let main status message handle display.
        }

        // Display the recommended movies
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16.0),
          itemCount: _latestRecommendedDisplayItems.length,
          itemBuilder: (context, index) {
            final displayItem = _latestRecommendedDisplayItems[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: InkWell(
                onTap: () {

                final movie = displayItem.movie;
                final score = displayItem.similarityScore;

                //Then inside onTap:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailScreen(
                      movie: movie, // Now 'movie' is defined
                      apiKey: widget.apiKey,
                    ),
                  ),
                );

                  // --- End Changed ---
                },
                borderRadius: BorderRadius.circular(12.0),
                child: RecommendedMovieItem(
                  movie: displayItem.movie,
                  similarityScore: displayItem.similarityScore,
                  cardBgColor: _cardBgColor,
                  textColor: _textColor,
                  secondaryTextColor: _secondaryTextColor,
                  accentColor: _accentColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}




// --- Helper class to pass Movie and Score together ---
class _RecommendedMovieDisplayItem {
  final Movie movie;
  final double similarityScore;
  _RecommendedMovieDisplayItem({required this.movie, required this.similarityScore});
}

// --- Shared Data Model (Movie) ---
class Movie {
  final int id;
  final String title;
  final String posterPath;
  final double rating;
  final String releaseDate;
  final String overview;

  Movie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.rating,
    required this.releaseDate,
    required this.overview,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Title',
      posterPath: json['poster_path'] ?? '',
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] ?? 'Unknown Date',
      overview: json['overview'] ?? 'No overview available.',
    );
  }
}

// --- RecommendedMovieItem Widget (Assumed to be the one from previous step) ---
class RecommendedMovieItem extends StatelessWidget {
  final Movie movie;
  final double similarityScore;
  final Color cardBgColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;

  const RecommendedMovieItem({
    super.key,
    required this.movie,
    required this.similarityScore,
    required this.cardBgColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (movie.posterPath.isEmpty) {
      return const SizedBox.shrink();
    }

    String year = 'N/A';
    if (movie.releaseDate.isNotEmpty && movie.releaseDate != 'Unknown Date') {
      year = movie.releaseDate.split('-').first;
    }

    Color scoreColor = Colors.greenAccent.shade400;
    if (similarityScore < 0.7) scoreColor = Colors.orangeAccent.shade400;
    if (similarityScore < 0.4) scoreColor = Colors.redAccent.shade200;

    return Card(
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: cardBgColor,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w154${movie.posterPath}',
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 120,
                  color: secondaryTextColor.withOpacity(0.1),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: accentColor.withOpacity(0.6))),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 120,
                  color: secondaryTextColor.withOpacity(0.1),
                  child: Icon(Icons.movie_creation_outlined, color: secondaryTextColor, size: 35),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${movie.rating.toStringAsFixed(1)}/10',
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today_rounded, color: secondaryTextColor.withOpacity(0.7), size: 15),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          year,
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (movie.overview.isNotEmpty && movie.overview != 'No overview available.')
                    Text(
                      movie.overview,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor.withOpacity(0.85), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: scoreColor.withOpacity(0.5), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          similarityScore > 0.6 ? Icons.thumb_up_alt_rounded : Icons.online_prediction_rounded,
                          color: scoreColor,
                          size: 13
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(similarityScore * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Match',
                  style: TextStyle(fontSize: 10, color: secondaryTextColor.withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared Widgets (MovieCard, SearchMovieItem) ---
class MovieCard extends StatelessWidget {
  final Movie movie;
  const MovieCard({super.key, required this.movie});
  @override
  Widget build(BuildContext context) {
    if (movie.posterPath.isEmpty) { return const SizedBox.shrink();}
    const Color cardBgColor = Color(0xFF161B22);
    const Color textColor = Colors.white;
    final Color secondaryTextColor = Colors.blueGrey[200]!;

    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0,3),
            )
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: secondaryTextColor.withOpacity(0.1),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: textColor.withOpacity(0.5))),
                ),
                errorWidget: (context, url, error) => Container(
                  color: secondaryTextColor.withOpacity(0.1),
                  child: Icon(Icons.error_outline, color: Colors.redAccent[100]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${movie.rating.toStringAsFixed(1)}/10',
                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  movie.releaseDate.isNotEmpty && movie.releaseDate != 'Unknown Date'
                      ? movie.releaseDate.split('-').first
                      : 'Year N/A',
                  style: TextStyle(fontSize: 12, color: secondaryTextColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SearchMovieItem extends StatelessWidget {
  final Movie movie;
  const SearchMovieItem({ super.key, required this.movie});
  @override
  Widget build(BuildContext context) {
    if (movie.posterPath.isEmpty) { return const SizedBox.shrink();}
    const Color textColor = Colors.white;
    final Color secondaryTextColor = Colors.blueGrey[200]!;
    final Color placeholderBg = secondaryTextColor.withOpacity(0.1);

    String year = 'N/A';
    if (movie.releaseDate.isNotEmpty && movie.releaseDate != 'Unknown Date') {
      year = movie.releaseDate.split('-').first;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: 'https://image.tmdb.org/t/p/w154${movie.posterPath}',
              width: 75,
              height: 112,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 75, height: 112, color: placeholderBg,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: textColor.withOpacity(0.5))),
              ),
              errorWidget: (context, url, error) => Container(
                width: 75, height: 112, color: placeholderBg,
                child: Icon(Icons.movie_creation_outlined, color: secondaryTextColor, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${movie.rating.toStringAsFixed(1)}/10',
                        style: TextStyle(fontSize: 15, color: secondaryTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        year,
                        style: TextStyle(fontSize: 15, color: secondaryTextColor.withOpacity(0.8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (movie.overview.isNotEmpty && movie.overview != 'No overview available.')
                  Text(
                    movie.overview,
                    style: TextStyle(fontSize: 13, color: secondaryTextColor.withOpacity(0.7), height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}