import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth/Login.dart'; // Your existing login page
import 'services/local_database.dart'; // Import our local database service

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local database
  final localDb = LocalDatabaseService();
  await localDb.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Loan Scope',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login', // Directly navigate to the LoginPage
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => LoginPage(initialRegister: true),
      },
    );
  }
}
