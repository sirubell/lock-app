import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

Future<Uint8List> loadDataFromAsset(String location) async {
  final data = await rootBundle.load(location);
  final buffer = img
      .decodeImage(data.buffer.asUint8List())!
      .getBytes(format: img.Format.luminance)
      .map((e) => e == 0 ? 0 : 1)
      .toList();
  return Uint8List.fromList(buffer);
}

class UserModel {
  final Map<String, Uint8List> share2s = {};

  void setDoor(String doorName, Uint8List share2) {
    share2s[doorName] = share2;
  }
}

class UsersModel extends ChangeNotifier {
  final Map<String, UserModel> _map = {};
  String? currentUserName;

  UsersModel();

  void setUser(String userName, UserModel user) {
    _map[userName] = user;
    notifyListeners();
  }

  void setCurrentUserName(String userName) {
    currentUserName = userName;
    notifyListeners();
  }

  Uint8List query(String doorName) {
    return _map[currentUserName]!.share2s[doorName]!;
  }

  List<String> queryOpenableDoor() {
    return _map[currentUserName]!.share2s.keys.toList();
  }
}

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    final users = ['user1', 'user2'];
    final openalbeDoors = context.watch<UsersModel>().queryOpenableDoor();
    for (final user in users) {
      debugPrint(user);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('User: '),
                DropdownButton(
                  value: context.watch<UsersModel>().currentUserName,
                  items: users
                      .map((String doorName) => DropdownMenuItem(
                          value: doorName, child: Text(doorName)))
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<UsersModel>().setCurrentUserName(newValue);
                    }
                  },
                ),
              ],
            ),
            const Text('Openable Doors:'),
            Expanded(
              child: ListView.builder(
                itemCount: openalbeDoors.length,
                itemBuilder: (BuildContext context, int index) {
                  return Center(child: Text(openalbeDoors[index]));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final user1 = UserModel();
  user1.setDoor(
    'door1',
    await loadDataFromAsset('assets/images/door1/door1_share2_1.png'),
  );
  user1.setDoor(
    'door2',
    await loadDataFromAsset('assets/images/door2/door2_share2_1.png'),
  );
  final user2 = UserModel();
  user2.setDoor(
    'door1',
    await loadDataFromAsset('assets/images/door1/door1_share2_2.png'),
  );
  user2.setDoor(
    'door2',
    await loadDataFromAsset('assets/images/door2/door2_share2_2.png'),
  );

  final users = UsersModel();
  users.setUser('user1', user1);
  users.setUser('user2', user2);

  users.setCurrentUserName('user1');

  runApp(
    ChangeNotifierProvider.value(
      value: users,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'User'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final cameraController = MobileScannerController(
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );
  Widget qrcode = const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Setting()),
              );
            },
            icon: const Icon(Icons.settings),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: MobileScanner(
              allowDuplicates: false,
              controller: cameraController,
              onDetect: (barcode, args) {
                if (barcode.rawValue == null) {
                  debugPrint('Failed to scan Barcode');
                } else {
                  final String code = barcode.rawValue!;
                  handleQrCode(code);
                }
              },
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            child: Center(child: qrcode),
          ),
        ],
      ),
    );
  }

  Widget generateQrCode(int seed, Uint8List share2) {
    Random rng = Random(seed);

    final buffer = Uint8List(share2.length ~/ 8);
    for (int i = 0; i < share2.length; i++) {
      buffer[i ~/ 8] |= (share2[i] << (i % 8));
    }
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] ^= rng.nextInt(256);
    }
    final data = base64Encode(buffer);
    debugPrint(data);

    return QrImage(
      data: data,
      version: QrVersions.auto,
    );
  }

  void handleQrCode(String data) {
    debugPrint(data);
    final tmp = data.split('&');
    final doorName = tmp[0].split('=')[1];
    final seed = int.parse(tmp[1].split('=')[1]);

    final share2 = context.read<UsersModel>().query(doorName);
    setState(() {
      qrcode = generateQrCode(seed, share2);
    });
  }
}
