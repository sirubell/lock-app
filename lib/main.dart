import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
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
      home: const MyHomePage(title: 'Door'),
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
    // facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );
  Uint8List share2 = Uint8List(0);
  Widget qrcode = const SizedBox.shrink();

  @override
  void initState() {
    super.initState();

    rootBundle.load('assets/images/share2.png').then((data) {
      final buffer = img
          .decodeImage(data.buffer.asUint8List())!
          .getBytes(format: img.Format.luminance)
          .map((e) => e == 0 ? 1 : 0)
          .toList();

      setState(() {
        share2 = Uint8List.fromList(buffer);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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

  Widget generateQrCode(int seed) {
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
    final doorname = tmp[0].split('=')[1];
    final seed = int.parse(tmp[1].split('=')[1]);

    setState(() {
      qrcode = generateQrCode(seed);
    });
  }
}
