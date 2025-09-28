import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'recommendation_movies_screen.dart';
import '../main.dart';


class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  final String apiKey;

  final double? similarityScore;

  const MovieDetailScreen({
    super.key,
    required this.movie,
    required this.apiKey,
    this.similarityScore,
  });

  @override
  _MovieDetailScreenState createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Future<String?>? _trailerIdFuture;
  Future<Map<String, dynamic>?>? _detailedMovieDataFuture;

  late Color _cardBgColor;
  late Color _textColor;
  late Color _secondaryTextColor;
  late Color _accentColor;
  late Color _errorColor;

  @override
  void initState() {
    super.initState();

    _trailerIdFuture = fetchTrailer(widget.movie.id, widget.apiKey);
    _detailedMovieDataFuture = _fetchMovieDetails(
      widget.movie.id,
      widget.apiKey,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final theme = Theme.of(context);
    _cardBgColor = theme.cardColor;
    _textColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    _secondaryTextColor =
        theme.textTheme.titleSmall?.color ?? Colors.grey[400]!;
    _accentColor = theme.primaryColor;
    _errorColor = theme.colorScheme.error;
  }

  Future<Map<String, dynamic>?> _fetchMovieDetails(
    int movieId,
    String apiKey,
  ) async {
    final uri = Uri.https('api.themoviedb.org', '/3/movie/$movieId', {
      'api_key': apiKey,
      'language': 'en-US',
      'append_to_response': 'credits',
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json;
      } else {
        print(
          'Failed to fetch movie $movieId details (status ${response.statusCode})',
        );
        return null;
      }
    } catch (e) {
      print('Error fetching movie $movieId details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double imageHeight = screenWidth * 0.8;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: screenWidth,
                  height: imageHeight,
                  child: widget.movie.posterPath.isEmpty
                      ? Container(
                          color: _cardBgColor,
                          child: Icon(
                            Icons.movie_filter_outlined,
                            size: 80,
                            color: _secondaryTextColor.withOpacity(0.5),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w500${widget.movie.posterPath}',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: _cardBgColor,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _accentColor,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: _cardBgColor,
                            child: Icon(
                              Icons.broken_image,
                              size: 80,
                              color: _errorColor,
                            ),
                          ),
                        ),
                ),

                Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,

                        Theme.of(
                          context,
                        ).scaffoldBackgroundColor.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),

            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: screenWidth,

                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _detailedMovieDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: _accentColor),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      print(
                        "Detailed movie data fetch error: ${snapshot.error}",
                      );

                      return _buildBasicDetails();
                    }

                    final detailedData = snapshot.data!;

                    final genres =
                        (detailedData['genres'] as List?)
                            ?.map((g) => g['name'] as String)
                            .where((name) => name.isNotEmpty)
                            .toList() ??
                        [];
                    final crew = detailedData['credits']?['crew'] as List?;
                    final director =
                        crew?.firstWhere(
                              (c) => c['job'] == 'Director',
                              orElse: () => null,
                            )?['name']
                            as String?;
                    final runtime = detailedData['runtime'] as int?;
                    final cast =
                        detailedData['credits']?['cast'] as List? ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.movie.title,
                          style: Theme.of(context).textTheme.headlineMedium!
                              .copyWith(
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                                fontSize: 24,
                              ),
                        ),
                        const SizedBox(height: 16),

                        _buildRatingDateRuntimeSimilarityRow(runtime),

                        const SizedBox(height: 16),

                        if (genres.isNotEmpty) _buildGenresSection(genres),

                        if (genres.isNotEmpty) const SizedBox(height: 16),

                        if (director != null && director.isNotEmpty)
                          _buildDirectorSection(director),

                        if (director != null && director.isNotEmpty)
                          const SizedBox(height: 16),

                        _buildTrailerButtonSection(),

                        const SizedBox(height: 24),

                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.movie.overview.isNotEmpty &&
                                  widget.movie.overview !=
                                      'No overview available.'
                              ? widget.movie.overview
                              : 'No overview available for this movie.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: 24),

                        _buildCastSection(cast),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.movie.title,
          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: _textColor,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 16),

        _buildRatingDateRuntimeSimilarityRow(null),
        const SizedBox(height: 16),

        _buildTrailerButtonSection(),
        const SizedBox(height: 24),

        Text(
          'Overview',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.movie.overview.isNotEmpty &&
                  widget.movie.overview != 'No overview available.'
              ? widget.movie.overview
              : 'No overview available for this movie.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRatingDateRuntimeSimilarityRow(int? runtime) {
    String year =
        widget.movie.releaseDate.isNotEmpty &&
            widget.movie.releaseDate != 'Unknown Date'
        ? widget.movie.releaseDate.split('-').first
        : 'N/A';

    String runtimeText = runtime != null ? '$runtime min' : 'N/A';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 20),
        const SizedBox(width: 4),
        Text(
          '${widget.movie.rating.toStringAsFixed(1)}/10',
          style: Theme.of(
            context,
          ).textTheme.titleMedium!.copyWith(color: _textColor),
        ),
        const SizedBox(width: 16),

        Icon(
          Icons.calendar_today_rounded,
          color: _secondaryTextColor.withOpacity(0.8),
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          year,
          style: Theme.of(
            context,
          ).textTheme.titleSmall!.copyWith(color: _secondaryTextColor),
        ),
        const SizedBox(width: 16),

        if (runtime != null) ...[
          Icon(
            Icons.timer_rounded,
            color: _secondaryTextColor.withOpacity(0.8),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            runtimeText,
            style: Theme.of(
              context,
            ).textTheme.titleSmall!.copyWith(color: _secondaryTextColor),
          ),
          const SizedBox(width: 16),
        ],

        if (widget.similarityScore != null) ...[
          Icon(
            Icons.compare_arrows_rounded,
            color: _accentColor.withOpacity(0.8),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            'Match: ${(widget.similarityScore! * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: _accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenresSection(List<String> genres) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genres',
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: genres
              .map(
                (genre) => Chip(
                  label: Text(
                    genre,
                    style: TextStyle(fontSize: 12, color: _textColor),
                  ),
                  backgroundColor: _cardBgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _secondaryTextColor.withOpacity(0.3),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDirectorSection(String directorName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Director',
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.camera_alt_rounded,
              color: _secondaryTextColor.withOpacity(0.8),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              directorName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: _secondaryTextColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailerButtonSection() {
    return FutureBuilder<String?>(
      future: _trailerIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _accentColor));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final trailerId = snapshot.data!;
          return Center(
            child: ElevatedButton.icon(
              onPressed: () {
                playTrailer(context, trailerId);
              },
              icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
              label: const Text('Watch Trailer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        }

        return Center(
          child: Text(
            'Trailer not available',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontStyle: FontStyle.italic,
              color: _secondaryTextColor.withOpacity(0.7),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCastSection(List<dynamic> cast) {
    if (cast.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cast',
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length > 10 ? 10 : cast.length,
            itemBuilder: (context, index) {
              final actor = cast[index];
              final profilePath = actor['profile_path'];
              final actorName = actor['name'] ?? 'Unknown';
              final character = actor['character'] ?? '';

              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: profilePath != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  'https://image.tmdb.org/t/p/w185$profilePath',
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 80,
                                width: 80,
                                color: _cardBgColor,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _accentColor,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 80,
                                width: 80,
                                color: _cardBgColor,
                                child: Icon(
                                  Icons.person,
                                  color: _secondaryTextColor,
                                ),
                              ),
                            )
                          : Container(
                              height: 80,
                              width: 80,
                              color: _cardBgColor,
                              child: Icon(
                                Icons.person,
                                color: _secondaryTextColor,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: _textColor),
                    ),
                    Text(
                      character,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: _secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
