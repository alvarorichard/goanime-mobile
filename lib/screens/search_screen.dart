import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../services/search_history_service.dart';
import '../main.dart';
import 'episode_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
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
  final List<Map<String, dynamic>> _genres = [
    {'id': JikanGenreIds.action, 'name': 'Ação', 'icon': Icons.flash_on},
    {'id': JikanGenreIds.adventure, 'name': 'Aventura', 'icon': Icons.explore},
    {'id': JikanGenreIds.comedy, 'name': 'Comédia', 'icon': Icons.emoji_emotions},
    {'id': JikanGenreIds.drama, 'name': 'Drama', 'icon': Icons.theater_comedy},
    {'id': JikanGenreIds.fantasy, 'name': 'Fantasia', 'icon': Icons.auto_awesome},
    {'id': JikanGenreIds.horror, 'name': 'Horror', 'icon': Icons.dark_mode},
    {'id': JikanGenreIds.mystery, 'name': 'Mistério', 'icon': Icons.search},
    {'id': JikanGenreIds.romance, 'name': 'Romance', 'icon': Icons.favorite},
    {'id': JikanGenreIds.sciFi, 'name': 'Sci-Fi', 'icon': Icons.rocket_launch},
    {'id': JikanGenreIds.sliceOfLife, 'name': 'Slice of Life', 'icon': Icons.wb_sunny},
    {'id': JikanGenreIds.sports, 'name': 'Esportes', 'icon': Icons.sports_soccer},
    {'id': JikanGenreIds.supernatural, 'name': 'Supernatural', 'icon': Icons.auto_fix_high},
  ];

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
    
    // Mostra loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Buscando ${anime.title}...',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Busca o anime no AllAnime/AnimeFire
      final results = await AnimeService.searchAnime(anime.title);
      
      if (!mounted) return;
      Navigator.pop(context); // Remove loading

      if (results.isEmpty) {
        _showErrorDialog('Anime não encontrado', 
          'Não foi possível encontrar "${anime.title}" no AllAnime ou AnimeFire.');
        return;
      }

      // Se encontrou apenas um, vai direto para episódios
      if (results.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: results.first),
          ),
        );
      } else {
        // Se encontrou vários, mostra diálogo para escolher
        _showAnimeSelectionDialog(anime.title, results);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Remove loading
      _showErrorDialog('Erro', 'Erro ao buscar anime: $e');
    }
  }

  void _showAnimeSelectionDialog(String searchTerm, List<Anime> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Selecione a versão',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final anime = results[index];
              return ListTile(
                leading: Icon(
                  anime.source == AnimeSource.allAnime 
                    ? Icons.star 
                    : Icons.local_fire_department,
                  color: Colors.orange,
                ),
                title: Text(
                  anime.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  anime.sourceName,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModernEpisodeListScreen(anime: anime),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            _buildSearchHeader(),
            
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

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F0F1E),
            const Color(0xFF1A1A2E).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
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
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Buscar animes...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          prefixIcon: const Icon(Icons.search, color: Colors.orange),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white70),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      backgroundColor: Colors.orange.withValues(alpha: 0.2),
                      side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
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
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _genres.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Todos'),
                labelStyle: TextStyle(
                  color: _selectedGenre == null ? Colors.white : Colors.white70,
                  fontWeight: _selectedGenre == null ? FontWeight.bold : FontWeight.normal,
                ),
                selected: _selectedGenre == null,
                selectedColor: Colors.orange,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                onSelected: (_) => _selectGenre(null),
              ),
            );
          }
          
          final genre = _genres[index - 1];
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
              selectedColor: Colors.orange,
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
        // Buscas Recentes (com resultados)
        if (_recentSearchResults.isNotEmpty) ...[
          _buildSectionHeader('Buscas Recentes', Icons.history),
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
        
        // Histórico de Pesquisas
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Histórico', Icons.schedule),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Limpar',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._searchHistory.take(8).map((query) {
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: Text(
                query,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => _removeHistoryItem(query),
              ),
              onTap: () => _selectSearchQuery(query),
            );
          }),
          const SizedBox(height: 32),
        ],
        
        // Em Alta
        _buildSectionHeader('Em Alta Agora', Icons.local_fire_department),
        const SizedBox(height: 16),
        if (_isLoadingTrending)
          const Center(
            child: CircularProgressIndicator(color: Colors.orange),
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
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Nenhum resultado encontrado',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
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
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
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
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 12),
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
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    ),
                  ),
                  if (anime.score != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 10),
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
