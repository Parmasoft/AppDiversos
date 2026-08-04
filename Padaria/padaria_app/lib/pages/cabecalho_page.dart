import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';

class CabecalhoPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;

  // ✅ Controllers agora vêm do PAI
  final TextEditingController clienteCtrl;
  final TextEditingController contatoCtrl;
  final TextEditingController observacaoCtrl;

  // ✅ Estados agora vêm do PAI
  final String formaPagamento;
  final DateTime? dataEntrega;
  final TimeOfDay? horaEntrega;

  /// ✅ Callback para atualizar os estados no PAI
  final void Function({
    required String formaPagamentoNovo,
    required DateTime? dataEntregaNova,
    required TimeOfDay? horaEntregaNova,
  })
  onStateChanged;

  const CabecalhoPage({
    super.key,
    required this.onChanged,
    required this.clienteCtrl,
    required this.contatoCtrl,
    required this.observacaoCtrl,
    required this.formaPagamento,
    required this.dataEntrega,
    required this.horaEntrega,
    required this.onStateChanged,
  });

  @override
  State<CabecalhoPage> createState() => _CabecalhoPageState();
}

class _CabecalhoPageState extends State<CabecalhoPage>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  final maskTelefone = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final formasPagamento = [
    'Dinheiro',
    'Pix',
    'Crédito',
    'Débito',
    'A pagar na retirada',
  ];

  // FOTO DO BOLO (preview + upload depois)
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoBolo;

  Future<void> _anexarFotoBolo() async {
    final foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (foto == null) return;

    setState(() => _fotoBolo = foto);
    notificarAlteracao();
  }

  void _removerFotoBolo() {
    setState(() => _fotoBolo = null);
    notificarAlteracao();
  }

  OutlineInputBorder bordaPadrao() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Colors.black26),
  );

  // ==================================================
  // MONTA O MAP DO CABEÇALHO
  // ==================================================
  Map<String, dynamic> montarCabecalho() {
    return {
      'cliente': widget.clienteCtrl.text.trim(),
      'contato': widget.contatoCtrl.text.trim(),
      'forma_pagamento': widget.formaPagamento,
      'data_entrega': widget.dataEntrega != null
          ? DateFormat('yyyy-MM-dd').format(widget.dataEntrega!)
          : null,
      'hora_entrega': widget.horaEntrega != null
          ? widget.horaEntrega!.format(context)
          : null,
      'observacoes': widget.observacaoCtrl.text.trim(),
      'foto_bolo_local': _fotoBolo?.path,
    };
  }

  void notificarAlteracao() {
    widget.onChanged(montarCabecalho());
  }

  Future<void> escolherData() async {
    final hoje = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.dataEntrega ?? hoje,
      firstDate: hoje,
      lastDate: DateTime(hoje.year + 1),
    );

    if (picked != null) {
      widget.onStateChanged(
        formaPagamentoNovo: widget.formaPagamento,
        dataEntregaNova: picked,
        horaEntregaNova: widget.horaEntrega,
      );
      notificarAlteracao();
    }
  }

  Future<void> escolherHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.horaEntrega ?? TimeOfDay.now(),
    );

    if (picked != null) {
      widget.onStateChanged(
        formaPagamentoNovo: widget.formaPagamento,
        dataEntregaNova: widget.dataEntrega,
        horaEntregaNova: picked,
      );
      notificarAlteracao();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final dataFormatada = widget.dataEntrega == null
        ? 'Selecionar data'
        : DateFormat('dd/MM/yyyy').format(widget.dataEntrega!);

    final horaFormatada = widget.horaEntrega == null
        ? 'Selecionar hora'
        : widget.horaEntrega!.format(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF9C4), Color(0xFFFFF3E0)],
        ),
      ),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // CLIENTE
                TextFormField(
                  controller: widget.clienteCtrl,
                  onChanged: (_) => notificarAlteracao(),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o cliente'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Cliente',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    filled: true,
                    fillColor: Colors.white,
                    border: bordaPadrao(),
                  ),
                ),
                const SizedBox(height: 16),

                // CONTATO
                TextFormField(
                  controller: widget.contatoCtrl,
                  onChanged: (_) => notificarAlteracao(),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [maskTelefone],
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o contato'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Contato',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    filled: true,
                    fillColor: Colors.white,
                    border: bordaPadrao(),
                  ),
                ),
                const SizedBox(height: 16),

                // PAGAMENTO
                DropdownButtonFormField<String>(
                  value: widget.formaPagamento,
                  onChanged: (v) {
                    if (v == null) return;

                    widget.onStateChanged(
                      formaPagamentoNovo: v,
                      dataEntregaNova: widget.dataEntrega,
                      horaEntregaNova: widget.horaEntrega,
                    );
                    notificarAlteracao();
                  },
                  items: formasPagamento
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: 'Forma de Pagamento',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    filled: true,
                    fillColor: Colors.white,
                    border: bordaPadrao(),
                  ),
                ),
                const SizedBox(height: 16),

                // DATA
                FormField<DateTime>(
                  validator: (_) =>
                      widget.dataEntrega == null ? 'Selecione a data' : null,
                  builder: (field) => InkWell(
                    onTap: escolherData,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Data Entrega',
                        errorText: field.errorText,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: true,
                        fillColor: Colors.white,
                        border: bordaPadrao(),
                      ),
                      child: Text(dataFormatada),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // HORA
                FormField<TimeOfDay>(
                  validator: (_) =>
                      widget.horaEntrega == null ? 'Selecione a hora' : null,
                  builder: (field) => InkWell(
                    onTap: escolherHora,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Hora Entrega',
                        errorText: field.errorText,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: true,
                        fillColor: Colors.white,
                        border: bordaPadrao(),
                      ),
                      child: Text(horaFormatada),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // OBSERVAÇÕES
                TextFormField(
                  controller: widget.observacaoCtrl,
                  onChanged: (_) => notificarAlteracao(),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a observação'
                      : null,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observações',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    filled: true,
                    fillColor: Colors.white,
                    border: bordaPadrao(),
                  ),
                ),
                const SizedBox(height: 12),

                // FOTO DO BOLO (anexar + preview)
                OutlinedButton.icon(
                  onPressed: _anexarFotoBolo,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Anexar foto do bolo'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white, // ✅ fundo branco
                    foregroundColor: Colors.black,
                    side: const BorderSide(
                      color: Colors.black,
                      width: 1.5, // ✅ borda um pouco mais grossa
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16, // ⬆️ mais folga em cima/baixo
                      horizontal: 20, // ⬅️⬅️ ISSO resolve o texto encostando
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (_fotoBolo == null)
                  Container(
                    height: 160,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: const Text('Nenhuma foto anexada'),
                  )
                else
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_fotoBolo!.path),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: _removerFotoBolo,
                          tooltip: 'Remover foto',
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
