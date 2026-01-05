import 'package:cloud_firestore/cloud_firestore.dart';

class PostService {
  static Future<List<Map<String, dynamic>>> fetchPostsForMap() async {
    try {
      print('🗺️ Fetching posts from Firestore for map...');

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('showOnMap', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> posts = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Validate that post has location coordinates
        if (data['location'] != null &&
            data['location']['coordinates'] != null &&
            data['location']['coordinates']['latitude'] != null &&
            data['location']['coordinates']['longitude'] != null) {
          posts.add(data);
          print('✅ Added post to map: ${data['title']}');
        } else {
          print('❌ Skipped post without coordinates: ${data['title']}');
        }
      }

      print('🗺️ Loaded ${posts.length} posts for map display');
      return posts;
    } catch (e) {
      print('❌ Error fetching posts for map: $e');
      return [];
    }
  }

  // Fetch posts created by a specific user
  static Future<List<Map<String, dynamic>>> fetchUserPosts(String userId) async {
    try {
      print('👤 Fetching posts for user: $userId');

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> posts = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        posts.add(data);
        print('✅ Added user post: ${data['title']}');
      }

      print('👤 Loaded ${posts.length} posts for user: $userId');
      return posts;
    } catch (e) {
      print('❌ Error fetching user posts: $e');
      return [];
    }
  }
}