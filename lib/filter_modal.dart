// lib/filter_modal.dart
import 'package:flutter/material.dart';
import 'services/algolia_manual_service.dart';
import 'dart:math' as Math;

class FilterModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onFilter;
  final Map<String, dynamic>? initialFilters;

  const FilterModal({
    Key? key,
    required this.onClose,
    required this.onFilter,
    this.initialFilters,
  }) : super(key: key);

  @override
  State<FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  String _selectedCategory = 'All';
  List<String> _selectedTags = [];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // 🗂️ DYNAMIC CATEGORIES: Will be fetched from Algolia
  List<String> _categories = ['All']; // Default fallback
  bool _isLoadingCategories = true;

  // 🎯 UPDATED: Only Lost and Found tags
  final List<String> _tags = ['Lost', 'Found'];

  @override
  void initState() {
    super.initState();

    // Initialize controller with initial filter if provided
    _titleController = TextEditingController(
      text: widget.initialFilters?['title'] ?? '',
    );

    // Set initial values from initialFilters if provided
    if (widget.initialFilters != null) {
      _selectedCategory = widget.initialFilters!['category'] ?? 'All';
      _selectedTags = List<String>.from(widget.initialFilters!['tags'] ?? []);
    }

    // 🎯 DYNAMIC FILTERING: Add listener to title controller for instant filtering
    _titleController.addListener(() {
      _applyFilters();
    });

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Start animation
    _animationController.forward();

    // 🗂️ FETCH CATEGORIES FROM ALGOLIA
    _fetchCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 🗂️ FETCH CATEGORIES DYNAMICALLY FROM ALGOLIA
  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      print('🗂️ FILTER MODAL: Fetching categories from Algolia...');
      final categories = await AlgoliaManualService.fetchCategoriesFromIndex();

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });

      print('🗂️ FILTER MODAL: Successfully loaded ${categories.length} categories');
    } catch (e) {
      print('❌ FILTER MODAL: Failed to fetch categories: $e');
      setState(() {
        _categories = [
          'All',
          'Electronics',
          'Wallet/Bag',
          'Keys',
          'Documents',
          'Clothing',
          'Other'
        ];
        _isLoadingCategories = false;
      });
    }
  }

  // 🎯 DYNAMIC FILTERING: Apply filters immediately
  void _applyFilters() {
    final filters = {
      'title': _titleController.text.trim(),
      'category': _selectedCategory,
      'tags': _selectedTags,
    };

    print('🔍 FILTER MODAL: Applying filters dynamically: $filters');
    widget.onFilter(filters);
  }

  void _handleTagChange(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });

    // 🎯 DYNAMIC FILTERING: Apply filters immediately when tag changes
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _titleController.clear();
      _selectedCategory = 'All';
      _selectedTags.clear();
    });

    // 🎯 DYNAMIC FILTERING: Apply cleared filters immediately
    _applyFilters();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'wallet/bag':
        return Icons.account_balance_wallet;
      case 'keys':
        return Icons.vpn_key;
      case 'documents':
        return Icons.description;
      case 'clothing':
        return Icons.checkroom;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.3),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: _buildModalContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(
        maxWidth: 380,
        maxHeight: 600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔧 KEY FIX: Prevent unbounded height
        children: [
          _buildHeader(),
          // 🔧 KEY FIX: Use Flexible instead of Expanded for scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // 🔧 KEY FIX: Minimize height
                children: [
                  _buildTitleInput(),
                  const SizedBox(height: 20),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 20),
                  _buildTagsSection(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF667eea),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Filter Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⚡', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text(
                  'Live Filter',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Title',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                'Live search',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Search by title...',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[500],
                size: 20,
              ),
              suffixIcon: _titleController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[500], size: 18),
                onPressed: () {
                  setState(() {
                    _titleController.clear();
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  // 🔧 FIXED: Category dropdown with proper constraints
  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingCategories) ...[
                    SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    const Text('⚡', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 2),
                    Text(
                      'From Algolia',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _categories.contains(_selectedCategory) ? _selectedCategory : 'All',
            onChanged: _isLoadingCategories ? null : (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCategory = newValue;
                });

                print('🔍 FILTER MODAL: Category changed to: $newValue');
                _applyFilters();
              }
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _categories.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child:
                // 🔧 FIXED: Constrain the Row inside dropdown items
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // 🔧 KEY FIX: Minimize width
                    children: [
                      Icon(
                        value == 'All' ? Icons.all_inclusive : _getCategoryIcon(value),
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      // 🔧 FIXED: Use Flexible instead of Expanded
                      Flexible(
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Text(
                'Instant filter',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: _tags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => _handleTagChange(tag),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (tag == 'Lost' ? Colors.red[600] : Colors.green[600])
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (tag == 'Lost' ? Colors.red[600]! : Colors.green[600]!)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _clearFilters,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Clear All',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
