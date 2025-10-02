/// Exemplo de uso da integração AniList API
/// 
/// Este arquivo demonstra como usar os recursos da AniList API
/// no aplicativo GoAnime Mobile.

import 'package:flutter/material.dart';
import '../models/anilist_models.dart';
import '../services/anilist_service.dart';

/// Exemplo 1: Buscar anime por nome
Future<void> searchAnimeExample() async {
  // Buscar anime
  final aniListResponse = await AniListService.fetchAnimeFromAniList('Naruto');
  
  if (aniListResponse != null) {
    final anime = aniListResponse.data.media;
    
    print('ID: ${anime.id}');
    print('Título: ${anime.title.preferred}');
    print('Capa: ${anime.coverImage.best}');
    print('Banner: ${anime.bannerImage}');
    print('Gêneros: ${anime.genres.join(", ")}');
    print('Nota: ${anime.averageScore}');
    print('Episódios: ${anime.episodes}');
    print('Status: ${anime.status}');
  }
}

/// Exemplo 2: Buscar por MAL ID
Future<void> searchByMalIdExample() async {
  final malId = 20; // Naruto
  final aniListResponse = await AniListService.fetchAnimeByMalId(malId);
  
  if (aniListResponse != null) {
    final anime = aniListResponse.data.media;
    print('Encontrado: ${anime.title.preferred}');
  }
}

/// Exemplo 3: Buscar por AniList ID
Future<void> searchByAniListIdExample() async {
  final anilistId = 20; // Naruto
  final aniListResponse = await AniListService.fetchAnimeById(anilistId);
  
  if (aniListResponse != null) {
    final anime = aniListResponse.data.media;
    print('Encontrado: ${anime.title.preferred}');
  }
}

/// Exemplo 4: Widget customizado com dados da AniList
class AnimeInfoCard extends StatelessWidget {
  final MediaDetails anime;

  const AnimeInfoCard({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          if (anime.bannerImage != null)
            Image.network(
              anime.bannerImage!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Capa
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    anime.coverImage.best,
                    width: 100,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Informações
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title.preferred,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Gêneros
                      Wrap(
                        spacing: 8,
                        children: anime.genres.map((genre) {
                          return Chip(
                            label: Text(genre),
                            labelStyle: const TextStyle(fontSize: 12),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Nota e Episódios
                      if (anime.averageScore != null)
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${anime.averageScore! / 10}/10'),
                          ],
                        ),
                      
                      if (anime.episodes != null)
                        Text('${anime.episodes} episódios'),
                      
                      if (anime.status != null)
                        Text('Status: ${anime.status}'),
                      
                      // Descrição
                      if (anime.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          anime.description!.replaceAll(RegExp(r'<[^>]*>'), ''),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exemplo 5: Tela completa de detalhes do anime
class AnimeDetailScreen extends StatefulWidget {
  final String animeName;

  const AnimeDetailScreen({super.key, required this.animeName});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  MediaDetails? _anime;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnime();
  }

  Future<void> _loadAnime() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await AniListService.fetchAnimeFromAniList(widget.animeName);
      
      if (response != null) {
        setState(() {
          _anime = response.data.media;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Anime não encontrado';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              ElevatedButton(
                onPressed: _loadAnime,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_anime == null) {
      return const Scaffold(
        body: Center(child: Text('Nenhum anime encontrado')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar com banner
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_anime!.title.preferred),
              background: _anime!.bannerImage != null
                  ? Image.network(
                      _anime!.bannerImage!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                      ),
                    ),
            ),
          ),
          
          // Conteúdo
          SliverToBoxAdapter(
            child: AnimeInfoCard(anime: _anime!),
          ),
        ],
      ),
    );
  }
}

/// Exemplo 6: Lista de animes populares
class PopularAnimesScreen extends StatefulWidget {
  const PopularAnimesScreen({super.key});

  @override
  State<PopularAnimesScreen> createState() => _PopularAnimesScreenState();
}

class _PopularAnimesScreenState extends State<PopularAnimesScreen> {
  final List<String> _popularAnimes = [
    'One Piece',
    'Naruto',
    'Attack on Titan',
    'Death Note',
    'My Hero Academia',
  ];

  final Map<String, MediaDetails?> _loadedAnimes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnimes();
  }

  Future<void> _loadAnimes() async {
    setState(() => _isLoading = true);

    // Carregar todos em paralelo
    final futures = _popularAnimes.map((name) async {
      final response = await AniListService.fetchAnimeFromAniList(name);
      return MapEntry(name, response?.data.media);
    });

    final results = await Future.wait(futures);
    
    setState(() {
      _loadedAnimes.addEntries(results);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Animes Populares')),
      body: ListView.builder(
        itemCount: _loadedAnimes.length,
        itemBuilder: (context, index) {
          final entry = _loadedAnimes.entries.elementAt(index);
          final anime = entry.value;
          
          if (anime == null) {
            return ListTile(
              title: Text(entry.key),
              subtitle: const Text('Não encontrado'),
            );
          }

          return AnimeInfoCard(anime: anime);
        },
      ),
    );
  }
}
