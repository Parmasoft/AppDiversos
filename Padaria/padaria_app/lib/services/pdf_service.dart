import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static Future<File> gerarPdfPedidoSimples({
    required String cliente,
    required String contato,
    required String formaPagamento,
    required DateTime dataEntrega,
    required String horaEntrega,
    required String observacoes,
  }) async {
    final pdf = pw.Document();

    final df = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PEDIDO PADARIA', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cliente: $cliente'),
                    pw.Text('Contato: $contato'),
                    pw.Text('Forma de pagamento: $formaPagamento'),
                    pw.Text('Entrega: ${df.format(dataEntrega)} às $horaEntrega'),
                    pw.SizedBox(height: 8),
                    pw.Text('Observações:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(observacoes.isEmpty ? '-' : observacoes),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),
              pw.Text('Itens (exemplo):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Produto')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qtd')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Subtotal')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pão Francês')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('10')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('R\$ 15,00')),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Text('Gerado em: ${df.format(DateTime.now())}'),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final nome = 'pedido_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$nome');

    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
