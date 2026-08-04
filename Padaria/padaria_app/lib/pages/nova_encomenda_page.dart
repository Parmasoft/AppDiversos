import 'package:flutter/material.dart';

import 'cabecalho_page.dart';
import 'produtos_page.dart';
import 'bolos_page.dart';
import 'carrinho_page.dart';

class NovaEncomendaPage extends StatefulWidget {
  const NovaEncomendaPage({super.key});

  @override
  State<NovaEncomendaPage> createState() => _NovaEncomendaPageState();
}

class _NovaEncomendaPageState extends State<NovaEncomendaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// 🔹 CABEÇALHO DO PEDIDO
  Map<String, dynamic> cabecalhoPedido = {};

  // ================================
  // CONTROLLERS E ESTADO DO CABEÇALHO (AGORA NO PAI ✅)
  // ================================
  final TextEditingController clienteCtrl = TextEditingController();
  final TextEditingController contatoCtrl = TextEditingController();
  final TextEditingController observacaoCtrl = TextEditingController();

  String formaPagamento = 'Dinheiro';
  DateTime? dataEntrega;
  TimeOfDay? horaEntrega;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    // 🔒 BLOQUEIO DE TROCA DE ABA + ATUALIZA RODAPÉ
    _tabController.addListener(() {
      setState(() {}); // 👈 atualiza visibilidade do carrinho

      // Só nos interessa quando tenta sair da aba Cabeçalho
      if (_tabController.previousIndex == 0 && _tabController.index != 0) {
        if (!cabecalhoCompleto()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preencha todo o cabeçalho antes de continuar'),
            ),
          );

          // Volta imediatamente para o Cabeçalho
          Future.microtask(() {
            _tabController.animateTo(0);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();

    // ✅ Dispose dos controllers no PAI
    clienteCtrl.dispose();
    contatoCtrl.dispose();
    observacaoCtrl.dispose();

    super.dispose();
  }

  // ==================================================
  // VALIDAÇÃO DO CABEÇALHO
  // ==================================================
  bool cabecalhoCompleto() {
    return cabecalhoPedido['cliente']?.toString().trim().isNotEmpty == true &&
        cabecalhoPedido['contato']?.toString().trim().isNotEmpty == true &&
        cabecalhoPedido['forma_pagamento']?.toString().trim().isNotEmpty ==
            true &&
        cabecalhoPedido['data_entrega']?.toString().trim().isNotEmpty == true &&
        cabecalhoPedido['hora_entrega']?.toString().trim().isNotEmpty == true &&
        cabecalhoPedido['observacoes']?.toString().trim().isNotEmpty == true;
  }

  // ==================================================
  // AÇÃO: ABRIR CARRINHO
  // ==================================================
  void abrirCarrinho() {
    if (!cabecalhoCompleto()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finalize o cabeçalho antes de acessar o carrinho'),
        ),
      );

      // Garante que o usuário esteja no Cabeçalho
      _tabController.animateTo(0);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarrinhoPage(cabecalho: cabecalhoPedido),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0, // ✅ remove a linha de cima (ganha espaço)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Cabeçalho'),
                    Tab(text: 'Produtos'),
                    Tab(text: 'Bolos'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // 🔒 bloqueia swipe
        children: [
          /// 🔹 ABA CABEÇALHO
          CabecalhoPage(
            clienteCtrl: clienteCtrl,
            contatoCtrl: contatoCtrl,
            observacaoCtrl: observacaoCtrl,
            formaPagamento: formaPagamento,
            dataEntrega: dataEntrega,
            horaEntrega: horaEntrega,

            onStateChanged:
                ({
                  required String formaPagamentoNovo,
                  required DateTime? dataEntregaNova,
                  required TimeOfDay? horaEntregaNova,
                }) {
                  setState(() {
                    formaPagamento = formaPagamentoNovo;
                    dataEntrega = dataEntregaNova;
                    horaEntrega = horaEntregaNova;
                  });
                },

            onChanged: (dados) {
              cabecalhoPedido = dados;
              debugPrint('CABECALHO => $cabecalhoPedido');
            },
          ),

          /// 🔹 ABA PRODUTOS
          const ProdutosTab(),

          /// 🔹 ABA BOLOS
          BolosTab(),
        ],
      ),

      /// 🔹 RODAPÉ (CARRINHO)
      /// ❌ NÃO aparece na aba Cabeçalho
      /// ✅ Aparece somente em Produtos e Bolos
      bottomNavigationBar: _tabController.index == 0
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: abrirCarrinho,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Carrinho'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
    );
  }
}
