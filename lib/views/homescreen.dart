import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

import 'movie_detail_and_play_screen.dart';
import 'recommendation_movies_screen.dart';

class HomeScreen extends StatefulWidget {
  final String apiKey;
  const HomeScreen({super.key, required this.apiKey});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Movie>>? trendingMovies;
  Future<List<Movie>>? nowPlayingMovies;
  Future<List<Movie>>? popularMovies;
  Future<List<Movie>>? topRatedMovies;
  Future<List<Movie>>? upcomingMovies;
  Future<List<Movie>>? actionMovies;
  Future<List<Movie>>? horrorMovies;
  Future<List<Movie>>? familyMovies;
  Future<List<Movie>>? comedyMovies;
  Future<List<Movie>>? spaceMovies;
  Future<List<Movie>>? latestMovies;

  @override
  void initState() {
    super.initState();

    trendingMovies = fetchMovies('trending/movie/week');
    nowPlayingMovies = fetchMovies('movie/now_playing');
    popularMovies = fetchMovies('movie/popular');
    topRatedMovies = fetchMovies('movie/top_rated');
    upcomingMovies = fetchMovies('movie/upcoming');

    actionMovies = fetchMovies(
      'discover/movie',
      extraParams: {'with_genres': '28', 'sort_by': 'popularity.desc'},
    );
    horrorMovies = fetchMovies(
      'discover/movie',
      extraParams: {'with_genres': '27', 'sort_by': 'popularity.desc'},
    );
    familyMovies = fetchMovies(
      'discover/movie',
      extraParams: {'with_genres': '10751', 'sort_by': 'popularity.desc'},
    );

    comedyMovies = fetchMovies(
      'discover/movie',
      extraParams: {'with_genres': '35', 'sort_by': 'popularity.desc'},
    );
    spaceMovies = fetchSpaceMovies(pages: 3);

    latestMovies = fetchMovies('movie/now_playing');
  }

  Future<List<Movie>> fetchMovies(
    String endpoint, {
    Map<String, String>? extraParams,
    int page = 1,
  }) async {
    final params = {
      'api_key': widget.apiKey,
      'language': 'en-US',
      'page': '$page',
      if (extraParams != null) ...extraParams,
    };

    final uri = Uri.https('api.themoviedb.org', '/3/$endpoint', params);

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        print('Failed to load $endpoint (status ${response.statusCode})');
        return [];
      }

      final data = json.decode(response.body);
      return (data['results'] as List)
          .take(30)
          .map((json) => Movie.fromJson(json))
          .where((movie) => movie.posterPath.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching $endpoint: $e');
      return [];
    }
  }

  Future<int?> fetchSpaceKeyword() async {
    final uri = Uri.https('api.themoviedb.org', '/3/search/keyword', {
      'api_key': widget.apiKey,
      'query': 'space',
    });
    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      final List results = json.decode(resp.body)['results'];
      return results.isNotEmpty ? results.first['id'] as int : null;
    } catch (e) {
      print('Error fetching space keyword: $e');
      return null;
    }
  }

  Future<List<Movie>> fetchSpaceMovies({int pages = 3}) async {
    final keywordId = await fetchSpaceKeyword();
    if (keywordId == null) return [];

    List<Movie> all = [];

    final params = {
      'api_key': widget.apiKey,
      'with_genres': '878',
      'with_keywords': '$keywordId',
      'sort_by': 'popularity.desc',
      'language': 'en-US',
    };

    for (var page = 1; page <= pages; page++) {
      final uri = Uri.https('api.themoviedb.org', '/3/discover/movie', {
        ...params,
        'page': '$page',
      });
      try {
        final resp = await http.get(uri);
        if (resp.statusCode != 200) break;
        final List results = json.decode(resp.body)['results'];
        all.addAll(
          results
              .map((j) => Movie.fromJson(j))
              .where((movie) => movie.posterPath.isNotEmpty),
        );
      } catch (e) {
        print('Error fetching space movies page $page: $e');
        break;
      }
    }
    return all.take(50).toList();
  }

  Widget _buildSlideshow(Future<List<Movie>>? movies) {
    return FutureBuilder<List<Movie>>(
      future: movies,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                "No movies available",
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final latest = snapshot.data!.take(5).toList();

        return CarouselSlider.builder(
          options: CarouselOptions(
            height: 200,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.85,
            aspectRatio: 16 / 9,
          ),
          itemCount: latest.length,
          itemBuilder: (context, index, realIndex) {
            final movie = latest[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MovieDetailScreen(movie: movie, apiKey: widget.apiKey),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w780${movie.posterPath}',
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) =>
                          Container(color: Colors.grey[800]),
                      errorWidget: (ctx, url, error) =>
                          Icon(Icons.broken_image, color: Colors.grey),
                    ),
                    Container(
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSection(String title, Future<List<Movie>>? movies) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          FutureBuilder<List<Movie>>(
            future: movies,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              }

              final categoryMovies = snapshot.data ?? [];
              if (snapshot.hasError || categoryMovies.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Could not load $title.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              final moviesWithPosters = categoryMovies
                  .where((m) => m.posterPath.isNotEmpty)
                  .toList();

              if (moviesWithPosters.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'No movies with posters available in $title.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }

              return SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: moviesWithPosters.length,
                  itemBuilder: (context, index) {
                    final movie = moviesWithPosters[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieDetailScreen(
                              movie: movie,
                              apiKey: widget.apiKey,
                            ),
                          ),
                        );
                      },
                      child: MovieCard(movie: movie),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "K",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: "-Movies",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
            ),

            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {},
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.purpleAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _buildSlideshow(latestMovies),
            const SizedBox(height: 20),
            _buildSection('Trending Movies', trendingMovies),
            _buildSection('Now in Theaters', nowPlayingMovies),
            _buildSection('Popular Movies', popularMovies),
            _buildSection('Top Rated', topRatedMovies),
            _buildSection('Upcoming', upcomingMovies),
            _buildSection('Action', actionMovies),
            _buildSection('Comedy', comedyMovies),
            _buildSection('Horror', horrorMovies),
            _buildSection('Family', familyMovies),
            _buildSection('Science Fiction', spaceMovies),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class MovieCard extends StatelessWidget {
  final Movie movie;

  const MovieCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    if (movie.posterPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w342${movie.posterPath}',
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey[600],
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 15),
              const SizedBox(width: 4),
              Text(
                '${movie.rating.toStringAsFixed(1)}/10',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            movie.releaseDate.isNotEmpty && movie.releaseDate != 'Unknown Date'
                ? movie.releaseDate.split('-').first
                : 'Year N/A',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
