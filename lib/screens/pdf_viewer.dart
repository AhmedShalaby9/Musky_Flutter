import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../core/theme.dart';

class InvoicePdfScreen extends StatefulWidget {
  const InvoicePdfScreen({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  PdfController? _ctrl;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.badCertificateCallback = (cert, host, port) => true;
      final request = await client.getUrl(Uri.parse(widget.url));
      final response = await request.close().timeout(const Duration(seconds: 30));
      final builder = BytesBuilder();
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > 20 * 1024 * 1024) {
          throw Exception('PDF too large');
        }
      }
      client.close(force: true);
      if (!mounted) return;
      final bytes = builder.toBytes();
      final old = _ctrl;
      setState(() {
        // PdfController takes Future<PdfDocument>
        _ctrl = PdfController(document: PdfDocument.openData(bytes));
        _loading = false;
      });
      old?.dispose();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل الفاتورة. تأكد من الاتصال وحاول مجدداً.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3C3C3C),
      appBar: AppBar(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة التحميل',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 56,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : PdfView(
                  controller: _ctrl!,
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  builders: PdfViewBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    pageLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
    );
  }
}
