// lib/search_screen.dart
import 'package:flutter/material.dart';
import 'services/algolia_manual_service.dart';
import 'filter_modal.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback onNavigateBack;
  final Widget bottomNav;
  final Function(Map<String, dynamic>) onPostSelected;

  const SearchScreen({
    Key? key,
    required this.onNavigateBack,
    required this.bottomNav,
    required this.onPostSelected,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  // Filter state
  Map<String, dynamic> _currentFilters = {
    'title': '',
    'category': 'All',
    'tags': <String>[],
  };
  bool _showFilterModal = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Perform initial search to show all posts
    _performInitialSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _performSearch(query: query);
  }

  Future<void> _performInitialSearch() async {
    setState(() {
      _isLoading = true;
      _hasSearched = false;
    });

    try {
      print('🔍 SEARCH SCREEN: Performing initial search...');
      final results = await AlgoliaManualService.searchWithFilters(
        query: '',
        category: null,
        tags: null,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _hasSearched = true;
          _errorMessage = results.isEmpty ? 'No items found' : null;
        });
      }

      print('🔍 SEARCH SCREEN: Initial search completed with ${results.length} results');
    } catch (e) {
      print('❌ SEARCH SCREEN: Initial search failed: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
          _errorMessage = 'Failed to load items. Please try again.';
        });
      }
    }
  }

  Future<void> _performSearch({String query = ''}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 SEARCH SCREEN: Performing search with filters...');
      print('   Query: "$query"');
      print('   Filters: $_currentFilters');

      final results = await AlgoliaManualService.searchWithFilters(
        query: query.isEmpty ? _currentFilters['title'] ?? '' : query,
        category: _currentFilters['category'],
        tags: List<String>.from(_currentFilters['tags'] ?? []),
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _hasSearched = true;
          _errorMessage = results.isEmpty ? 'No items found with current filters' : null;
        });
      }

      print('🔍 SEARCH SCREEN: Search completed with ${results.length} results');
    } catch (e) {
      print('❌ SEARCH SCREEN: Search failed: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
          _errorMessage = 'Search failed. Please try again.';
        });
      }
    }
  }

  // 🎯 FILTER MODAL METHODS
  void _showFilter() {
    print('🔍 SEARCH SCREEN: Opening filter modal...');

    setState(() {
      _showFilterModal = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (BuildContext modalContext) {
        return FilterModal(
          onClose: () {
            print('🔍 SEARCH SCREEN: Closing filter modal');
            Navigator.of(modalContext).pop();
            setState(() {
              _showFilterModal = false;
            });
          },
          onFilter: (filters) {
            print('🔍 SEARCH SCREEN: Applying filters: $filters');
            setState(() {
              _currentFilters = Map<String, dynamic>.from(filters);
              _showFilterModal = false;
            });
            _performSearch();
          },
          initialFilters: _currentFilters,
        );
      },
    ).then((_) {
      setState(() {
        _showFilterModal = false;
      });
    });
  }

  void _clearFilters() {
    setState(() {
      _currentFilters = {
        'title': '',
        'category': 'All',
        'tags': <String>[],
      };
      _searchController.clear();
    });
    _performSearch();
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_currentFilters['category'] != null && _currentFilters['category'] != 'All') count++;
    if (_currentFilters['tags'] != null && (_currentFilters['tags'] as List).isNotEmpty) count++;
    if (_currentFilters['title'] != null && (_currentFilters['title'] as String).isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFiltersRow(),
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomNav,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onNavigateBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Search Items',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search for lost or found items...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.grey),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildFiltersRow() {
    final activeFilterCount = _getActiveFilterCount();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          // Filter Button
          Expanded(
            child: GestureDetector(
              onTap: _showFilter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: activeFilterCount > 0
                      ? Border.all(color: const Color(0xFF667eea), width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune,
                      color: activeFilterCount > 0 ? const Color(0xFF667eea) : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activeFilterCount > 0 ? 'Filters ($activeFilterCount)' : 'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: activeFilterCount > 0 ? const Color(0xFF667eea) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (activeFilterCount > 0) ...[
            const SizedBox(width: 12),
            // Clear Filters Button
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.clear,
                  color: Colors.red[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Results Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _isLoading
                      ? 'Searching...'
                      : _hasSearched
                      ? '${_searchResults.length} results found'
                      : 'Start searching...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                if (_searchResults.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '⚡ Algolia',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF667eea)),
            SizedBox(height: 16),
            Text('Searching Algolia...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performInitialSearch,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final isLost = post['type']?.toString().toLowerCase() == 'lost';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => widget.onPostSelected(post),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLost ? Colors.red[600] : Colors.green[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (post['type']?.toString().toUpperCase() ?? 'UNKNOWN'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      post['category']?.toString() ?? 'Other',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                post['title']?.toString() ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Description
              if (post['description']?.toString().isNotEmpty == true)
                Text(
                  post['description'].toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              // Location and Date
              Row(
                children: [
                  if (post['location']?.toString().isNotEmpty == true) ...[
                    Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post['location'].toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (post['date']?.toString().isNotEmpty == true) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      post['date'].toString(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
