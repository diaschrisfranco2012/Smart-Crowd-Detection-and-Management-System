import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase
      .instance
      .ref();

  // Sign In
  Future<UserCredential> signIn(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Register (Saves Name to Database)
  Future<UserCredential> signUp(
    String name,
    String email,
    String password,
  ) async {
    UserCredential cred = await _auth
        .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

    // Save the user's name so we can greet them on the dashboard
    await _db
        .child("users")
        .child(cred.user!.uid)
        .set({
          'name': name,
          'email': email,
          'role': 'guard',
        });

    return cred;
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
