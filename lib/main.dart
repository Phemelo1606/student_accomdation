import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:student_accomdation/firebase_options.dart';
import 'package:student_accomdation/core/routes.dart';
//PLEASE RUN FLUTTER PUB GET BEFORE RUNNING THE APP

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Student Accommodation',
      theme: ThemeData(primarySwatch: Colors.indigo),

      onGenerateRoute: RouteManager.generateRoute,
      initialRoute: RouteManager.loginPage,

      // 👇 If you want to start at RegisterScreen instead:
      // home: RegisterScreen(),
    );
  }
}
