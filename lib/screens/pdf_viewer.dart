import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../core/api.dart';
import '../core/theme.dart';

class InvoicePdfScreen extends StatefulWidget {
  const InvoicePdfScreen({
    super.key,
    required this.api,
    required this.url,
    required this.title,
  });
  final MuskyApi api;
  final String url;
  final String title;

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  PdfController? _ctrl;
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;
  bool _saving = false;

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
      final bytes = await widget.api.downloadBytes(widget.url);
      if (!mounted) return;
      if (bytes.length < 4 ||
          bytes[0] != 0x25 || bytes[1] != 0x50 ||
          bytes[2] != 0x44 || bytes[3] != 0x46) {
        throw Exception('الملف المستلم ليس PDF صحيحاً (${bytes.length} bytes)');
      }
      final doc = await PdfDocument.openData(bytes);
      if (!mounted) return;
      final old = _ctrl;
      setState(() {
        _bytes = bytes;
        _ctrl = PdfController(document: Future.value(doc));
        _loading = false;
      });
      old?.dispose();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'تعذّر فتح الفاتورة: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _saving) return;
    setState(() => _saving = true);
    try {
      final suggested = '${widget.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.pdf';
      final location = await getSaveLocation(
        suggestedName: suggested,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null || !mounted) return;
      await File(location.path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الحفظ: ${location.path}'),
          backgroundColor: teal,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
          if (_bytes != null)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'حفظ PDF',
                    icon: const Icon(Icons.download_outlined, color: Colors.white),
                    onPressed: _save,
                  ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(32),
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
