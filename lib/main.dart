import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glurg_app/providers/card_provider.dart';
import 'package:glurg_app/screens/home_screen.dart';

void main() {
  try {
    runApp(const GlurgApp());
  } catch (e, stackTrace) {
    print('ERROR IN MAIN: $e');
    print('STACK TRACE: $stackTrace');
    rethrow;
  }
}

class GlurgApp extends StatelessWidget {
  const GlurgApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CardListProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Glurg - Card Copier',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        builder: (context, child) {
          return ErrorHandlingWidget(child: child!);
        },
      ),
    );
  }
}

class ErrorHandlingWidget extends StatelessWidget {
  final Widget child;
  
  const ErrorHandlingWidget({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
