// lib/services/algolia_bulk_upload.dart
import 'package:algoliasearch/algoliasearch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/algolia_config.dart';

class AlgoliaBulkUpload {
  static late SearchClient _client;

  static void _initializeClient() {
    _client = SearchClient(
      appId: AlgoliaConfig.applicationId,
      apiKey: AlgoliaConfig.adminApiKey,
    );
  }

  // Upload all existing Firestore posts to Algolia
  static Future<Map<String, dynamic>> uploadAllPostsToAlgolia() async {
    try {
      _initializeClient();

      print('🔄 Starting bulk upload of existing posts...');

      // Get all posts from Firestore
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'success': true,
          'message': 'No posts found in Firestore collection',
          'uploaded': 0,
          'errors': 0,
          'total': 0,
        };
      }

      int successCount = 0;
      int errorCount = 0;
      List<String> errorMessages = [];

      print('📊 Found ${snapshot.docs.length} posts to upload');

      // Upload each post to Algolia
      for (int i = 0; i < snapshot.docs.length; i++) {
        var doc = snapshot.docs[i];
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          // Add objectID (required by Algolia)
          data['objectID'] = doc.id;

          // Remove Firestore-specific fields that can cause issues
          data.remove('createdAt');
          data.remove('updatedAt');

          // Convert any Timestamp fields to strings
          data.forEach((key, value) {
            if (value is Timestamp) {
              data[key] = value.toDate().toIso8601String();
            }
          });

          // Upload to Algolia using correct API
          await _client.saveObject(
            indexName: AlgoliaConfig.indexName,
            body: data,
          );

          successCount++;
          print('✅ Uploaded ${i + 1}/${snapshot.docs.length}: ${data['title']}');

        } catch (e) {
          errorCount++;
          String errorMsg = 'Failed to upload ${doc.id}: $e';
          errorMessages.add(errorMsg);
          print('❌ $errorMsg');
        }
      }

      _client.dispose();

      return {
        'success': true,
        'uploaded': successCount,
        'errors': errorCount,
        'total': snapshot.docs.length,
        'errorMessages': errorMessages,
      };

    } catch (e) {
      print('💥 Bulk upload failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'uploaded': 0,
        'errors': 0,
        'total': 0,
      };
    }
  }

  // Upload with progress callback
  static Future<Map<String, dynamic>> uploadWithProgress({
    required Function(int current, int total, String status) onProgress,
  }) async {
    try {
      _initializeClient();

      onProgress(0, 0, 'Fetching posts from Firestore...');

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();

      if (snapshot.docs.isEmpty) {
        onProgress(0, 0, 'No posts found to upload');
        return {
          'success': true,
          'message': 'No posts found',
          'uploaded': 0,
          'errors': 0,
          'total': 0,
        };
      }

      int total = snapshot.docs.length;
      int current = 0;
      int successCount = 0;
      int errorCount = 0;

      onProgress(0, total, 'Starting upload of $total posts...');

      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['objectID'] = doc.id;

          // Clean up data
          data.remove('createdAt');
          data.remove('updatedAt');

          data.forEach((key, value) {
            if (value is Timestamp) {
              data[key] = value.toDate().toIso8601String();
            }
          });

          await _client.saveObject(
            indexName: AlgoliaConfig.indexName,
            body: data,
          );

          successCount++;
          current++;

          onProgress(current, total, 'Uploaded: ${data['title']} ($current/$total)');

        } catch (e) {
          errorCount++;
          current++;
          onProgress(current, total, 'Failed: ${doc.id} ($current/$total)');
        }
      }

      _client.dispose();

      return {
        'success': true,
        'uploaded': successCount,
        'errors': errorCount,
        'total': total,
      };

    } catch (e) {
      onProgress(0, 0, 'Upload failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'uploaded': 0,
        'errors': 0,
        'total': 0,
      };
    }
  }
}
