// lib/services/algolia_service.dart
import 'package:algoliasearch/algoliasearch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/algolia_config.dart';

class AlgoliaService {
  static SearchClient? _searchClient;
  static SearchClient? _adminClient;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    debugPrint('🔧 ALGOLIA: Initializing...');

    try {
      _searchClient = SearchClient(
        appId: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.searchApiKey,
      );

      _adminClient = SearchClient(
        appId: AlgoliaConfig.applicationId,
        apiKey: AlgoliaConfig.adminApiKey,
      );

      _initialized = true;
      debugPrint('✅ ALGOLIA: Initialized successfully');
    } catch (e) {
      debugPrint('❌ ALGOLIA: Initialization failed: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    debugPrint('🔍 ALGOLIA: Searching for "$query"');

    if (!_initialized) initialize();

    try {
      final request = SearchForHits(
        indexName: AlgoliaConfig.indexName,
        query: query,
        hitsPerPage: 50,
      );

      final response = await _searchClient!.searchIndex(request: request);
      debugPrint('📥 ALGOLIA: Found ${response.hits.length} results');

      return response.hits.map((hit) {
        Map<String, dynamic> data = Map<String, dynamic>.from(hit);
        data['id'] = hit['objectID'];
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ ALGOLIA: Search error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchWithFilters({
    required String query,
    String? category,
    List<String>? tags,
  }) async {
    debugPrint('🔍 ALGOLIA: Filtered search for "$query"');

    if (!_initialized) initialize();

    try {
      List<String> filters = [];

      if (category != null && category != 'All' && category.isNotEmpty) {
        filters.add('category:"$category"');
      }

      if (tags != null && tags.isNotEmpty) {
        if (tags.contains('Lost')) {
          filters.add('type:"lost"');
        } else if (tags.contains('Found')) {
          filters.add('type:"found"');
        }
      }

      final request = SearchForHits(
        indexName: AlgoliaConfig.indexName,
        query: query,
        hitsPerPage: 50,
        filters: filters.isNotEmpty ? filters.join(' AND ') : null,
      );

      final response = await _searchClient!.searchIndex(request: request);
      debugPrint('📥 ALGOLIA: Filtered results: ${response.hits.length}');

      return response.hits.map((hit) {
        Map<String, dynamic> data = Map<String, dynamic>.from(hit);
        data['id'] = hit['objectID'];
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ ALGOLIA: Filtered search error: $e');
      return [];
    }
  }

  static Future<String> addPost(Map<String, dynamic> postData) async {
    if (!_initialized) initialize();

    try {
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('posts')
          .add(postData);

      DocumentSnapshot docSnapshot = await docRef.get();
      Map<String, dynamic> firestoreData = docSnapshot.data() as Map<String, dynamic>;

      Map<String, dynamic> algoliaData = _cleanDataForAlgolia(firestoreData);
      algoliaData['objectID'] = docRef.id;

      await _adminClient!.saveObject(
        indexName: AlgoliaConfig.indexName,
        body: algoliaData,
      );

      debugPrint('✅ ALGOLIA: Post added successfully');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ ALGOLIA: Add post error: $e');
      throw e;
    }
  }

  static Map<String, dynamic> _cleanDataForAlgolia(Map<String, dynamic> data) {
    Map<String, dynamic> cleanData = {};

    data.forEach((key, value) {
      if (value == null) return;

      if (value is Timestamp) {
        cleanData[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        cleanData[key] = value.toIso8601String();
      } else if (value.toString().contains('FieldValue')) {
        return;
      } else {
        cleanData[key] = value;
      }
    });

    cleanData.remove('createdAt');
    cleanData.remove('updatedAt');
    return cleanData;
  }
}
