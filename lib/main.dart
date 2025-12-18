import 'package:flutter/material.dart';
import 'package:movetrap/screen/authentication/login_screen/login.dart';
//import 'package:movetrap/screen/authentication/login_screen/loginscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    //MediaQuery.of(context).size.width;
    return MaterialApp(
        title: 'Flutter Practice',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          //brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            fontFamily: 'poppins-Bold.ttf',
           ),
        home: const Login());
  }
}
