import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔹 Sign Up
  Future<Map<String, dynamic>?> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        String? token = await user.getIdToken(); // nullable token

        Map<String, dynamic> userData = {
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? 'User',
          'isAnonymous': user.isAnonymous,
          'token': token, // may be null
        };

        return userData;
      }
    } catch (e) {
      print("❌ Sign Up Error: $e");
    }
    return null;
  }

  // 🔹 Log In
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        String? token = await user.getIdToken(); // nullable token

        return {
          "uid": user.uid,
          "email": user.email ?? '',
          "name": user.displayName ?? "User",
          "isAnonymous": user.isAnonymous,
          "token": token, // may be null
        };
      }
    } catch (e) {
      print("❌ Login Error: $e");
    }
    return null;
  }
}
