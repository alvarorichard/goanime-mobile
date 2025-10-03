# 🌐 Integração Multi-Fonte

## Visão Geral

O GoAnime Mobile agora busca animes em **múltiplas fontes simultaneamente**, proporcionando:

- ✅ **Mais resultados** de busca
- ✅ **Melhor disponibilidade** de conteúdo
- ✅ **Fontes alternativas** quando uma está indisponível
- ✅ **Metadados enriquecidos** do AniList

## 🎯 Fontes Integradas

### 1. AnimeFire (Brasil)
- **URL**: https://animefire.plus
- **Tipo**: Scraping web
- **Idioma**: Português (PT-BR)
- **Características**:
  - Animes dublados e legendados em português
  - Episódios hospedados em múltiplas fontes
  - Grande catálogo brasileiro

### 2. AllAnime (Internacional)
- **URL**: https://allanime.day
- **Tipo**: API GraphQL
- **Idioma**: Inglês/Multi-idioma
- **Características**:
  - API GraphQL oficial
  - Links priorizados por qualidade
  - Suporte a HLS e MP4
  - Catálogo internacional extenso

### 3. AniList (Metadados)
- **URL**: https://anilist.co
- **Tipo**: API GraphQL
- **Função**: Enriquecimento de dados
- **Características**:
  - Capas e banners em alta qualidade
  - Sinopses e descrições
  - Gêneros, ratings, e estatísticas
  - IDs de MyAnimeList

## 🔄 Fluxo de Busca

```
Usuário digita "Naruto"
        ↓
┌───────────────────────┐
│  AnimeService Search  │
└───────────────────────┘
        ↓
┌───────┴───────┐
│   Parallel    │
│    Search     │
└───────┬───────┘
        ↓
┌───────┴────────────────┐
│                        │
▼                        ▼
AnimeFire              AllAnime
  Search                Search
    ↓                      ↓
┌───────┐            ┌─────────┐
│ Anime │            │  Anime  │
│ List  │            │  List   │
└───┬───┘            └────┬────┘
    │                     │
    └──────┬──────────────┘
           ↓
    Combine Results
           ↓
  ┌────────────────┐
  │ Enrich with    │
  │   AniList      │
  │   (Parallel)   │
  └────────┬───────┘
           ↓
    Display Results
```

## 📊 Arquitetura

### Classes Principais

#### `AnimeSource` (Enum)
```dart
enum AnimeSource {
  animeFire,  // AnimeFire.plus
  allAnime,   // AllAnime.day
}
```

#### `Anime` (Model)
```dart
class Anime {
  final String name;
  final String url;
  final AnimeSource source;      // Fonte do anime
  final String? allAnimeId;      // ID para AllAnime
  MediaDetails? aniListData;     // Dados do AniList
  
  String get sourceName;          // "AnimeFire" ou "AllAnime"
  String get imageUrl;            // Capa do AniList
  List<String> get genres;        // Gêneros do AniList
  // ... outros getters
}
```

### Serviços

#### 1. `AllAnimeService`
Localização: `lib/services/allanime_service.dart`

**Métodos principais:**
- `searchAnime(query)` - Busca animes via GraphQL
- `getEpisodesList(animeId)` - Lista episódios disponíveis
- `getEpisodeURL(animeId, episodeNo)` - URL do vídeo

**Características técnicas:**
- Decodificação de URLs encoded (baseado no projeto Curd)
- Priorização de links por domínio
- Suporte a HLS e MP4
- Rate limiting para evitar bloqueios

#### 2. `AniListService`
Localização: `lib/services/anilist_service.dart`

**Métodos principais:**
- `fetchAnimeFromAniList(name)` - Busca por nome
- `fetchAnimeByMalId(id)` - Busca por MyAnimeList ID
- `fetchAnimeById(id)` - Busca por AniList ID

#### 3. `AnimeService` (Main)
Localização: `lib/main.dart`

**Métodos principais:**
- `searchAnime(name)` - Busca em múltiplas fontes
- `getAnimeEpisodes(anime)` - Lista episódios (multi-fonte)
- `enrichAnimeWithAniList(anime)` - Enriquece com metadados

## 🎨 Interface do Usuário

### Badge de Fonte
Cada resultado de busca exibe um badge indicando a fonte:

```dart
┌─────────────────────────────────┐
│  [Capa]  Naruto Shippuden       │
│          [AnimeFire] 🟠         │  ← Badge laranja
│          Action, Adventure      │
│          ⭐ 8.2 • 📺 500 eps   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  [Capa]  One Piece              │
│          [AllAnime] 🟣          │  ← Badge roxo
│          Action, Adventure      │
│          ⭐ 8.7 • 📺 1000+ eps │
└─────────────────────────────────┘
```

