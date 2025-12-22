// lib/services/algolia_manual_service.dart
import 'package:algoliasearch/algoliasearch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/algolia_config.dart';
import 'dart:math' as Math;

class AlgoliaManualService {
  static late SearchClient _adminClient;
  static late SearchClient _searchClient;
  static bool _initialized = false;

  static void initialize() {
    print('🔧 ALGOLIA SERVICE: ====== INITIALIZING ALGOLIA ======');
    print('   📋 App ID: ${AlgoliaConfig.applicationId}');
    print('   📋 Index Name: ${AlgoliaConfig.indexName}');
    print('   📋 Timestamp: ${DateTime.now().toString()}');

    try {
      _adminClient = SearchClient(
        appId: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.adminApiKey,
      );

      _searchClient = SearchClient(
        appId: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.searchApiKey,
      );

      _initialized = true;
      print('✅ ALGOLIA SERVICE: Successfully initialized Algolia clients');
      print('   🔹 Admin client ready');
      print('   🔹 Search client ready');
    } catch (e) {
      print('❌ ALGOLIA SERVICE: Initialization failed - $e');
    }
    print('🔧 ALGOLIA SERVICE: ====== INITIALIZATION COMPLETE ======\n');
  }

  // 🗂️ NEW: Fetch dynamic categories from Algolia index
  static Future<List<String>> fetchCategoriesFromIndex() async {
    print('\n🗂️ ALGOLIA SERVICE: ====== FETCHING CATEGORIES ======');
    print('   🕒 Request Time: ${DateTime.now().toString()}');

    if (!_initialized) {
      print('⚠️  ALGOLIA SERVICE: Service not initialized, initializing now...');
      initialize();
    }

    try {
      print('🚀 ALGOLIA SERVICE: Requesting categories via search with facets...');
      final stopwatch = Stopwatch()..start();

      // Use search with facets to get category values
      SearchForHits request = SearchForHits(
        indexName: AlgoliaConfig.indexName,
        query: '', // Empty query to get all items
        hitsPerPage: 0, // We don't need hits, just facets
        facets: ['category'], // Request facets for category
      );

      SearchResponse response = await _searchClient.searchIndex(request: request);

      stopwatch.stop();

      print('📥 ALGOLIA SERVICE: ====== CATEGORIES FETCHED ======');
      print('   ⚡ Response Time: ${stopwatch.elapsedMilliseconds}ms');

      List<String> categories = ['All']; // Add 'All' as first option

      // Extract categories from facets
      if (response.facets != null && response.facets!.containsKey('category')) {
        final categoryFacets = response.facets!['category'] as Map<String, dynamic>;

        print('   📊 Categories Found: ${categoryFacets.length}');

        for (String category in categoryFacets.keys) {
          if (category.isNotEmpty && category != 'All') {
            categories.add(category);
            print('   🏷️  Found category: $category (${categoryFacets[category]} items)');
          }
        }
      } else {
        print('   ⚠️  No category facets found in response');
      }

      print('✅ ALGOLIA SERVICE: Successfully fetched ${categories.length} categories');
      return categories;

    } catch (e, stackTrace) {
      print('❌ ALGOLIA SERVICE: Failed to fetch categories: $e');
      print('❌ ALGOLIA SERVICE: Stack trace: $stackTrace');

      // Return default categories as fallback
      return [
        'All',
        'Electronics',
        'Wallet/Bag',
        'Keys',
        'Documents',
        'Clothing',
        'Other'
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    print('\n🔍 ALGOLIA SEARCH: ====== STARTING SEARCH REQUEST ======');
    print('   📝 Search Query: "${query}"');
    print('   🕒 Request Time: ${DateTime.now().toString()}');
    print('   📊 Service Initialized: $_initialized');

    if (!_initialized) {
      print('⚠️  ALGOLIA SEARCH: Service not initialized, initializing now...');
      initialize();

      if (!_initialized) {
        print('❌ ALGOLIA SEARCH: Failed to initialize service');
        return [];
      }
    }

    try {
      print('📤 ALGOLIA SEARCH: Preparing search request...');
      print('   🎯 Target Index: ${AlgoliaConfig.indexName}');
      print('   🔤 Final Query: "${query.isEmpty ? '*' : query}"');
      print('   📏 Hits Per Page: 50');

      SearchForHits request = SearchForHits(
        indexName: AlgoliaConfig.indexName,
        query: query.isEmpty ? '*' : query,
        hitsPerPage: 50,
      );

      print('🚀 ALGOLIA SEARCH: Sending request to Algolia servers...');
      final stopwatch = Stopwatch()..start();

      SearchResponse response = await _searchClient.searchIndex(request: request);

      stopwatch.stop();
      print('📥 ALGOLIA SEARCH: ====== RESPONSE RECEIVED ======');
      print('   ⚡ Response Time: ${stopwatch.elapsedMilliseconds}ms');
      print('   📊 Total Hits Found: ${response.hits.length}');
      print('   🔍 Query Executed: "${response.query}"');
      print('   ⏱️  Processing Time (Algolia): ${response.processingTimeMS}ms');
      print('   📍 Index Used: ${AlgoliaConfig.indexName}');

      if (response.hits.isNotEmpty) {
        print('📄 ALGOLIA SEARCH: Sample result structure:');
        final firstHit = response.hits.first;
        print('   🔑 Object ID: ${firstHit['objectID']}');
        print('   📝 Title: ${firstHit['title'] ?? 'N/A'}');
        print('   📂 Category: ${firstHit['category'] ?? 'N/A'}');
        print('   🏷️  Type: ${firstHit['type'] ?? 'N/A'}');
        print('   📍 Location: ${firstHit['location'] ?? 'N/A'}');
      } else {
        print('❌ ALGOLIA SEARCH: No results found - running diagnostics...');
        await _runSearchDiagnostics(query);
      }

      List<Map<String, dynamic>> results = _formatResults(response);
      print('✅ ALGOLIA SEARCH: Successfully formatted ${results.length} results');
      print('🔍 ALGOLIA SEARCH: ====== SEARCH COMPLETE ======\n');

      return results;
    } catch (e, stackTrace) {
      print('❌ ALGOLIA SEARCH: ====== SEARCH FAILED ======');
      print('   💥 Error Type: ${e.runtimeType}');
      print('   📝 Error Message: $e');
      print('   🔧 Stack Trace: $stackTrace');
      print('❌ ALGOLIA SEARCH: ====== ERROR END ======\n');
      return [];
    }
  }

  static Future<void> _runSearchDiagnostics(String originalQuery) async {
    print('🔧 ALGOLIA DIAGNOSTICS: Running search diagnostics...');

    try {
      // Test 1: Wildcard search
      print('   🧪 Test 1: Wildcard search (*)...');
      SearchForHits wildcardRequest = SearchForHits(
        indexName: AlgoliaConfig.indexName,
        query: '*',
        hitsPerPage: 5,
      );

      SearchResponse wildcardResponse = await _searchClient.searchIndex(request: wildcardRequest);
      print('      📊 Wildcard results: ${wildcardResponse.hits.length} hits');

      if (wildcardResponse.hits.isNotEmpty) {
        print('      ✅ Index contains data');
        print('      📄 Sample record keys: ${wildcardResponse.hits.first.keys.toList()}');

        // Test 2: Search for common terms
        print('   🧪 Test 2: Searching common terms...');
        for (String term in ['lost', 'found', 'phone', 'key', 'bag']) {
          try {
            SearchForHits termRequest = SearchForHits(
              indexName: AlgoliaConfig.indexName,
              query: term,
              hitsPerPage: 3,
            );

            SearchResponse termResponse = await _searchClient.searchIndex(request: termRequest);
            print('      🔍 "$term": ${termResponse.hits.length} hits');
          } catch (e) {
            print('      ❌ "$term" search failed: $e');
          }
        }
      } else {
        print('      ❌ Index appears to be empty');

        // Test 3: Check write permissions
        print('   🧪 Test 3: Testing write permissions...');
        try {
          await _adminClient.saveObject(
            indexName: AlgoliaConfig.indexName,
            body: {
              'objectID': 'diagnostic-test-${DateTime.now().millisecondsSinceEpoch}',
              'title': 'Diagnostic Test Post',
              'description': 'This is a diagnostic test',
              'type': 'test',
              'category': 'Diagnostic',
              'createdAt': DateTime.now().toIso8601String(),
            },
          );
          print('      ✅ Write permissions OK - diagnostic record created');
        } catch (e) {
          print('      ❌ Write test failed: $e');
        }
      }
    } catch (e) {
      print('   ❌ Diagnostics failed: $e');
    }
  }

  static Future<String> addPost(Map<String, dynamic> postData) async {
    print('\n📝 ALGOLIA ADD: ====== ADDING NEW POST ======');
    print('   🕒 Request Time: ${DateTime.now().toString()}');
    print('   📄 Post Data: $postData');

    if (!_initialized) {
      print('⚠️  ALGOLIA ADD: Initializing service...');
      initialize();
    }

    try {
      // STEP 1: SAVE TO FIRESTORE
      print('📤 ALGOLIA ADD: Step 1 - Saving to Firestore...');
      DocumentReference docRef =
      await FirebaseFirestore.instance.collection('posts').add(postData);

      String docId = docRef.id;
      print('✅ Added to Firestore: $docId');

      // STEP 2: PREPARE ALGOLIA DATA
      print('🔧 ALGOLIA ADD: Preparing Algolia data...');
      Map<String, dynamic> algoliaData = Map.from(postData);
      algoliaData['objectID'] = docId;

      // Remove Firestore-specific fields that can cause issues
      algoliaData.remove('createdAt');
      algoliaData.remove('updatedAt');

      // Convert Firestore timestamp → ISO string and filter out FieldValue objects
      algoliaData.removeWhere((key, value) {
        if (value is FieldValue) {
          print('   🗑️  Removed FieldValue field: $key');
          return true;
        }
        return false;
      });

      algoliaData.forEach((key, value) {
        if (value is Timestamp) {
          algoliaData[key] = value.toDate().toIso8601String();
          print('   🔄 Converted Timestamp Field: $key');
        }
      });

      // Convert nested coordinates if needed and flatten location data
      if (algoliaData['location'] != null && algoliaData['location'] is Map) {
        Map<String, dynamic> locationData = algoliaData['location'];
        
        // Extract address as a string for Algolia
        algoliaData['location'] = locationData['address'] ?? '';
        
        // Extract coordinates for geosearch
        if (locationData['coordinates'] != null && locationData['coordinates'] is Map) {
          algoliaData['lat'] = locationData['coordinates']['latitude'];
          algoliaData['lng'] = locationData['coordinates']['longitude'];
        }
      }

      print('📊 Final Algolia Data:');
      algoliaData.forEach((k, v) => print('   🔹 $k → $v'));

      // STEP 3: SAVE TO ALGOLIA INDEX
      print('🚀 ALGOLIA ADD: Saving to Algolia...');
      await _adminClient.saveObject(
        indexName: AlgoliaConfig.indexName,
        body: algoliaData,
      );

      print('✅ ALGOLIA ADD: Successfully added to Algolia with objectID: $docId');

      return docId;
    } catch (e, stackTrace) {
      print('❌ ALGOLIA ADD FAILED: $e');
      print('📛 STACKTRACE: $stackTrace');
      throw e;
    }
  }


  // 🎯 UPDATED: Enhanced filtering with dynamic search
  static Future<List<Map<String, dynamic>>> searchWithFilters({
    required String query,
    String? category,
    List<String>? tags,
  }) async {
    print('\n🔧 ALGOLIA FILTER SEARCH: ====== STARTING FILTERED SEARCH ======');
    print('   📝 Base Query: "$query"');
    print('   📂 Category Filter: $category');
    print('   🏷️  Tag Filters: $tags');
    print('   🕒 Request Time: ${DateTime.now().toString()}');

    if (!_initialized) {
      print('⚠️  ALGOLIA FILTER SEARCH: Initializing service...');
      initialize();
    }

    try {
      // Build filters
      List<String> filters = [];

      if (category != null && category.isNotEmpty && category != 'All') {
        filters.add('category:"$category"');
        print('   ➕ Added category filter: category:"$category"');
      }

      if (tags != null && tags.isNotEmpty) {
        List<String> typeFilters = [];
        for (String tag in tags) {
          if (tag == 'Lost') {
            typeFilters.add('type:"lost"');
          } else if (tag == 'Found') {
            typeFilters.add('type:"found"');
          }
        }
        if (typeFilters.isNotEmpty) {
          // Use OR for type filters (Lost OR Found)
          filters.add('(${typeFilters.join(' OR ')})');
          print('   ➕ Added type filters: (${typeFilters.join(' OR ')})');
        }
      }

      String filterString = filters.join(' AND ');
      print('   🔍 Final Filter String: "$filterString"');

      SearchForHits request = SearchForHits(
        indexName: AlgoliaConfig.indexName,
        query: query.isEmpty ? '*' : query,
        hitsPerPage: 50,
        filters: filterString.isNotEmpty ? filterString : null,
        facets: ['category'], // Include facets for dynamic categories
      );

      print('🚀 ALGOLIA FILTER SEARCH: Sending filtered request to Algolia...');
      print('   🎯 Target Index: ${AlgoliaConfig.indexName}');
      print('   🔤 Query: "${request.query}"');
      print('   🔧 Filters: ${request.filters ?? "None"}');

      final stopwatch = Stopwatch()..start();

      SearchResponse response = await _searchClient.searchIndex(request: request);

      stopwatch.stop();

      print('📥 ALGOLIA FILTER SEARCH: ====== FILTERED RESPONSE RECEIVED ======');
      print('   ⚡ Response Time: ${stopwatch.elapsedMilliseconds}ms');
      print('   📊 Filtered Results: ${response.hits.length}');
      print('   ⏱️  Processing Time (Algolia): ${response.processingTimeMS}ms');

      // Show sample results for debugging
      if (response.hits.isNotEmpty) {
        print('   📄 Sample filtered results:');
        for (int i = 0; i < Math.min(3, response.hits.length); i++) {
          final hit = response.hits[i];
          print('      ${i + 1}. ${hit['title']} (${hit['type']}) - ${hit['category']}');
        }
      }

      List<Map<String, dynamic>> results = _formatResults(response);
      print('✅ ALGOLIA FILTER SEARCH: Successfully formatted ${results.length} filtered results');
      print('🔧 ALGOLIA FILTER SEARCH: ====== FILTERED SEARCH COMPLETE ======\n');

      return results;
    } catch (e, stackTrace) {
      print('❌ ALGOLIA FILTER SEARCH: ====== FILTERED SEARCH FAILED ======');
      print('   💥 Error Type: ${e.runtimeType}');
      print('   📝 Error Message: $e');
      print('   🔧 Stack Trace: $stackTrace');
      print('❌ ALGOLIA FILTER SEARCH: ====== ERROR END ======\n');
      return [];
    }
  }

  static List<Map<String, dynamic>> _formatResults(SearchResponse response) {
    print('🔄 ALGOLIA FORMAT: Formatting ${response.hits.length} search results...');

    List<Map<String, dynamic>> formattedResults = [];

    for (int i = 0; i < response.hits.length; i++) {
      var hit = response.hits[i];
      Map<String, dynamic> data = Map<String, dynamic>.from(hit);
      data['id'] = hit['objectID'];
      formattedResults.add(data);

      // Log first few results for verification
      if (i < 3) {
        print('   📄 Result ${i + 1}: ID=${data['id']}, Title="${data['title']}"');
      }
    }

    print('✅ ALGOLIA FORMAT: Formatting complete');
    return formattedResults;
  }
}
