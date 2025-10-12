import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/search_history_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'source_selection_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const SearchScreen({super.key, this.onBackPressed});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final JikanService _jikanService = JikanService();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _animationController;
  Timer? _debounce;

  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  List<JikanAnime> _trendingAnimes = [];
  List<JikanAnime> _searchResults = [];
  List<JikanAnime> _recentSearchResults = [];

  bool _isLoadingTrending = true;
  bool _isSearching = false;
  bool _showHistory = true;

  // Filtros
  int? _selectedGenre;

  List<Map<String, dynamic>> _getGenres() {
    final l10n = AppLocalizations.of(context);
    return [
      {'id': JikanGenreIds.action, 'name': l10n.action, 'icon': Icons.flash_on},
      {
        'id': JikanGenreIds.adventure,
        'name': l10n.adventure,
        'icon': Icons.explore,
      },
      {
        'id': JikanGenreIds.comedy,
        'name': l10n.comedy,
        'icon': Icons.emoji_emotions,
      },
      {
        'id': JikanGenreIds.drama,
        'name': l10n.drama,
        'icon': Icons.theater_comedy,
      },
      {
        'id': JikanGenreIds.fantasy,
        'name': l10n.fantasy,
        'icon': Icons.auto_awesome,
      },
      {
        'id': JikanGenreIds.horror,
        'name': l10n.horror,
        'icon': Icons.dark_mode,
      },
      {'id': JikanGenreIds.mystery, 'name': l10n.mystery, 'icon': Icons.search},
      {
        'id': JikanGenreIds.romance,
        'name': l10n.romance,
        'icon': Icons.favorite,
      },
      {
        'id': JikanGenreIds.sciFi,
        'name': l10n.sciFi,
        'icon': Icons.rocket_launch,
      },
      {
        'id': JikanGenreIds.sliceOfLife,
        'name': l10n.sliceOfLife,
        'icon': Icons.wb_sunny,
      },
      {
        'id': JikanGenreIds.sports,
        'name': l10n.sports,
        'icon': Icons.sports_soccer,
      },
      {
        'id': JikanGenreIds.supernatural,
        'name': l10n.supernatural,
        'icon': Icons.auto_fix_high,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    _loadSearchHistory();
    _loadTrendingAnimes();
    _loadRecentSearches();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _showHistory = true;
        _suggestions = [];
        _searchResults = [];
      });
      return;
    }

    setState(() => _showHistory = false);

    // Busca sugestões no histórico
    _loadSuggestions(query);

    // Debounce para busca na API
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getSearchHistory();
    setState(() => _searchHistory = history);
  }

  Future<void> _loadSuggestions(String query) async {
    final suggestions = await SearchHistoryService.getSuggestions(query);
    setState(() => _suggestions = suggestions);
  }

  Future<void> _loadTrendingAnimes() async {
    setState(() => _isLoadingTrending = true);
    try {
      final animes = await _jikanService.getCurrentSeasonAnimes(limit: 12);
      if (mounted) {
        setState(() {
          _trendingAnimes = animes;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trending animes: $e');
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  Future<void> _loadRecentSearches() async {
    final history = await SearchHistoryService.getSearchHistory();
    if (history.isEmpty) return;

    // Busca os últimos 3 animes do histórico
    final recentSearches = history.take(3).toList();
    final List<JikanAnime> results = [];

    for (final query in recentSearches) {
      try {
        await Future.delayed(const Duration(milliseconds: 400)); // Rate limit
        final searchResults = await _jikanService.searchAnimes(query, limit: 1);
        if (searchResults.isNotEmpty) {
          results.add(searchResults.first);
        }
      } catch (e) {
        debugPrint('Error loading recent search: $e');
      }
    }

    if (mounted) {
      setState(() => _recentSearchResults = results);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<JikanAnime> results;

      if (_selectedGenre != null) {
        // Busca por gênero com termo
        results = await _jikanService.searchAnimes(query, limit: 20);
        results = results.where((anime) {
          return anime.genres.any((genre) => genre.malId == _selectedGenre);
        }).toList();
      } else {
        // Busca normal
        results = await _jikanService.searchAnimes(query, limit: 20);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching animes: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSearchQuery(String query) async {
    _searchController.text = query;
    _searchFocusNode.unfocus();

    // Salva no histórico
    await SearchHistoryService.saveSearch(query);
    await _loadSearchHistory();

    // Realiza a busca
    _performSearch(query);
  }

  Future<void> _removeHistoryItem(String query) async {
    await SearchHistoryService.removeSearchItem(query);
    await _loadSearchHistory();
  }

  Future<void> _clearHistory() async {
    await SearchHistoryService.clearHistory();
    await _loadSearchHistory();
    setState(() => _recentSearchResults = []);
  }

  void _selectGenre(int? genreId) {
    setState(() {
      _selectedGenre = genreId;
    });

    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  Future<void> _onAnimeTap(JikanAnime anime) async {
    // Salva no histórico
    await SearchHistoryService.saveSearch(anime.title);

    // Navega para tela de seleção de fonte
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(canPop),

            // Genre Filters
            if (!_showHistory) _buildGenreFilters(),

            // Content
            Expanded(
              child: _showHistory
                  ? _buildHistoryAndTrending()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool canPop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, AppColors.backgroundLight],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (canPop) {
                    Navigator.pop(context);
                  } else if (widget.onBackPressed != null) {
                    widget.onBackPressed!();
                  }
                },
              ),
              const SizedBox(width: 8),

              // Search field
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search animes...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.primary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _showHistory = true;
                                      _searchResults = [];
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Suggestions
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(suggestion),
                      labelStyle: const TextStyle(color: Colors.white),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      onPressed: () => _selectSearchQuery(suggestion),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenreFilters() {
    final l10n = AppLocalizations.of(context);
    final genres = _getGenres();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(l10n.allGenres),
                labelStyle: TextStyle(
                  color: _selectedGenre == null ? Colors.white : Colors.white70,
                  fontWeight: _selectedGenre == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                selected: _selectedGenre == null,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                onSelected: (_) => _selectGenre(null),
              ),
            );
          }

          final genre = genres[index - 1];
          final isSelected = _selectedGenre == genre['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                genre['icon'] as IconData,
                color: isSelected ? Colors.white : Colors.white70,
                size: 18,
              ),
              label: Text(genre['name'] as String),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onSelected: (_) => _selectGenre(genre['id'] as int),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryAndTrending() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recent Searches (with results)
        if (_recentSearchResults.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches', Icons.history),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentSearchResults.length,
              itemBuilder: (context, index) {
                return _buildAnimeCard(_recentSearchResults[index]);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Search History
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('History', Icons.schedule),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._searchHistory.take(8).map((query) {
            return ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: Text(query, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => _removeHistoryItem(query),
              ),
              onTap: () => _selectSearchQuery(query),
            );
          }),
          const SizedBox(height: 32),
        ],

        // Trending
        _buildSectionHeader('Trending Now', Icons.local_fire_department),
        const SizedBox(height: 16),
        if (_isLoadingTrending)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _trendingAnimes.length,
            itemBuilder: (context, index) {
              return _buildGridAnimeCard(_trendingAnimes[index]);
            },
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_searchResults.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFound,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildGridAnimeCard(_searchResults[index]);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeCard(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.imageUrl,
                    width: 130,
                    height: 160,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridAnimeCard(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            anime.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
