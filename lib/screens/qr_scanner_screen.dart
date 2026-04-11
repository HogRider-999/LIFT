// lib/screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isScanned = false; // 避免重複掃描導致彈窗多次

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 硬派深色底
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'SCAN PROGRAM',
          style: TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.accent), // 綠色返回鈕
      ),
      body: Stack(
        children: [
          // 相機預覽畫面
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return; // 已經掃描到就不要再跑了
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _isScanned = true;
                  // 掃描成功！退回上一頁並帶上代碼
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // 掃描框的裝飾線條
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.5), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  color: AppTheme.accent,
                  size: 60,
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              '請將 QR Code 對準框內',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white70, fontSize: 14, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }
}
