import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class AdminExportUtil {
  /// Exports a list of rows to a CSV file and triggers a download in the browser.
  static void exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    List<List<dynamic>> csvData = [headers, ...rows];
    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(csvData);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "$filename.csv")
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Exports a professional PDF report with headers, stats, charts, and tables.
  static Future<void> exportPageToPdf({
    required String filename,
    required String title,
    String? subtitle,
    List<Map<String, String>>? kpis,
    List<Uint8List>? chartImages,
    required List<String> tableHeaders,
    required List<List<dynamic>> tableRows,
  }) async {
    final pdf = pw.Document();

    // Generate the PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // KPI Grid
            if (kpis != null && kpis.isNotEmpty) ...[
              pw.Text('Statistiques Clés', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.GridView(
                crossAxisCount: 3,
                childAspectRatio: 2,
                children: kpis.map((kpi) => pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  margin: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(kpi['label'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(kpi['value'] ?? '', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ],
                  ),
                )).toList(),
              ),
              pw.SizedBox(height: 30),
            ],

            // Charts Section
            if (chartImages != null && chartImages.isNotEmpty) ...[
              pw.Text('Graphiques et Visualisations', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: chartImages.map((img) => pw.Container(
                  width: 240,
                  height: 150,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200)),
                  child: pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain),
                )).toList(),
              ),
              pw.SizedBox(height: 30),
            ],

            // Data Table Section
            pw.Text('Données Détaillées', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: tableHeaders,
              data: tableRows,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    // Trigger Download
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$filename.pdf');
  }
}
