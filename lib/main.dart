import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cấu hình cửa sổ đơn giản - chỉ maximize
  await windowManager.ensureInitialized();

  // Chờ cửa sổ sẵn sàng rồi maximize
  windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.maximize();
    await windowManager.show();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biểu Đồ DVL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
