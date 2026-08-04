import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

class PedidoPdfService {
  static Future<Uint8List?> _carregarFoto(String? path) async {
    if (path == null || path.trim().isEmpty) return null;

    final file = File(path);
    if (!file.existsSync()) return null;

    return await file.readAsBytes();
  }

  static Future<File> gerarPedidoPdf({
    required String titulo,
    required Map<String, String> cabecalho, // chave:valor
    required List<Map<String, String>> itensProdutos,
    required List<Map<String, String>> itensBolos,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final fotoBytes = await _carregarFoto(cabecalho['foto_bolo_local']);

    // =========================
    // MONEY (pt_BR + robust parse)
    // =========================
    double parseMoney(String? v) {
      if (v == null) return 0.0;
      var s = v.trim();
      if (s.isEmpty) return 0.0;

      s = s.replaceAll('R\$', '').replaceAll(' ', '');

      if (s.contains('.') && s.contains(',')) {
        final lastDot = s.lastIndexOf('.');
        final lastComma = s.lastIndexOf(',');
        if (lastComma > lastDot) {
          // 1.234,56 => pt_BR
          s = s.replaceAll('.', '').replaceAll(',', '.');
          return double.tryParse(s) ?? 0.0;
        } else {
          // 1,234.56 => en_US
          s = s.replaceAll(',', '');
          return double.tryParse(s) ?? 0.0;
        }
      }

      if (s.contains(',')) {
        // 1.234,56 => remove milhar e troca decimal
        s = s.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(s) ?? 0.0;
      }

      return double.tryParse(s) ?? 0.0;
    }

    final fmtMoney = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    );

    String money(num v) => fmtMoney.format(v);
    String moneyFromRaw(String? raw) => money(parseMoney(raw));

    double sumSubtotal(List<Map<String, String>> itens) {
      double total = 0.0;
      for (final it in itens) {
        final raw = it['sub'] ?? it['subtotal'] ?? '0';
        total += parseMoney(raw);
      }
      return total;
    }

    final totalProdutos = sumSubtotal(itensProdutos);
    final totalBolos = sumSubtotal(itensBolos);
    final totalGeral = totalProdutos + totalBolos;

    // =========================
    // UI helpers
    // =========================
    pw.Widget divider() => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: PdfColors.grey300,
    );

    pw.Widget chip(String text, {PdfColor bg = PdfColors.grey200}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
        );