**Cores dos badges:**
- 🟠 **Laranja** = AnimeFire
- 🟣 **Roxo** = AllAnime

### Tela de Episódios

O comportamento muda conforme a fonte:

**AnimeFire:**
- Exibe número e link completo do episódio
- Navegação direta para player

**AllAnime:**
- Exibe "Episódio X" formatado
- Busca link do vídeo antes de reproduzir

## 🔧 Implementação Técnica

### Busca Simultânea
```dart
static Future<List<Anime>> searchAnime(String animeName) async {
  // Buscar simultaneamente em ambas as fontes
  final results = await Future.wait([
    _searchAnimeFire(animeName),
    _searchAllAnime(animeName),
  ]);
  
  // Combinar resultados
  final List<Anime> allAnimes = [];
  allAnimes.addAll(results[0]); // AnimeFire
  allAnimes.addAll(results[1]); // AllAnime
  
  // Enriquecer com AniList
  await Future.wait(
    allAnimes.map((anime) => enrichAnimeWithAniList(anime)),
  );
  
  return allAnimes;
}
```

### Priorização de Links (AllAnime)

Baseado no projeto **Curd**, os links são priorizados por domínio:

```dart
var LinkPriorities = [
  "sharepoint.com",      // Prioridade 1
  "wixmp.com",          // Prioridade 2
  "dropbox.com",        // Prioridade 3
  "wetransfer.com",     // Prioridade 4
  "gogoanime.com",      // Prioridade 5
];
```

### Decodificação de URLs

AllAnime usa URLs encoded que precisam ser decodificadas:

```dart
static String _decodeSourceURL(String encoded) {
  const replacements = {
    '01': '9', '08': '0', '05': '=', '0a': '2',
    // ... mapeamento completo
  };
  
  // Decodifica pares de caracteres
  // Adiciona domínio base se necessário
  // Retorna URL completa
}
```

## 📈 Benefícios

### Para o Usuário
- 📺 **Mais opções** de animes disponíveis
- 🌍 **Conteúdo internacional** e brasileiro
- 🎯 **Melhor disponibilidade** (fallback automático)
- 🖼️ **Visual aprimorado** com capas do AniList

### Para o Desenvolvedor
- 🔌 **Arquitetura modular** fácil de estender
- 🧪 **Testável** (cada fonte isolada)
- 📊 **Logging detalhado** para debugging
- 🚀 **Performance** com buscas paralelas

## 🐛 Tratamento de Erros

O sistema é resiliente a falhas:

```dart
// Se AnimeFire falhar, AllAnime continua
// Se AllAnime falhar, AnimeFire continua
// Se ambos falharem, erro é mostrado ao usuário

try {
  final results = await Future.wait([
    _searchAnimeFire(animeName),    // Pode retornar []
    _searchAllAnime(animeName),     // Pode retornar []
  ]);
  
  // Sempre retorna lista (pode estar vazia)
  return results[0] + results[1];
} catch (e) {
  // Erro catastrófico
  throw Exception('Error searching anime: $e');
}
```

## 🔮 Futuras Melhorias

### Planejadas
- [ ] Cache de resultados de busca
- [ ] Preferência de fonte pelo usuário
- [ ] Indicador de qualidade de vídeo
- [ ] Download de episódios
- [ ] Histórico de visualização multi-fonte
- [ ] Sincronização com AniList (watch progress)

### Fontes Adicionais Possíveis
- [ ] Crunchyroll (API oficial)
- [ ] Funimation
- [ ] AnimixPlay
- [ ] Zoro.to
- [ ] HiAnime

## 📚 Referências

### Projetos Base
- **Curd**: https://github.com/ahkharsha/Curd
  - Implementação AllAnime em Go
  - Sistema de priorização de links
  - Decodificação de URLs

### APIs Utilizadas
- **AniList GraphQL**: https://anilist.gitbook.io/anilist-apiv2-docs/
- **AllAnime GraphQL**: https://api.allanime.day/api

### Dependências
- `http` - Requisições HTTP
- `cached_network_image` - Cache de imagens
- `html` - Parse de HTML (AnimeFire)

## 👥 Contribuindo

Para adicionar uma nova fonte:

1. Criar serviço em `lib/services/[nome]_service.dart`
2. Adicionar enum em `AnimeSource`
3. Implementar métodos de busca e episódios
4. Atualizar `AnimeService.searchAnime()` e `getAnimeEpisodes()`
5. Adicionar cor do badge na UI

## 📄 Licença

Este projeto segue a mesma licença do GoAnime Mobile principal.
