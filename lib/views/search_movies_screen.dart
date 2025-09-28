import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';

import 'movie_detail_and_play_screen.dart';
import 'recommendation_movies_screen.dart';

class SearchScreen extends StatefulWidget {
  final String apiKey;
  const SearchScreen({super.key, required this.apiKey});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<Movie>>? _searchResultsFuture;
  String _currentSearchQuery = '';
  late Future<List<Movie>> _topRatedFuture;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);

    _topRatedFuture = _fetchTopRatedMovies();

    _searchResultsFuture = _topRatedFuture;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (_searchController.text.isEmpty && _currentSearchQuery.isNotEmpty) {
      _performSearch('');
    }
  }

  Future<List<Movie>> _fetchTopRatedMovies() async {
    final uri = Uri.https('api.themoviedb.org', '/3/movie/top_rated', {
      'api_key': widget.apiKey,
      'language': 'en-US',
      'page': '1',
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        return results
            .map((json) => Movie.fromJson(json))
            .where((movie) => movie.posterPath.isNotEmpty)
            .take(10)
            .toList();
      } else {
        print(
          'Failed to fetch top-rated movies (status ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Error fetching top-rated: $e');
    }
    return [];
  }

  Future<List<Movie>> _searchMovies(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.https('api.themoviedb.org', '/3/search/movie', {
      'api_key': widget.apiKey,
      'query': query,
      'language': 'en-US',
      'page': '1',
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        return results
            .map((json) => Movie.fromJson(json))
            .where((movie) => movie.posterPath.isNotEmpty)
            .toList();
      } else {
        print('Search API failed (status ${response.statusCode})');
      }
    } catch (e) {
      print('Error during search: $e');
    }
    return [];
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();

    if (trimmed == _currentSearchQuery &&
        (_searchResultsFuture != null || trimmed.isEmpty)) {
      return;
    }

    if (trimmed.isEmpty) {
      setState(() {
        _searchResultsFuture = _topRatedFuture;
        _currentSearchQuery = '';
      });
    } else {
      setState(() {
        _currentSearchQuery = trimmed;
        _searchResultsFuture = _searchMovies(trimmed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: TextField(
              controller: _searchController,
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search movies...',
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 16),
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white70,
                  size: 24,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              onSubmitted: (q) => _performSearch(q.trim()),
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Movie>>(
      future: _searchResultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              _currentSearchQuery.isEmpty
                  ? 'No top rated movies available.'
                  : 'No movies found for "$_currentSearchQuery"',
            ),
          );
        }

        final movies = snapshot.data!;
        final isTopRated = _currentSearchQuery.isEmpty;

        return MovieResultsView(
          movies: movies,
          viewType: isTopRated ? MovieViewType.grid : MovieViewType.list,
          onTap: (movie) {
            if (isTopRated) {
              _searchController.text = movie.title;
              _performSearch(movie.title);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MovieDetailScreen(movie: movie, apiKey: widget.apiKey),
                ),
              );
            }
          },
        );
      },
    );
  }
}

enum MovieViewType { grid, list }

class MovieResultsView extends StatelessWidget {
  final List<Movie> movies;
  final MovieViewType viewType;
  final Function(Movie) onTap;

  const MovieResultsView({
    super.key,
    required this.movies,
    required this.viewType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return const Center(child: Text('No movies found.'));
    }

    if (viewType == MovieViewType.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () => onTap(movie),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl:
                      'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: movies.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final movie = movies[index];
        return SearchMovieItem(movie: movie);
      },
    );
  }
}
