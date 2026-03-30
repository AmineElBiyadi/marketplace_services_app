import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─── Brand Colors ────────────────────────────────────────────────────────────
final _navy     = PdfColor.fromHex('#0F172A'); // Dark navy
final _blue     = PdfColor.fromHex('#3D5A99'); // Accent blue
final _blueLight= PdfColor.fromHex('#EFF6FF'); // Blue bg
final _greyBg   = PdfColor.fromHex('#F8FAFC'); // Alt row bg
final _greyText = PdfColor.fromHex('#64748B'); // Secondary text
final _border   = PdfColor.fromHex('#E2E8F0'); // Border

class AdminExportUtil {
  // ─── CSV Export ──────────────────────────────────────────────────────────────
  static void exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final csvData = [headers, ...rows];
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(csvData);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url  = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ─── PDF Export ──────────────────────────────────────────────────────────────
  static Future<void> exportPageToPdf({
    required String filename,
    required String title,
    String? subtitle,
    List<Map<String, String>>? kpis,
    List<Uint8List>? chartImages,
    required List<String> tableHeaders,
    required List<List<dynamic>> tableRows,
  }) async {
    final pdf    = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy at HH:mm').format(DateTime.now());

    // Fetch logo
    Uint8List? logoBytes;
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dt0swikte';
      final logoUrl = 'https://res.cloudinary.com/$cloudName/image/upload/v1/vuiqcy4zm2jo5op3vmje';
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode == 200) {
        logoBytes = response.bodyBytes;
      }
    } catch (e) {
      print('Error fetching logo: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (ctx) => _buildPageHeader(title, subtitle, dateStr, logoBytes),
        footer: (ctx) => _buildPageFooter(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          if (kpis != null && kpis.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(_buildSectionHeader('Key Performance Indicators'));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(_buildKpiGrid(kpis));
            widgets.add(pw.SizedBox(height: 24));
          }

          if (chartImages != null && chartImages.isNotEmpty) {
            widgets.add(_buildSectionHeader('Charts & Visualizations'));
            widgets.add(pw.SizedBox(height: 12));
            widgets.add(_buildChartsGrid(chartImages));
            widgets.add(pw.SizedBox(height: 24));
          }

          widgets.add(_buildSectionHeader('Detailed Data'));
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(_buildDataTable(tableHeaders, tableRows));

          return widgets;
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: '$filename.pdf');
  }

  // ─── Page Header ─────────────────────────────────────────────────────────────
  static pw.Widget _buildPageHeader(String title, String? subtitle, String date, Uint8List? logoBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: pw.BoxDecoration(color: _navy),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  if (logoBytes != null) ...[
                    pw.Container(
                      width: 40,
                      height: 40,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PRESTO ADMIN',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          subtitle,
                          style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _blue,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  date,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
        pw.Container(height: 3, color: _blue),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ─── Page Footer ─────────────────────────────────────────────────────────────
  static pw.Widget _buildPageFooter(pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Container(height: 1, color: _border),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Confidential Report – Presto Admin',
              style: pw.TextStyle(fontSize: 8, color: _greyText),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _greyText),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Section Header ──────────────────────────────────────────────────────────
  static pw.Widget _buildSectionHeader(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 4, height: 16, color: _blue),
            pw.SizedBox(width: 8),
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1, color: _border),
      ],
    );
  }

  // ─── KPI Grid ────────────────────────────────────────────────────────────────
  static pw.Widget _buildKpiGrid(List<Map<String, String>> kpis) {
    final cols = kpis.length <= 3 ? kpis.length : 3;
    final rows = <pw.Widget>[];
    for (int i = 0; i < kpis.length; i += cols) {
      final slice = kpis.sublist(i, (i + cols).clamp(0, kpis.length));
      rows.add(pw.Row(
        children: slice.map((kpi) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8, bottom: 8),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: pw.BoxDecoration(
              color: _blueLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _border, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  kpi['label'] ?? '',
                  style: pw.TextStyle(fontSize: 8, color: _greyText),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  kpi['value'] ?? '',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ));
    }
    return pw.Column(children: rows);
  }

  // ─── Charts Grid ─────────────────────────────────────────────────────────────
  static pw.Widget _buildChartsGrid(List<Uint8List> images) {
    final items = images.map((img) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Image(pw.MemoryImage(img), height: 160, fit: pw.BoxFit.contain),
        ),
      ),
    )).toList();

    final rows = <pw.Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(pw.Row(children: items.sublist(i, (i + 2).clamp(0, items.length))));
      rows.add(pw.SizedBox(height: 10));
    }
    return pw.Column(children: rows);
  }

  // ─── Data Table ──────────────────────────────────────────────────────────────
  static pw.Widget _buildDataTable(List<String> headers, List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        child: pw.Center(
          child: pw.Text(
            'No data available',
            style: pw.TextStyle(fontSize: 10, color: _greyText),
          ),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.map((r) => r.map((c) => c?.toString() ?? '').toList()).toList(),

      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        letterSpacing: 0.5,
      ),
      headerDecoration: pw.BoxDecoration(color: _navy),
      headerHeight: 24,

      cellStyle: pw.TextStyle(fontSize: 8, color: _navy),
      cellHeight: 20,
      cellAlignments: {for (int i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft},
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      rowDecoration: pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: pw.BoxDecoration(color: _greyBg),

      border: pw.TableBorder(
        bottom: pw.BorderSide(color: _border, width: 0.5),
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        left: pw.BorderSide(color: _border, width: 0.5),
        right: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide.none,
      ),
    );
  }
}
