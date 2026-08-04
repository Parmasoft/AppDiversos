import '../../services/cotacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cotacao_online/app/app_config.dart';

class CotacaoNovaDesktopModal extends StatefulWidget {
  const CotacaoNovaDesktopModal({super.key});

  @override
  State<CotacaoNovaDesktopModal> createState() =>
      _CotacaoNovaDesktopModalState();
}

class _CotacaoNovaDesktopModalState extends State<CotacaoNovaDesktopModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController descricaoCtrl = TextEditingController();
  final _dtAberturaCtrl = TextEditingController();
  final _dtFechamentoCtrl = TextEditingController();
  final FocusNode _focusDescricao = FocusNode();

  final _focusDtAbertura = FocusNode();
  final _focusDtFechamento = FocusNode();
  final _focusSalvar = FocusNode();

  String? _numeroCotacao;
  bool _podeSalvar = false;

  bool _validarAbertura() {
    if (!_dataValida(_dtAberturaCtrl.text)) {
      _mostrarErro('Data de abertura inválida');
      _focusDtAbertura.requestFocus();
      return false;
    }
    return true;
  }

  bool _validarFechamento() {
    if (!_dataValida(_dtFechamentoCtrl.text)) {
      _mostrarErro('Data de fechamento inválida');
      _focusDtFechamento.requestFocus();
      return false;
    }
    return true;
  }

  bool _validarFormularioCompleto() {
    if (!_validarAbertura()) return false;
    if (!_validarFechamento()) return false;

    setState(() => _podeSalvar = true);
    return true;
  }

  bool _dataValida(String v) {
    if (v.length != 10) return false;
    final partes = v.split('/');
    if (partes.length != 3) return false;

    final d = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final a = int.tryParse(partes[2]);

    if (d == null || m == null || a == null) return false;

    try {
      DateTime(a, m, d);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    descricaoCtrl.dispose();
    _focusDescricao.dispose(); // 👈 ADICIONAR

    _dtAberturaCtrl.dispose();
    _dtFechamentoCtrl.dispose();

    _focusDtAbertura.dispose();
    _focusDtFechamento.dispose();
    _focusSalvar.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _iniciarNovaCotacao();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusDescricao.requestFocus(); // ✅ agora funciona
    });
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _fechar() => Navigator.pop(context);

  Future<void> salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_numeroCotacao == null) {
      _mostrarErro('Cotação ainda não foi inicializada');
      return;
    }

    try {
      await CotacaoService.atualizarDatas(
        empresa: 1,
        cotId: int.parse(_numeroCotacao!), // agora 100% seguro
        dataAbertura: _dtAberturaCtrl.text,
        dataFechamento: _dtFechamentoCtrl.text,
        descricao: descricaoCtrl.text.trim(),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar cotação: $e')),
      );
    }
  }

  Future<void> _iniciarNovaCotacao() async {
    try {
      setState(() => _podeSalvar = false);

      final resp = await CotacaoService.abrirCotacao(
        empresa: 1,
        usuario: 1,
      );

      setState(() {
        _numeroCotacao = resp['cot_id'].toString();
        _dtAberturaCtrl.text = resp['data_abertura'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao abrir nova cotação'),
          backgroundColor: Colors.red,
        ),
      );
      _fechar();
    }
  }

  String _hoje() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _SaveIntent(),
        },
        child: Actions(
          actions: {
            _BackIntent: CallbackAction(onInvoke: (_) => _fechar()),
            _SaveIntent: CallbackAction(onInvoke: (_) => salvar()),
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 1100,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF3C4),
                    Color(0xFFFFF9E6),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CABEÇALHO
                  Row(
                    children: [
                      IconButton(
                        onPressed: _fechar,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Voltar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // PAINEL BRANCO
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // TOPO
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Dados da Cotação',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Nº: ${_numeroCotacao ?? "..."}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'API: ${AppConfig.baseUrl}',
                                child: const Icon(Icons.info_outline),
                              )
                            ],
                          ),

                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ================================
                                    // DESCRIÇÃO DA COTAÇÃO
                                    // ================================
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _FieldLabel('DESCRIÇÃO'),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: descricaoCtrl,
                                          focusNode: _focusDescricao,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          textInputAction: TextInputAction
                                              .next, // 🔥 IMPORTANTE
                                          onEditingComplete: () {
                                            _focusDtAbertura
                                                .requestFocus(); // 🔥 PULA PARA DATA ABERTURA
                                          },
                                          decoration: _dec(
                                              'Ex: Cotação semanal – Hortifruti'),
                                          onChanged: (_) {
                                            setState(() => _podeSalvar = false);
                                          },
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                    ),

                                    const _FieldLabel('DATA ABERTURA'),
                                    const SizedBox(height: 6),
                                    _DateField(
                                      controller: _dtAberturaCtrl,
                                      focusNode: _focusDtAbertura,
                                      nextFocus: _focusDtFechamento,
                                      onPick: () => _pickDate(_dtAberturaCtrl),
                                      onValidate: () {
                                        final ok = _validarAbertura();
                                        setState(() => _podeSalvar =
                                            false); // ainda não pode salvar
                                        return ok;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    const _FieldLabel('DATA FECHAMENTO'),
                                    const SizedBox(height: 6),
                                    _DateField(
                                      controller: _dtFechamentoCtrl,
                                      focusNode: _focusDtFechamento,
                                      nextFocus: _focusSalvar,
                                      onPick: () =>
                                          _pickDate(_dtFechamentoCtrl),
                                      onValidate: () {
                                        final ok = _validarFechamento();
                                        if (ok) {
                                          _validarFormularioCompleto();

                                          // 🔥 FORÇA FOCO NO BOTÃO SALVAR
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                            _focusSalvar.requestFocus();
                                          });
                                        }
                                        return ok;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 160,
                              child: _SalvarButton(
                                onPressed: _podeSalvar ? salvar : null,
                                focusNode: _focusSalvar,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Atalhos: Ctrl+S Salvar • Esc Voltar',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ==== COMPONENTES ==== */

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E4D2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .4),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final VoidCallback onPick;
  final bool Function() onValidate;

  const _DateField({
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    required this.onPick,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
        LengthLimitingTextInputFormatter(10),
      ],
      //onChanged: (_) => onChanged(),
      onEditingComplete: () {
        controller.text = normalizarDataDigitada(controller.text);

        final ok = onValidate();

        if (ok && nextFocus != null) {
          nextFocus!.requestFocus();
        }
      },
      decoration: _dec('dd/MM/aaaa').copyWith(
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: onPick,
        ),
      ),
    );
  }
}

String normalizarDataDigitada(String valor) {
  final hoje = DateTime.now();

  String v = valor.replaceAll('/', '').trim();

  if (v.length == 2) {
    // dd
    return '${v}/'
        '${hoje.month.toString().padLeft(2, '0')}/'
        '${hoje.year}';
  }

  if (v.length == 4) {
    // ddMM
    return '${v.substring(0, 2)}/'
        '${v.substring(2, 4)}/'
        '${hoje.year}';
  }

  if (v.length == 6) {
    // ddMMyy
    return '${v.substring(0, 2)}/'
        '${v.substring(2, 4)}/'
        '20${v.substring(4, 6)}';
  }

  return valor; // já digitado completo
}

class _SalvarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final FocusNode focusNode;

  const _SalvarButton({
    required this.onPressed,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (onPressed != null) {
              onPressed!();
            }
            return null;
          },
        ),
      },
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: const Text('SALVAR'),
      ),
    );
  }
}

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

class _SaveIntent extends Intent {}

class _BackIntent extends Intent {}