    pw.Widget sectionTitle(String text, {required int qtd, PdfColor? bg}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            chip('Itens: $qtd', bg: bg ?? PdfColors.grey200),
          ],
        ),
      );
    }

    // =========================
    // HEADER logic
    // =========================
    bool isObsKey(String k) {
      final s = k.trim().toLowerCase();
      return s == 'observação' ||
          s == 'observacoes' ||
          s == 'observações' ||
          s == 'observacao' ||
          s == 'obs';
    }

    String getCab(Map<String, String> c, List<String> keys) {
      for (final k in keys) {
        final v = c[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }

      for (final e in c.entries) {
        final kk = e.key.trim().toLowerCase();
        for (final wanted in keys) {
          final w = wanted.trim().toLowerCase();
          if (w.isEmpty) continue;
          if (kk == w || kk.contains(w)) {
            final vv = e.value.trim();
            if (vv.isNotEmpty) return vv;
          }
        }
      }

      return '';
    }

    /// Se vier "ENTREGA: 2025-12-29 20:24" ou "2025-12-29T20:24", separa data/hora.
    /// E converte data ISO -> BR (29/12/2025).
    Map<String, String> splitEntregaIfNeeded(
      String dataEntrega,
      String horaEntrega,
    ) {
      var d = dataEntrega.trim();
      var h = horaEntrega.trim();

      if (h.isEmpty) {
        final m = RegExp(r'^(.+?)[T ](\d{1,2}:\d{2}(:\d{2})?)$').firstMatch(d);
        if (m != null) {
          d = m.group(1)!.trim();
          h = m.group(2)!.trim();
        }
      }

      // ISO yyyy-mm-dd -> dd/mm/yyyy
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(d);
      if (iso != null) {
        final yyyy = iso.group(1)!;
        final mm = iso.group(2)!;
        final dd = iso.group(3)!;
        d = '$dd/$mm/$yyyy';
      }

      return {'data': d, 'hora': h};
    }

    pw.Widget headerCard(String label, String value, {double? width}) {
      return pw.Container(
        width: width,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '${label.toUpperCase()}: ',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      );
    }

    pw.Widget headerBlock() {
      var dataEntrega = getCab(cabecalho, [
        'data_entrega',
        'data entrega',
        'data de entrega',
        'DATA_ENTREGA',
        'DATA DE ENTREGA',
      ]);

      var horaEntrega = getCab(cabecalho, [
        'hora_entrega',
        'hora entrega',
        'hora de entrega',
        'HORA_ENTREGA',
        'HORA',
      ]);

      // Quando vem como "ENTREGA: 2025-12-29 20:24"
      final entregaUnica = getCab(cabecalho, ['entrega', 'ENTREGA']);

      if ((dataEntrega.isEmpty && horaEntrega.isEmpty) &&
          entregaUnica.isNotEmpty) {
        final sep = splitEntregaIfNeeded(entregaUnica, '');
        dataEntrega = sep['data'] ?? '';
        horaEntrega = sep['hora'] ?? '';
      }

      final sep2 = splitEntregaIfNeeded(dataEntrega, horaEntrega);
      dataEntrega = sep2['data'] ?? '';
      horaEntrega = sep2['hora'] ?? '';

      String obsCab = '';
      for (final e in cabecalho.entries) {
        if (isObsKey(e.key)) {
          obsCab = e.value.trim();
          break;
        }
      }

      bool isEntregaKey(String k) {
        final s = k.trim().toLowerCase();
        return s.contains('data_entrega') ||
            s.contains('data entrega') ||
            s.contains('hora_entrega') ||
            s.contains('hora entrega') ||
            s.contains('data de entrega') ||
            s.contains('hora de entrega') ||
            s == 'entrega';
      }

      bool isFotoKey(String k) {
        final s = k.toLowerCase();
        return s.contains('foto');
      }

      final outros = <MapEntry<String, String>>[];
      for (final e in cabecalho.entries) {
        if (isObsKey(e.key)) continue;
        if (isEntregaKey(e.key)) continue;
        if (isFotoKey(e.key)) continue; // 👈 ESSENCIAL
        outros.add(e);
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.black,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    titulo,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    df.format(DateTime.now()),
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                ...outros.map((e) => headerCard(e.key, e.value, width: 250)),

                // ✅ DATA na frente da HORA (mesma linha)
                if (dataEntrega.isNotEmpty || horaEntrega.isNotEmpty)
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'DATA DE ENTREGA: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.TextSpan(
                            text: (dataEntrega.isEmpty
                                ? '--/--/----'
                                : dataEntrega),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.TextSpan(text: '       '),
                          pw.TextSpan(
                            text: 'HORA: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.TextSpan(
                            text: (horaEntrega.isEmpty ? '--:--' : horaEntrega),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            if (obsCab.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              headerCard('OBSERVAÇÃO', obsCab, width: double.infinity),
            ],
          ],
        ),
      );
    }

    // =========================
    // Table (Produtos e Bolos)
    // =========================
    pw.Widget itemsTable(
      List<Map<String, String>> itens, {
      required bool isBolos,
    }) {
      if (itens.isEmpty) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            'Nenhum item nesta seção.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        );
      }

      final headers = ['Descrição', 'Qtd', 'Unit', 'Subtotal'];

      String pick(Map<String, String> it, List<String> keys) {
        for (final k in keys) {
          final v = it[k];
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
        return '';
      }

      return pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.7),
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.7),
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(5),
          1: const pw.FlexColumnWidth(1.2),
          2: const pw.FlexColumnWidth(1.8),
          3: const pw.FlexColumnWidth(2.0),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isBolos ? PdfColors.amber100 : PdfColors.grey200,
            ),
            children: headers
                .map(
                  (h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          ...List.generate(itens.length, (i) {
            final it = itens[i];

            final tipo = pick(it, [
              'ITEM_TIPO',
              'item_tipo',
              'TIPO',
              'tipo',
            ]).toUpperCase();
            final isBoloRow = isBolos || (tipo == 'B');

            // ✅ BOLO: respeita exatamente o Firebird (ITEM_DESC1/2/3)
            final descBolo = pick(it, [
              'ITEM_DESC1',
              'item_desc1',
              'descricao1',
              'desc1',
              'descricao',
              'desc',
            ]);

            final recheio1 = pick(it, [
              'ITEM_DESC2',
              'item_desc2',
              'descricao2',
              'desc2',
            ]);

            final recheio2 = pick(it, [
              'ITEM_DESC3',
              'item_desc3',
              'descricao3',
              'desc3',
            ]);

            final obs = pick(it, ['ITEM_OBS', 'item_obs', 'observacao', 'obs']);

            // ✅ PRODUTO: pode concatenar
            final descProdutos = [
              pick(it, [
                'ITEM_DESC1',
                'item_desc1',
                'descricao1',
                'desc1',
                'descricao',
                'desc',
              ]),
              pick(it, ['ITEM_DESC2', 'item_desc2', 'descricao2', 'desc2']),
              pick(it, ['ITEM_DESC3', 'item_desc3', 'descricao3', 'desc3']),
            ].where((s) => s.trim().isNotEmpty).join(' ').trim();

            final descFinal = isBoloRow ? descBolo : descProdutos;

            final qtd = pick(it, ['qtd', 'quantidade', 'ITEM_QTD', 'item_qtd']);
            final unitRaw = pick(it, [
              'unit',
              'preco_unitario',
              'ITEM_PRECO',
              'item_preco',
            ]);
            final subRaw = pick(it, [
              'sub',
              'subtotal',
              'ITEM_SUBTOTAL',
              'item_subtotal',
            ]);

            final unitFmt = unitRaw.isEmpty ? '' : moneyFromRaw(unitRaw);
            final subFmt = subRaw.isEmpty ? '' : moneyFromRaw(subRaw);

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.white : PdfColors.grey50,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: isBoloRow
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              descFinal,
                              style: const pw.TextStyle(fontSize: 9),
                            ),

                            if (recheio1.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 3),
                                child: pw.Text(
                                  'RECHEIO 1: $recheio1',
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ),

                            if (recheio2.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  'RECHEIO 2: $recheio2',
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ),

                            if (obs.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Container(
                                  width: double.infinity,
                                  child: pw.Text(
                                    'OBSERVAÇÃO: $obs',
                                    softWrap: true,
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : pw.Text(
                          descFinal,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                ),

                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(qtd, style: const pw.TextStyle(fontSize: 9)),
                  ),
                ),

                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      unitFmt,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),

                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      subFmt,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }

    // =========================
    // TOTAL block (Resumo)
    // =========================
    pw.Widget totalBlock() {
      pw.Widget line(String label, String value, {bool bold = false}) {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColors.grey800,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColors.grey800,
              ),
            ),
          ],
        );
      }

      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 14),
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.black,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Resumo',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  line('Total Produtos', money(totalProdutos)),
                  pw.SizedBox(height: 6),
                  line('Total Bolos', money(totalBolos)),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  line('Total Geral', money(totalGeral), bold: true),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // =========================
    // PDF layout
    // =========================
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => [
          headerBlock(),
          divider(),

          sectionTitle(
            'Produtos',
            qtd: itensProdutos.length,
            bg: PdfColors.grey200,
          ),
          itemsTable(itensProdutos, isBolos: false),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Subtotal Produtos: ${money(totalProdutos)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),

          divider(),

          sectionTitle('Bolos', qtd: itensBolos.length, bg: PdfColors.amber100),
          itemsTable(itensBolos, isBolos: true),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Subtotal Bolos: ${money(totalBolos)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),

          totalBlock(),

          if (fotoBytes != null) ...[
            //pw.SizedBox(height: 24),
            //pw.Divider(),
            //pw.SizedBox(height: 12),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 6),

            pw.Text(
              'Imagem do bolo',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
              textAlign: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 10),

            pw.Center(
              child: pw.Container(
                width: 200, // 👈 menor largura
                height: 120, // 👈 menor altura (resolve o problema vertical)
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Image(
                  pw.MemoryImage(fotoBytes),
                  //fit: pw.BoxFit.contain,
                  fit: pw.BoxFit.fill,
                ),
              ),
            ),
          ],

          pw.SizedBox(height: 14),
          pw.Text(
            'Gerado em ${df.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/pedido_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
