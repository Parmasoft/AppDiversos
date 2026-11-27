import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'local_draft_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _malhaApiBase = String.fromEnvironment(
  'MALHA_API_BASE',
  defaultValue: 'http://127.0.0.1:5056/api/v1',
);

void main() => runApp(const ParmaGestorApp());

class AppColors {
  static const yellow = Color(0xFFFFC928);
  static const lightYellow = Color(0xFFFFF7D6);
  static const ink = Color(0xFF20252B);
  static const muted = Color(0xFF68727D);
  static const surface = Color(0xFFFFFFFF);
}

class ParmaGestorApp extends StatelessWidget {
  const ParmaGestorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'ParmaGestor — Pedidos de Malhas',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.yellow,
        primary: AppColors.yellow,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
    ),
    home: const LoginScreen(),
  );
}

class RotatingBrand extends StatefulWidget {
  const RotatingBrand({super.key});

  @override
  State<RotatingBrand> createState() => _RotatingBrandState();
}

class _RotatingBrandState extends State<RotatingBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 310,
    height: 220,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _OrbitPainter(animation: _controller, foreground: false),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final turn = _controller.value;
            final angle = turn * 6.28318;
            final frontVisible = math.cos(angle) >= 0;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateY(angle),
              child: frontVisible
                  ? child
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: child,
                    ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, 7),
                child: Container(
                  width: 172,
                  height: 122,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DDE2),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 20,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 172,
                height: 122,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logo.jpeg',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _OrbitPainter(animation: _controller, foreground: true),
            ),
          ),
        ),
      ],
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.animation, required this.foreground})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value * 6.28318;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = foreground ? 2.4 : 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: foreground ? 0.78 : 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final first = Rect.fromCenter(center: center, width: 276, height: 94);
    final second = Rect.fromCenter(center: center, width: 228, height: 166);
    final sweep = foreground ? 1.10 : 2.05;
    final start = foreground ? phase : phase + 2.9;

    canvas.save();
    canvas.rotate((foreground ? -0.12 : 0.12) * math.sin(phase));
    canvas.drawArc(first, start, sweep, false, paint);
    canvas.drawArc(second, -start - 0.9, sweep, false, paint);
    canvas.restore();

    if (!foreground) {
      final softPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(center, 82, softPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.foreground != foreground ||
      oldDelegate.animation != animation;
}

class _CloudSession {
  const _CloudSession({
    required this.accessToken,
    required this.refreshToken,
    required this.companyId,
    required this.sellerId,
  });
  final String accessToken;
  final String refreshToken;
  final int companyId;
  final int sellerId;
}

class _SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'malhas_cloud_session';

  static Future<void> save(_CloudSession value) => _storage.write(
    key: _key,
    value: jsonEncode({
      'access_token': value.accessToken,
      'refresh_token': value.refreshToken,
      'company_id': value.companyId,
      'seller_id': value.sellerId,
    }),
  );
  static Future<void> clear() => _storage.delete(key: _key);
  static Future<_CloudSession?> readSession() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      return _CloudSession(
        accessToken: value['access_token'] as String,
        refreshToken: value['refresh_token'] as String,
        companyId: value['company_id'] as int,
        sellerId: value['seller_id'] as int,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<_CloudSession?> renewSession(_CloudSession current) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$_malhaApiBase/sessoes/renovar'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'refresh_token': current.refreshToken}));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        await clear();
        return null;
      }
      final data =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
      final next = _CloudSession(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        companyId: current.companyId,
        sellerId: current.sellerId,
      );
      await save(next);
      return next;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _loading = false;
  final _user = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$_malhaApiBase/sessoes'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({'usuario': _user.text, 'senha': _password.text}),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await utf8.decodeStream(response);
      client.close();
      if (!mounted) return;
      if (response.statusCode == 201) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        final seller = data['vendedor'] as Map<String, dynamic>?;
        final companyId = seller?['empresa'] as int?;
        final sellerId = seller?['id'] as int?;
        if (token == null ||
            token.isEmpty ||
            refresh == null ||
            refresh.isEmpty ||
            companyId == null ||
            sellerId == null) {
          throw HttpException('Sessão inválida.');
        }
        await _SessionStore.save(
          _CloudSession(
            accessToken: token,
            refreshToken: refresh,
            companyId: companyId,
            sellerId: sellerId,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SellerHomeScreen(
              accessToken: token,
              companyId: companyId,
              sellerId: sellerId,
            ),
          ),
        );
      } else {
        final message =
            (jsonDecode(body) as Map<String, dynamic>)['erro'] as String? ??
            'Não foi possível entrar.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on SocketException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API indisponível. Verifique a conexão USB.'),
          ),
        );
    } on HttpException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha de comunicação com a API.')),
        );
    } on TimeoutException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A API demorou para responder.')),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7), Color(0xFFF3F4F6)],
          stops: [0, 0.42, 1],
        ),
      ),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: SizedBox(
                      height: 176,
                      child: FittedBox(child: RotatingBrand()),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pedidos de Malhas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _LoginField(
                    label: 'Usuário',
                    icon: Icons.person_outline,
                    controller: _user,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 14),
                  _LoginField(
                    label: 'Senha',
                    icon: Icons.lock_outline,
                    controller: _password,
                    obscureText: _obscurePassword,
                    suffix: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _login,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_loading ? 'Entrando...' : 'Entrar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF202020),
                      minimumSize: const Size.fromHeight(56),
                      elevation: 3,
                      shadowColor: const Color(0x33000000),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.controller,
    this.textInputAction,
    this.onSubmitted,
  });
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscureText,
    textInputAction: textInputAction,
    onSubmitted: onSubmitted,
    scrollPadding: const EdgeInsets.only(bottom: 120),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDE1E5)),
      ),
    ),
  );
}

class SellerHomeScreen extends StatelessWidget {
  const SellerHomeScreen({
    super.key,
    required this.accessToken,
    required this.companyId,
    required this.sellerId,
  });
  final String accessToken;
  final int companyId;
  final int sellerId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF9E3), Color(0xFFF7EFC7), Color(0xFFF3F4F6)],
          stops: [0, 0.42, 1],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 700;
            final gridRatio = compactHeight ? 1.20 : 1.12;

            return ListView(
              padding: EdgeInsets.fromLTRB(24, compactHeight ? 14 : 18, 24, 12),
              children: [
                const Text(
                  'AÇÕES RÁPIDAS',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF74777B),
                  ),
                ),
                const SizedBox(height: 12),
                _PrimaryAction(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewOrderScreen(
                        accessToken: accessToken,
                        companyId: companyId,
                        sellerId: sellerId,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: gridRatio,
                  children: [
                    _SecondaryAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Meus Pedidos',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyOrdersScreen(
                            accessToken: accessToken,
                            companyId: companyId,
                            sellerId: sellerId,
                          ),
                        ),
                      ),
                    ),
                    _SecondaryAction(
                      icon: Icons.people_outline,
                      label: 'Meus Clientes',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyClientsScreen(
                            accessToken: accessToken,
                            companyId: companyId,
                            sellerId: sellerId,
                          ),
                        ),
                      ),
                    ),
                    const _SecondaryAction(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Financeiro',
                    ),
                    _SecondaryAction(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Novo Cliente',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NewProvisionalClientScreen(
                            accessToken: accessToken,
                            companyId: companyId,
                            sellerId: sellerId,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'RESUMO DEMONSTRATIVO',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF74777B),
                  ),
                ),
                const SizedBox(height: 12),
                const _SummaryCard(),
              ],
            );
          },
        ),
      ),
    ),
    bottomNavigationBar: NavigationBarTheme(
      data: const NavigationBarThemeData(
        height: 82,
        backgroundColor: Color(0xFFFEFEFC),
        indicatorColor: Color(0xFFFFF1B8),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            label: 'Sincronização',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    ),
  );
}

class MyClientsScreen extends StatefulWidget {
  const MyClientsScreen({
    super.key,
    required this.accessToken,
    required this.companyId,
    required this.sellerId,
    this.clientLookup,
    this.draftStore,
  });

  final String accessToken;
  final int companyId;
  final int sellerId;
  final ClientLookup? clientLookup;
  final LocalDraftStore? draftStore;

  @override
  State<MyClientsScreen> createState() => _MyClientsScreenState();
}

class _MyClientsScreenState extends State<MyClientsScreen> {
  final _searchController = TextEditingController();
  late final _CatalogApi _catalog = _CatalogApi(widget.accessToken);
  late final LocalDraftStore _draftStore =
      widget.draftStore ?? SqliteLocalDraftStore();
  List<ClientRecord> _clients = const [];
  List<LocalProvisionalClient> _provisionalClients = const [];
  bool _loading = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadProvisionalClients();
  }

  Future<void> _loadProvisionalClients() async {
    try {
      final clients = await _draftStore.listProvisionalClients(
        companyId: widget.companyId,
        sellerId: widget.sellerId,
      );
      if (mounted) setState(() => _provisionalClients = clients);
    } catch (_) {
      // Os clientes oficiais continuam disponiveis mesmo se o armazenamento local falhar.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final requestVersion = ++_requestVersion;
    if (query.length < 3) {
      setState(() {
        _clients = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lookup = widget.clientLookup ?? _catalog.clientRecords;
      final result = await lookup(query);
      if (!mounted || requestVersion != _requestVersion) return;
      final normalizedQuery = _normalizeClientText(query);
      setState(() {
        _clients = result
            .where((client) {
              final searchable =
                  '${client.code} ${client.name} ${client.fantasyName}';
              return _normalizeClientText(searchable).contains(normalizedQuery);
            })
            .toList(growable: false);
      });
    } on _CatalogException catch (error) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && requestVersion == _requestVersion) {
        setState(
          () => _error =
              'Não foi possível consultar os clientes. Tente novamente.',
        );
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final normalizedQuery = _normalizeClientText(query);
    final visibleProvisionalClients = _provisionalClients
        .where((client) {
          if (normalizedQuery.isEmpty) return true;
          return _normalizeClientText(
            '${client.name} ${client.fantasyName ?? ''} ${client.document}',
          ).contains(normalizedQuery);
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.ink,
        title: const Text(
          'Meus Clientes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NewProvisionalClientScreen(
                    accessToken: widget.accessToken,
                    companyId: widget.companyId,
                    sellerId: widget.sellerId,
                    draftStore: _draftStore,
                  ),
                ),
              );
              if (mounted) _loadProvisionalClients();
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('+ Novo Cliente'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Pesquisar cliente',
              hintText: 'Nome, fantasia ou código',
              prefixIcon: const Icon(Icons.search, color: AppColors.ink),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (visibleProvisionalClients.isNotEmpty) ...[
            const Text(
              'CLIENTES NOVOS NESTE APARELHO',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            for (final client in visibleProvisionalClients) ...[
              _ProvisionalClientCard(client: client),
              const SizedBox(height: 10),
            ],
          ],
          if (query.length < 3)
            const _ClientEmptyState(
              icon: Icons.manage_search_outlined,
              message:
                  'Digite ao menos 3 caracteres para pesquisar clientes cadastrados no sistema.',
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _CatalogError(message: _error!, onRetry: () => _search(query))
          else ...[
            Text(
              '${_clients.length + visibleProvisionalClients.length} ${(_clients.length + visibleProvisionalClients.length) == 1 ? 'cliente encontrado' : 'clientes encontrados'}',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (_clients.isEmpty)
              const _ClientEmptyState(
                icon: Icons.people_outline,
                message: 'Nenhum cliente encontrado para esta pesquisa.',
              )
            else
              for (final client in _clients) ...[
                _ClientCard(
                  client: client,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClientDetailsScreen(client: client),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }
}

class ClientDetailsScreen extends StatelessWidget {
  const ClientDetailsScreen({super.key, required this.client});
  final ClientRecord client;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.ink,
      title: const Text(
        'Dados do Cliente',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E4E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('CLIENTE'),
              const SizedBox(height: 8),
              Text(
                client.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              _ClientDetail(label: 'Código', value: client.code),
              if (client.fantasyName.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ClientDetail(
                  label: 'Nome fantasia',
                  value: client.fantasyName,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ClientDetail extends StatelessWidget {
  const _ClientDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});
  final ClientRecord client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E4E8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.lightYellow,
              foregroundColor: AppColors.ink,
              child: Icon(Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  if (client.fantasyName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      client.fantasyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    'Código ${client.code}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _ProvisionalClientCard extends StatelessWidget {
  const _ProvisionalClientCard({required this.client});
  final LocalProvisionalClient client;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.yellow, width: 1.4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.lightYellow,
          foregroundColor: AppColors.ink,
          child: Icon(Icons.person_add_alt_1_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              if ((client.fantasyName ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  client.fantasyName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Novo no aparelho - pendente de envio',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class NewProvisionalClientScreen extends StatefulWidget {
  const NewProvisionalClientScreen({
    super.key,
    required this.accessToken,
    required this.companyId,
    required this.sellerId,
    this.draftStore,
  });

  final String accessToken;
  final int companyId;
  final int sellerId;
  final LocalDraftStore? draftStore;

  @override
  State<NewProvisionalClientScreen> createState() =>
      _NewProvisionalClientScreenState();
}

class _NewProvisionalClientScreenState
    extends State<NewProvisionalClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fantasyController = TextEditingController();
  final _stateRegistrationController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  late final LocalDraftStore _draftStore =
      widget.draftStore ?? SqliteLocalDraftStore();
  String _personType = 'PF';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _fantasyController.dispose();
    _stateRegistrationController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _zipCodeController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      final client = await _draftStore.saveProvisionalClient(
        LocalProvisionalClient(
          localId: newLocalProvisionalClientId(),
          companyId: widget.companyId,
          sellerId: widget.sellerId,
          personType: _personType,
          name: _nameController.text.trim(),
          document: _onlyDigits(_documentController.text),
          phone: _onlyDigits(_phoneController.text),
          fantasyName:
              _personType == 'PJ' && _fantasyController.text.trim().isNotEmpty
              ? _fantasyController.text.trim()
              : null,
          stateRegistration: _optional(_stateRegistrationController),
          email: _optional(_emailController),
          whatsapp: _onlyDigits(_whatsappController.text).isEmpty
              ? null
              : _onlyDigits(_whatsappController.text),
          zipCode: _onlyDigits(_zipCodeController.text).isEmpty
              ? null
              : _onlyDigits(_zipCodeController.text),
          street: _optional(_streetController),
          number: _optional(_numberController),
          complement: _optional(_complementController),
          neighborhood: _optional(_neighborhoodController),
          city: _optional(_cityController),
          state: _optional(_stateController)?.toUpperCase(),
          status: provisionalClientStatus,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E7D32),
            size: 38,
          ),
          title: const Text('Cliente salvo neste aparelho'),
          content: const Text(
            'O cadastro esta pendente de envio para a empresa.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Meus Clientes'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => NewOrderScreen(
                      accessToken: widget.accessToken,
                      companyId: widget.companyId,
                      sellerId: widget.sellerId,
                      initialClientId: client.orderClientId,
                      initialClientName: client.name,
                      draftStore: _draftStore,
                    ),
                  ),
                );
              },
              child: const Text('Novo Pedido'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.ink,
      title: const Text(
        'Novo Cliente',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Cadastro local provisório',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'O cliente ficará pendente de envio e ainda não receberá um código do sistema.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PF', label: Text('Pessoa Física')),
                ButtonSegment(value: 'PJ', label: Text('Pessoa Jurídica')),
              ],
              selected: {_personType},
              onSelectionChanged: (value) => setState(() {
                _personType = value.single;
                _documentController.clear();
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _personType == 'PF'
                    ? 'Nome completo'
                    : 'Razão social',
              ),
              validator: (value) => (value ?? '').trim().length < 3
                  ? 'Informe ${_personType == 'PF' ? 'o nome completo' : 'a razão social'}.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _documentController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _DocumentMaskFormatter(cnpj: _personType == 'PJ'),
              ],
              decoration: InputDecoration(
                labelText: _personType == 'PF' ? 'CPF' : 'CNPJ',
              ),
              validator: (value) => _personType == 'PF'
                  ? (isValidCpf(value ?? '') ? null : 'Informe um CPF válido.')
                  : (isValidCnpj(value ?? '')
                        ? null
                        : 'Informe um CNPJ válido.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _PhoneMaskFormatter(),
              ],
              decoration: const InputDecoration(labelText: 'Telefone com DDD'),
              validator: (value) {
                final length = _onlyDigits(value ?? '').length;
                return length == 10 || length == 11
                    ? null
                    : 'Informe telefone com DDD.';
              },
            ),
            if (_personType == 'PJ') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _fantasyController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome fantasia (opcional)',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _stateRegistrationController, decoration: const InputDecoration(labelText: 'Inscri\u00e7\u00e3o estadual (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _whatsappController, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, _PhoneMaskFormatter()], decoration: const InputDecoration(labelText: 'WhatsApp com DDD (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _zipCodeController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CepMaskFormatter()], decoration: const InputDecoration(labelText: 'CEP (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _streetController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Logradouro (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _numberController, keyboardType: TextInputType.streetAddress, decoration: const InputDecoration(labelText: 'N\u00famero (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _complementController, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Complemento (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _neighborhoodController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Bairro (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _cityController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Cidade (opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _stateController, textCapitalization: TextCapitalization.characters, inputFormatters: [LengthLimitingTextInputFormatter(2)], decoration: const InputDecoration(labelText: 'Estado / UF (opcional)')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar cliente'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');
String? _optional(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : value;
}

bool isValidCpf(String value) {
  final digits = _onlyDigits(value);
  if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits))
    return false;
  int digit(int length) =>
      (List<int>.generate(
            length,
            (index) => int.parse(digits[index]) * (length + 1 - index),
          ).reduce((a, b) => a + b) *
          10) %
      11 %
      10;
  return digit(9) == int.parse(digits[9]) && digit(10) == int.parse(digits[10]);
}

bool isValidCnpj(String value) {
  final digits = _onlyDigits(value);
  if (digits.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(digits))
    return false;
  int check(List<int> weights) {
    var sum = 0;
    for (var index = 0; index < weights.length; index++) {
      sum += int.parse(digits[index]) * weights[index];
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }

  return check([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) == int.parse(digits[12]) &&
      check([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) == int.parse(digits[13]);
}

class _DocumentMaskFormatter extends TextInputFormatter {
  _DocumentMaskFormatter({required this.cnpj});
  final bool cnpj;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _onlyDigits(
      newValue.text,
    ).substring(0, math.min(cnpj ? 14 : 11, _onlyDigits(newValue.text).length));
    final formatted = cnpj ? _formatCnpj(digits) : _formatCpf(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatCpf(String value) => value.length <= 3
    ? value
    : value.length <= 6
    ? '${value.substring(0, 3)}.${value.substring(3)}'
    : value.length <= 9
    ? '${value.substring(0, 3)}.${value.substring(3, 6)}.${value.substring(6)}'
    : '${value.substring(0, 3)}.${value.substring(3, 6)}.${value.substring(6, 9)}-${value.substring(9)}';
String _formatCnpj(String value) => value.length <= 2
    ? value
    : value.length <= 5
    ? '${value.substring(0, 2)}.${value.substring(2)}'
    : value.length <= 8
    ? '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5)}'
    : value.length <= 12
    ? '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/${value.substring(8)}'
    : '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/${value.substring(8, 12)}-${value.substring(12)}';

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = _onlyDigits(
      newValue.text,
    ).substring(0, math.min(11, _onlyDigits(newValue.text).length));
    final text = value.length <= 2
        ? value
        : value.length <= 6
        ? '(${value.substring(0, 2)}) ${value.substring(2)}'
        : value.length <= 10
        ? '(${value.substring(0, 2)}) ${value.substring(2, 6)}-${value.substring(6)}'
        : '(${value.substring(0, 2)}) ${value.substring(2, 7)}-${value.substring(7)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CepMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = _onlyDigits(newValue.text);
    final value = digits.substring(0, math.min(8, digits.length));
    final text = value.length <= 5 ? value : '${value.substring(0, 5)}-${value.substring(5)}';
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ClientEmptyState extends StatelessWidget {
  const _ClientEmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(icon, size: 46, color: AppColors.muted),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

String _normalizeClientText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàãâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòõôö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({
    super.key,
    required this.accessToken,
    required this.companyId,
    required this.sellerId,
    this.draftStore,
    this.useInMemoryCatalog = false,
  });

  final String accessToken;
  final int companyId;
  final int sellerId;
  final LocalDraftStore? draftStore;
  final bool useInMemoryCatalog;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late final LocalDraftStore _draftStore =
      widget.draftStore ?? SqliteLocalDraftStore();
  List<LocalOrderDraft> _drafts = const [];
  bool _loading = true;
  String? _error;
  String? _sendingId;

  Future<void> _sendDraft(LocalOrderDraft draft) async {
    if (_sendingId != null || draft.status == localReceivedStatus) return;
    setState(() => _sendingId = draft.localId);
    try {
      LocalProvisionalClient? provisional;
      if (draft.clientId?.startsWith(provisionalClientIdPrefix) == true) {
        final clients = await _draftStore.listProvisionalClients(
          companyId: widget.companyId,
          sellerId: widget.sellerId,
        );
        final localId = draft.clientId!.substring(
          provisionalClientIdPrefix.length,
        );
        for (final client in clients) {
          if (client.localId == localId) {
            provisional = client;
            break;
          }
        }
      }
      if (draft.clientId == null ||
          draft.clientName == null ||
          draft.paymentMethodId == null ||
          draft.deliveryDays == null ||
          draft.deliveryDate == null ||
          draft.isManagerial == null ||
          draft.lines.isEmpty ||
          (draft.clientId!.startsWith(provisionalClientIdPrefix) &&
              provisional == null))
        throw StateError('Pedido local incompleto.');
      for (var index = 0; index < draft.lines.length; index++) {
        final price = draft.lines[index].unitPrice;
        if (price == null || price.trim().isEmpty) {
          throw StateError(
            'O item ${index + 1} não possui preço unitário salvo. '
            'Abra o pedido, informe o preço e tente novamente.',
          );
        }
      }
      await _draftStore.updateSendState(
        draft: draft,
        status: localSendingStatus,
        remoteOrderId: draft.remoteOrderId,
      );
      final receipt = await _OrderReceptionApi(
        widget.accessToken,
      ).send(draft, provisional);
      await _draftStore.updateSendState(
        draft: draft,
        status: localReceivedStatus,
        remoteOrderId: receipt,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pedido recebido pela API. Aguardando processamento pela empresa.',
            ),
          ),
        );
    } catch (error) {
      await _draftStore.updateSendState(
        draft: draft,
        status: localSendErrorStatus,
        remoteOrderId: draft.remoteOrderId,
        sendError: error.toString(),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.toString().replaceFirst('Bad state: ', '')
                  : 'Envio nao confirmado. O pedido permanece salvo para nova tentativa.',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _sendingId = null);
        _loadDrafts();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final drafts = await _draftStore.listDrafts(
        companyId: widget.companyId,
        sellerId: widget.sellerId,
      );
      for (final draft in drafts.where(
        (draft) => draft.status == localSendingStatus,
      )) {
        await _draftStore.updateSendState(
          draft: draft,
          status: localPendingSendStatus,
          remoteOrderId: draft.remoteOrderId,
        );
      }
      final visibleDrafts = await _draftStore.listDrafts(
        companyId: widget.companyId,
        sellerId: widget.sellerId,
      );
      if (mounted) {
        setState(() => _drafts = _sortDraftsForDisplay(visibleDrafts));
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível carregar os pedidos locais.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LocalOrderDraft> _sortDraftsForDisplay(List<LocalOrderDraft> drafts) {
    final indexedDrafts = List.generate(
      drafts.length,
      (index) => (index: index, draft: drafts[index]),
    );
    indexedDrafts.sort((first, second) {
      final firstPriority = first.draft.status == localReceivedStatus ? 1 : 0;
      final secondPriority = second.draft.status == localReceivedStatus ? 1 : 0;
      final priorityComparison = firstPriority.compareTo(secondPriority);
      return priorityComparison != 0
          ? priorityComparison
          : first.index.compareTo(second.index);
    });
    return indexedDrafts.map((entry) => entry.draft).toList(growable: false);
  }

  Future<void> _openDraft(LocalOrderDraft draft) async {
    if (draft.status == localReceivedStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido recebido: edicao bloqueada.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewOrderScreen(
          accessToken: widget.accessToken,
          companyId: widget.companyId,
          sellerId: widget.sellerId,
          draftId: draft.localId,
          draftStore: _draftStore,
          useInMemoryCatalog: widget.useInMemoryCatalog,
        ),
      ),
    );
    if (mounted) _loadDrafts();
  }

  Future<void> _newOrder() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewOrderScreen(
          accessToken: widget.accessToken,
          companyId: widget.companyId,
          sellerId: widget.sellerId,
          draftStore: _draftStore,
          useInMemoryCatalog: widget.useInMemoryCatalog,
        ),
      ),
    );
    if (mounted) _loadDrafts();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.ink,
      title: const Text(
        'Meus Pedidos',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _newOrder,
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.ink,
      icon: const Icon(Icons.add_shopping_cart_outlined),
      label: const Text(
        'Novo pedido',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _loadDrafts,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _CatalogError(message: _error!, onRetry: _loadDrafts),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _OrdersSummary(
                  pendingCount: _drafts
                      .where((draft) => draft.status != localReceivedStatus)
                      .length,
                  sentCount: _drafts
                      .where((draft) => draft.status == localReceivedStatus)
                      .length,
                ),
                const SizedBox(height: 22),
                const _SectionTitle('PEDIDOS PENDENTES'),
                const SizedBox(height: 10),
                if (_drafts.isEmpty)
                  const _EmptyOrderLines(
                    message: 'Nenhum pedido salvo neste aparelho.',
                  )
                else
                  for (final draft in _drafts) ...[
                    _LocalDraftCard(
                      draft: draft,
                      onTap: () => _openDraft(draft),
                      onSend: _sendingId == null
                          ? () => _sendDraft(draft)
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 18),
                const _SectionTitle('ENVIADOS'),
                const SizedBox(height: 10),
                const _EmptyOrderLines(message: 'Nenhum pedido enviado ainda.'),
              ],
            ),
    ),
  );
}

class _OrdersSummary extends StatelessWidget {
  const _OrdersSummary({
    required this.pendingCount,
    required this.sentCount,
  });
  final int pendingCount;
  final int sentCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E4E8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.lightYellow,
          foregroundColor: AppColors.ink,
          child: Icon(Icons.edit_note_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$pendingCount ${pendingCount == 1 ? 'pedido pendente' : 'pedidos pendentes'}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: AppColors.ink,
            ),
          ),
        ),
        Text(
          '$sentCount ${sentCount == 1 ? 'enviado' : 'enviados'}',
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LocalDraftCard extends StatelessWidget {
  const _LocalDraftCard({
    required this.draft,
    required this.onTap,
    this.onSend,
  });
  final LocalOrderDraft draft;
  final VoidCallback onTap;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final line in draft.lines) {
      final unit = line.unit.trim().toUpperCase();
      totals.update(
        unit,
        (total) => total + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E4E8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      draft.status == localReceivedStatus
                          ? 'Recebido pela API'
                          : draft.status == localSendErrorStatus
                          ? 'Erro de envio'
                          : draft.status == localSendingStatus
                          ? 'Enviando'
                          : 'Pendente de envio',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.ink,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                draft.clientName ?? 'Cliente não informado',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Nº local ${draft.localId.length > 8 ? draft.localId.substring(draft.localId.length - 8) : draft.localId} • ${_formatLocalDate(draft.updatedAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                '${draft.lines.length} ${draft.lines.length == 1 ? 'produto diferente' : 'produtos diferentes'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: totals.entries
                    .map(
                      (entry) => Text(
                        '${_formatLocalQuantity(entry.value)} ${entry.key}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (draft.status == localSendErrorStatus) ...[
                OutlinedButton.icon(
                  onPressed: () => _showSendError(context, draft.sendError),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Ver motivo do erro'),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: draft.status == localReceivedStatus ? null : onSend,
                icon: const Icon(Icons.send_outlined),
                label: Text(
                  draft.status == localReceivedStatus
                      ? 'Recebido pela API'
                      : 'Enviar pedido',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSendError(BuildContext context, String? error) {
    final detail = error?.trim();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Motivo do erro de envio'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: SelectableText(
              detail == null || detail.isEmpty
                  ? 'Detalhe do erro não disponível'
                  : detail,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

String _formatLocalQuantity(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value
          .toStringAsFixed(3)
          .replaceAll('.', ',')
          .replaceFirst(RegExp(r',?0+$'), '');

String _formatLocalDate(DateTime value) {
  final local = value.toLocal();
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year} ${pad(local.hour)}:${pad(local.minute)}';
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF202427),
    elevation: 5,
    shadowColor: const Color(0x38000000),
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 112,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFFFE172),
                child: Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 32,
                  color: Color(0xFF101418),
                ),
              ),
              SizedBox(width: 22),
              Expanded(
                child: Text(
                  'Novo Pedido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 34),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3C9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF101010), size: 32),
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF101010),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: const Row(
      children: [
        Expanded(
          child: _Metric(value: '03', label: 'Pendentes'),
        ),
        _MetricDivider(),
        Expanded(
          child: _Metric(value: '12', label: 'Recebidos'),
        ),
        _MetricDivider(),
        Expanded(
          child: _Metric(value: '01', label: 'A sincronizar'),
        ),
      ],
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 58, width: 1, color: const Color(0xFFE0E2E5));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFF101010),
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ],
  );
}

class _OrderSearchOption {
  const _OrderSearchOption({
    required this.code,
    required this.label,
    this.unit = 'kg',
    this.quantityPrecision = 3,
    this.unitPrice,
  });

  final String code;
  final String label;
  final String unit;
  final int quantityPrecision;
  final String? unitPrice;

  @override
  bool operator ==(Object other) =>
      other is _OrderSearchOption && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

typedef _OrderSearchLookup =
    Future<List<_OrderSearchOption>> Function(String query);

class ClientRecord {
  const ClientRecord({
    required this.code,
    required this.name,
    required this.fantasyName,
  });

  final String code;
  final String name;
  final String fantasyName;

  String get orderLabel => fantasyName.isEmpty ? name : '$name - $fantasyName';
}

typedef ClientLookup = Future<List<ClientRecord>> Function(String query);

class _CatalogException implements Exception {
  const _CatalogException(this.message, {this.sessionExpired = false});
  final String message;
  final bool sessionExpired;
}

BigInt _scaled(String value, int scale) {
  final parts = value.trim().replaceAll(',', '.').split('.');
  final whole = parts.first.isEmpty ? '0' : parts.first;
  final fraction = (parts.length > 1 ? parts[1] : '')
      .padRight(scale, '0')
      .substring(0, scale);
  return BigInt.parse(whole) * BigInt.from(10).pow(scale) +
      BigInt.parse(fraction);
}

String _money(BigInt scaled) {
  final base = BigInt.from(10000);
  final whole = scaled ~/ base;
  final fraction = (scaled % base).toString().padLeft(4, '0');
  return '$whole.$fraction';
}

String _subtotal(String quantity, String price) =>
    _money((_scaled(quantity, 6) * _scaled(price, 4)) ~/ BigInt.from(1000000));

class _OrderReceptionApi {
  const _OrderReceptionApi(this.accessToken);
  final String accessToken;

  Future<String> send(
    LocalOrderDraft draft,
    LocalProvisionalClient? provisional,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$_malhaApiBase/pedidos'));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final isProvisional = provisional != null;
      final items = draft.lines.map((line) {
        final quantity = line.quantity.toStringAsFixed(6);
        final price = line.unitPrice;
        if (price == null || price.trim().isEmpty) {
          throw StateError('Item sem preço unitário salvo.');
        }
        return {
          'produto_id': int.parse(line.productId),
          'descricao': line.description,
          'unidade': line.unit,
          'quantidade': quantity,
          'valor_unitario': _money(_scaled(price, 4)),
          'subtotal': _subtotal(quantity, price),
        };
      }).toList();
      final total = items.fold<BigInt>(
        BigInt.zero,
        (sum, line) => sum + _scaled(line['subtotal']! as String, 4),
      );
      final body = {
        'local_id': draft.localId,
        'created_at': draft.createdAt.toUtc().toIso8601String(),
        'cliente': isProvisional
            ? {
                'tipo': 'provisorio',
                'nome': draft.clientName,
                'provisorio': {
                  'local_id': provisional.localId,
                  'tipo_pessoa': provisional.personType,
                  'nome': provisional.name,
                  'fantasia': provisional.fantasyName ?? '',
                  'cpf_cnpj': provisional.document,
                  'telefone': provisional.phone,
                  'inscricao_estadual': provisional.stateRegistration ?? '',
                  'email': provisional.email ?? '',
                  'whatsapp': provisional.whatsapp ?? '',
                  'cep': provisional.zipCode ?? '',
                  'logradouro': provisional.street ?? '',
                  'numero': provisional.number ?? '',
                  'complemento': provisional.complement ?? '',
                  'bairro': provisional.neighborhood ?? '',
                  'cidade': provisional.city ?? '',
                  'uf': provisional.state ?? '',
                },
              }
            : {
                'tipo': 'oficial',
                'id': int.parse(draft.clientId!),
                'nome': draft.clientName,
              },
        'forma_pagamento_id': int.parse(draft.paymentMethodId!),
        'prazo_dias': draft.deliveryDays,
        'previsao_entrega':
            '${draft.deliveryDate!.year.toString().padLeft(4, '0')}-${draft.deliveryDate!.month.toString().padLeft(2, '0')}-${draft.deliveryDate!.day.toString().padLeft(2, '0')}',
        'gerencial': draft.isManagerial,
        'observacoes': draft.notes ?? '',
        'itens': items,
        'valor_total': _money(total),
      };
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final decoded =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
      if (response.statusCode != 200 && response.statusCode != 201)
        throw HttpException(
          decoded['erro'] as String? ?? 'Falha ao enviar pedido.',
        );
      final id = decoded['id'] as String?;
      if (id == null || id.isEmpty)
        throw const HttpException('Recibo invalido.');
      return id;
    } on SocketException {
      throw const HttpException('Sem conexao com a API.');
    } on TimeoutException {
      final recovered = await _findByLocalId(draft.localId);
      if (recovered != null) return recovered;
      throw const HttpException(
        'Tempo de envio esgotado. O pedido permaneceu pendente para reenvio.',
      );
    } finally {
      client.close();
    }
  }

  Future<String?> _findByLocalId(String localId) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$_malhaApiBase/pedidos'));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      final data =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
      for (final value in (data['pedidos'] as List? ?? const [])) {
        final row = value as Map<String, dynamic>;
        if (row['pedido_local_id'] == localId) return row['id'] as String?;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }
}

class _CatalogApi {
  const _CatalogApi(this.accessToken);
  final String accessToken;

  Future<List<_OrderSearchOption>> clients(String query) async {
    final items = await _get(
      '/clientes?termo=${Uri.encodeQueryComponent(query)}',
    );
    return items
        .map(
          (item) => _OrderSearchOption(
            code: '${item['id']}',
            label:
                '${item['nome']}${(item['fantasia'] as String? ?? '').isEmpty ? '' : ' — ${item['fantasia']}'}',
          ),
        )
        .toList(growable: false);
  }

  Future<List<_OrderSearchOption>> products() async {
    final items = await _get('/produtos');
    return items
        .map(
          (item) => _OrderSearchOption(
            code: '${item['id']}',
            label: '${item['descricao']}',
            unit: '${item['unidade']}',
            unitPrice: item['preco_unitario'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ClientRecord>> clientRecords(String query) async {
    final items = await _get(
      '/clientes?termo=${Uri.encodeQueryComponent(query)}',
    );
    return items
        .map(
          (item) => ClientRecord(
            code: '${item['id']}',
            name: '${item['nome'] ?? ''}',
            fantasyName: '${item['fantasia'] ?? ''}',
          ),
        )
        .toList(growable: false);
  }

  Future<List<_OrderSearchOption>> paymentMethods() async {
    final items = await _get('/formas-pagamento');
    return items
        .map(
          (item) => _OrderSearchOption(
            code: '${item['id']}',
            label: '${item['descricao']}',
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _get(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$_malhaApiBase/catalogo$path'),
      );
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await utf8.decodeStream(response);
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode == 401)
        throw _CatalogException(
          'Sessão expirada. Entre novamente.',
          sessionExpired: true,
        );
      if (response.statusCode != 200)
        throw _CatalogException(
          decoded['erro'] as String? ?? 'Falha ao carregar dados.',
        );
      return List<Map<String, dynamic>>.from(
        decoded['itens'] as List? ?? const [],
      );
    } on SocketException {
      throw const _CatalogException('Não foi possível conectar à API.');
    } on TimeoutException {
      throw const _CatalogException('A API demorou para responder.');
    } finally {
      client.close();
    }
  }
}

class _DemoOrderCatalog {
  static const clients = [
    _OrderSearchOption(code: '1001', label: 'Têxtil Aurora Ltda.'),
    _OrderSearchOption(code: '1002', label: 'Confecções Horizonte'),
    _OrderSearchOption(code: '1003', label: 'Malharia São Jorge'),
    _OrderSearchOption(code: '1004', label: 'Ateliê Bela Trama'),
  ];

  static const products = [
    _OrderSearchOption(
      code: '2001',
      label: 'Malha algodão penteado — Branco',
      unit: 'kg',
      unitPrice: '24.90',
    ),
    _OrderSearchOption(
      code: '2002',
      label: 'Malha viscolycra — Preto',
      unit: 'UN',
      unitPrice: '29.50',
    ),
    _OrderSearchOption(
      code: '2003',
      label: 'Malha ribana canelada — Mescla',
      unit: 'kg',
      unitPrice: '27.80',
    ),
    _OrderSearchOption(
      code: '2004',
      label: 'Malha dry fit — Azul marinho',
      unit: 'kg',
      unitPrice: '31.20',
    ),
  ];

  // Ponto de troca futuro: cada busca será atendida por API autorizada.
  static Future<List<_OrderSearchOption>> searchClients(String query) =>
      _filter(clients, query);

  static Future<List<_OrderSearchOption>> _filter(
    List<_OrderSearchOption> source,
    String query,
  ) async {
    final normalized = query.trim().toLowerCase();
    return source
        .where(
          (option) =>
              option.code.contains(normalized) ||
              option.label.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }
}

enum _OrderTab { order, items }

class _OrderLine {
  const _OrderLine({
    required this.id,
    required this.product,
    required this.quantity,
  });

  final String id;
  final _OrderSearchOption product;
  final double quantity;

  _OrderLine copyWith({double? quantity}) =>
      _OrderLine(id: id, product: product, quantity: quantity ?? this.quantity);
}

/// Calcula em escala inteira para não introduzir arredondamento binário em
/// valores comerciais. `null` significa preço ausente ou inválido; ele nunca
/// deve ser convertido silenciosamente para R$ 0,00.
BigInt? _itemTotalCents(_OrderLine line) {
  final price = line.product.unitPrice;
  if (price == null || price.trim().isEmpty) return null;
  final normalized = price.replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = BigInt.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = (parts.length > 1 ? parts[1] : '')
      .padRight(4, '0')
      .substring(0, 4);
  final fractionValue = BigInt.tryParse(fraction);
  if (fractionValue == null) return null;
  final priceScale = whole * BigInt.from(10000) + fractionValue;
  final quantityScale = BigInt.from((line.quantity * 1000).round());
  return (quantityScale * priceScale + BigInt.from(50000)) ~/
      BigInt.from(100000);
}

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({
    super.key,
    required this.accessToken,
    required this.companyId,
    required this.sellerId,
    this.draftId,
    this.initialClientId,
    this.initialClientName,
    this.useInMemoryCatalog = false,
    this.draftStore,
  });
  final String accessToken;
  final int companyId;
  final int sellerId;
  final String? draftId;
  final String? initialClientId;
  final String? initialClientName;
  // Exclusivo para testes de interface; o fluxo real continua usando a API.
  final bool useInMemoryCatalog;
  final LocalDraftStore? draftStore;
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  _OrderSearchOption? _selectedClient;
  final _notesController = TextEditingController();
  final _deliveryDaysController = TextEditingController();
  _OrderTab _tab = _OrderTab.order;
  int _nextLineId = 1;
  final List<_OrderLine> _lines = [];
  late final _CatalogApi _catalog = _CatalogApi(widget.accessToken);
  List<_OrderSearchOption> _products = const [];
  List<_OrderSearchOption> _paymentMethods = const [];
  _OrderSearchOption? _selectedPaymentMethod;
  bool _catalogLoading = true;
  String? _catalogError;
  late final LocalDraftStore _draftStore =
      widget.draftStore ?? SqliteLocalDraftStore();
  String _localDraftId = newLocalDraftId();
  DateTime _draftCreatedAt = DateTime.now();
  bool _savingDraft = false;
  bool _addingLine = false;
  bool _hasUnsavedChanges = false;
  bool? _isManagerial;
  bool _clientValidationError = false;
  bool _paymentMethodValidationError = false;
  bool _deliveryDaysValidationError = false;
  bool _managerialValidationError = false;
  OverlayEntry? _addSuccessOverlay;
  Timer? _addSuccessTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialClientId != null && widget.initialClientName != null) {
      _selectedClient = _OrderSearchOption(
        code: widget.initialClientId!,
        label: widget.initialClientName!,
      );
    }
    _loadCatalog();
    if (widget.draftId != null) _restoreLocalDraft(widget.draftId!);
  }

  Future<void> _restoreLocalDraft(String localId) async {
    try {
      final draft = await _draftStore.loadById(
        localId: localId,
        companyId: widget.companyId,
        sellerId: widget.sellerId,
      );
      if (draft == null || !mounted) return;
      setState(() {
        _localDraftId = draft.localId;
        _draftCreatedAt = draft.createdAt;
        _selectedClient = draft.clientId == null || draft.clientName == null
            ? null
            : _OrderSearchOption(
                code: draft.clientId!,
                label: draft.clientName!,
              );
        _selectedPaymentMethod =
            draft.paymentMethodId == null || draft.paymentMethodName == null
            ? null
            : _OrderSearchOption(
                code: draft.paymentMethodId!,
                label: draft.paymentMethodName!,
              );
        _notesController.text = draft.notes ?? '';
        _deliveryDaysController.text = draft.deliveryDays?.toString() ?? '';
        _isManagerial = draft.isManagerial;
        _lines
          ..clear()
          ..addAll(
            draft.lines.map(
              (line) => _OrderLine(
                id: 'line-${_nextLineId++}',
                product: _OrderSearchOption(
                  code: line.productId,
                  label: line.description,
                  unit: line.unit,
                  unitPrice: line.unitPrice,
                ),
                quantity: line.quantity,
              ),
            ),
          );
        _hasUnsavedChanges = false;
      });
    } catch (_) {
      // Falha de armazenamento não bloqueia o pedido em memória.
    }
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      if (widget.useInMemoryCatalog) {
        setState(() {
          _products = _DemoOrderCatalog.products
              .take(2)
              .toList(growable: false);
          _paymentMethods = const [
            _OrderSearchOption(code: 'teste', label: 'Pagamento para teste'),
          ];
          _catalogLoading = false;
        });
        return;
      }
      final results = await Future.wait<List<_OrderSearchOption>>([
        _catalog.products(),
        _catalog.paymentMethods(),
      ]);
      if (mounted)
        setState(() {
          _products = results[0];
          _paymentMethods = results[1];
          _catalogLoading = false;
        });
    } on _CatalogException catch (error) {
      if (mounted)
        setState(() {
          _catalogError = error.message;
          _catalogLoading = false;
        });
    }
  }

  /*
  Widget _obsoletePrototype(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.ink,
      title: const Text(
        'Novo Pedido',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _SectionTitle('DADOS DO PEDIDO'),
        const SizedBox(height: 12),
        _SearchPicker(
          label: 'Cliente',
          hint: 'Nome, nome fantasia ou código',
          lookup: _DemoOrderCatalog.searchClients,
          selected: _selectedClient,
          onSelected: (client) => setState(() => _selectedClient = client),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle('PRODUTOS'),
            TextButton.icon(
              onPressed: () => setState(() => _items++),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var index = 0; index < _items; index++)
          _ProductCard(key: ValueKey(index), index: index + 1),
        const SizedBox(height: 12),
        const _SectionTitle('CONDIÇÕES COMERCIAIS'),
        const SizedBox(height: 12),
        const _SelectField(label: 'Prazo', value: '15 dias'),
        const SizedBox(height: 12),
        const _SelectField(
          label: 'Forma de pagamento',
          value: 'Boleto bancário',
        ),
        const SizedBox(height: 12),
        const _SelectField(
          label: 'Indicação comercial',
          value: 'Com nota fiscal',
        ),
        const SizedBox(height: 12),
        const _SelectField(label: 'Data de entrega', value: '10/11/2026'),
        const SizedBox(height: 12),
        const _TextArea(
          label: 'Observações',
          hint: 'Registre aqui qualquer negociação comercial.',
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido demonstrativo salvo apenas nesta tela.'),
            ),
          ),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar pedido demonstrativo'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.yellow,
            foregroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 18),
      ],
    ),
  );

  */
  @override
  void dispose() {
    _addSuccessTimer?.cancel();
    _addSuccessOverlay?.remove();
    _notesController.dispose();
    _deliveryDaysController.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value
            .toStringAsFixed(3)
            .replaceAll('.', ',')
            .replaceFirst(RegExp(r',?0+$'), '');

  Future<void> _openQuantityEntry(_OrderSearchOption product) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _QuantityEntryPage(
          product: product,
          formatMoney: _formatMoney,
          onAdd: (quantity) => _addOrUpdateLine(product, quantity),
        ),
      ),
    );
    if (!mounted || added != true) return;
    _showAddSuccessConfirmation();
  }

  Future<bool> _addOrUpdateLine(
    _OrderSearchOption product,
    double quantity,
  ) async {
    if (_addingLine) return false;
    if (_itemTotalCents(
          _OrderLine(id: 'validation', product: product, quantity: quantity),
        ) ==
        null) {
      return false;
    }
    setState(() => _addingLine = true);
    setState(() {
      final sameProductIndex = _lines.indexWhere(
        (line) => line.product.code == product.code,
      );
      if (sameProductIndex >= 0) {
        final line = _lines[sameProductIndex];
        _lines[sameProductIndex] = line.copyWith(
          quantity: line.quantity + quantity,
        );
      } else {
        _lines.add(
          _OrderLine(
            id: 'line-${_nextLineId++}',
            product: product,
            quantity: quantity,
          ),
        );
      }
      _hasUnsavedChanges = true;
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) setState(() => _addingLine = false);
    return mounted;
  }

  void _showAddSuccessConfirmation() {
    _addSuccessTimer?.cancel();
    _addSuccessOverlay?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    _addSuccessOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x99000000),
          ),
          Center(
            child: Semantics(
              liveRegion: true,
              label: 'Item adicionado ao carrinho!',
              child: Dialog(
                key: const Key('cart-add-success-confirmation'),
                insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                backgroundColor: AppColors.lightYellow,
                child: const _SuccessConfirmationContent(
                  message: 'Item adicionado ao carrinho!',
                  iconBackgroundColor: Color(0xFFDDF3DF),
                  iconColor: Color(0xFF247A35),
                  messageSize: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_addSuccessOverlay!);
    _addSuccessTimer = Timer(const Duration(seconds: 2), () {
      _addSuccessOverlay?.remove();
      _addSuccessOverlay = null;
    });
  }

  void _updateLineQuantity(_OrderLine line, double quantity) => setState(() {
    final index = _lines.indexWhere((current) => current.id == line.id);
    if (index >= 0) {
      _lines[index] = line.copyWith(quantity: quantity);
      _hasUnsavedChanges = true;
    }
  });

  void _removeLine(_OrderLine line) => setState(() {
    _lines.removeWhere((current) => current.id == line.id);
    _hasUnsavedChanges = true;
  });

  int? get _deliveryDays =>
      int.tryParse(_deliveryDaysController.text.trim());

  bool _validateOrderDetails() {
    String? message;
    final hasClient = _selectedClient != null;
    final hasPaymentMethod = _selectedPaymentMethod != null;
    final deliveryDays = _deliveryDays;
    final hasValidDeliveryDays = deliveryDays != null && deliveryDays >= 0;
    final hasManagerialChoice = _isManagerial != null;

    setState(() {
      _clientValidationError = !hasClient;
      _paymentMethodValidationError = !hasPaymentMethod;
      _deliveryDaysValidationError = !hasValidDeliveryDays;
      _managerialValidationError = !hasManagerialChoice;
    });

    if (!hasClient) {
      message = 'Selecione um cliente.';
    } else if (!hasPaymentMethod) {
      message = 'Selecione a forma de pagamento.';
    } else if (!hasValidDeliveryDays) {
      message = 'Informe um prazo de entrega válido.';
    } else if (!hasManagerialChoice) {
      message = 'Informe se o pedido é gerencial.';
    }

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    return true;
  }

  Future<void> _saveLocalDraft() async {
    if (_savingDraft) return;
    if (!_validateOrderDetails()) return;
    if (_lines.isEmpty) return;
    final deliveryDays = _deliveryDays!;
    if (_lines.any((line) => _itemTotalCents(line) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Há itens sem preço unitário disponível. Atualize o catálogo antes de salvar.',
          ),
        ),
      );
      return;
    }
    setState(() => _savingDraft = true);
    try {
      final saved = await _draftStore.save(
        LocalOrderDraft(
          localId: _localDraftId,
          companyId: widget.companyId,
          sellerId: widget.sellerId,
          status: 'RASCUNHO_LOCAL',
          createdAt: _draftCreatedAt,
          updatedAt: DateTime.now(),
          clientId: _selectedClient?.code,
          clientName: _selectedClient?.label,
          paymentMethodId: _selectedPaymentMethod?.code,
          paymentMethodName: _selectedPaymentMethod?.label,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          deliveryDays: deliveryDays,
          deliveryDate: _draftCreatedAt.add(Duration(days: deliveryDays)),
          isManagerial: _isManagerial,
          lines: _lines
              .map(
                (line) => LocalDraftLine(
                  productId: line.product.code,
                  description: line.product.label,
                  unit: line.product.unit,
                  quantity: line.quantity,
                  unitPrice: line.product.unitPrice,
                ),
              )
              .toList(growable: false),
        ),
      );
      if (!mounted) return;
      setState(() {
        _localDraftId = saved.localId;
        _draftCreatedAt = saved.createdAt;
        _hasUnsavedChanges = false;
      });
      await _showSaveConfirmationAndReturnHome();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao salvar o pedido local. Tente novamente.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        /* Falhas após desmontagem não podem usar o context. */
        /*
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o rascunho local.')),
        );
        */
      }
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _showSaveConfirmationAndReturnHome() async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: const _SuccessConfirmationContent(
            message: 'Pedido salvo com sucesso!',
            detail: 'Pedido armazenado neste aparelho.',
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    navigator.pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _openCart() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _OrderCartPage(
        lines: _lines,
        formatQuantity: _formatQuantity,
        formatMoney: _formatMoney,
        onQuantityChanged: _updateLineQuantity,
        onRemove: _removeLine,
        onSaveDraft: _saveLocalDraft,
        savingDraft: _savingDraft,
      ),
    ),
  );

  void _selectOrderTab(_OrderTab tab) {
    if (tab == _OrderTab.items && !_validateOrderDetails()) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_hasUnsavedChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmDiscardChanges();
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.ink,
        title: const Text(
          'Novo Pedido',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          _CartIconButton(itemCount: _lines.length, onTap: _openCart),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: _OrderTabs(
            selected: _tab,
            onSelected: _selectOrderTab,
          ),
        ),
      ),
      body: _tab == _OrderTab.order ? _buildOrderTab() : _buildItemsTab(),
    ),
  );

  Future<void> _confirmDiscardChanges() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text(
          'Deseja sair e descartar as alterações ainda não salvas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop();
    }
  }

  Widget _buildItemsTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const _SectionTitle('SELECIONE A MALHA'),
      const SizedBox(height: 12),
      if (_catalogLoading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_catalogError != null)
        _CatalogError(message: _catalogError!, onRetry: _loadCatalog)
      else if (_products.isEmpty)
        const _EmptyOrderLines(message: 'Nenhum produto habilitado para touch.')
      else
        _ProductChoiceGrid(
          products: _products,
          onSelected: _openQuantityEntry,
          formatMoney: _formatMoney,
        ),
      const SizedBox(height: 18),
    ],
  );

  Widget _buildOrderTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _SearchPicker(
        label: 'Cliente',
        hint: '',
        hasError: _clientValidationError,
        lookup: _catalog.clients,
        selected: _selectedClient,
        onSelected: (client) => setState(() {
          _selectedClient = client;
          _clientValidationError = false;
          _hasUnsavedChanges = true;
        }),
      ),
      const SizedBox(height: 18),
      if (_catalogLoading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_catalogError != null)
        _CatalogError(message: _catalogError!, onRetry: _loadCatalog)
      else
        DropdownButtonFormField<_OrderSearchOption>(
          value: _selectedPaymentMethod,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Forma de pagamento',
            errorText: _paymentMethodValidationError
                ? 'Selecione a forma de pagamento.'
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDDE1E5)),
            ),
          ),
          items: _paymentMethods
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (item) => setState(() {
            _selectedPaymentMethod = item;
            _paymentMethodValidationError = false;
            _hasUnsavedChanges = true;
          }),
        ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _deliveryDaysController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {
                _deliveryDaysValidationError = _deliveryDays == null ||
                    _deliveryDays! < 0;
                _hasUnsavedChanges = true;
              }),
              decoration: InputDecoration(
                labelText: 'Prazo de entrega',
                errorText: _deliveryDaysValidationError
                    ? 'Informe um prazo válido.'
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE1E5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Previsão de entrega',
                filled: true,
                fillColor: const Color(0xFFF0F2F4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE1E5)),
                ),
              ),
              child: Text(
                _deliveryDateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _managerialValidationError
                ? Theme.of(context).colorScheme.error
                : const Color(0xFFDDE1E5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo do pedido',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gerencial?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const SizedBox(
                      width: double.infinity,
                      child: Text('Sim', textAlign: TextAlign.center),
                    ),
                    selected: _isManagerial == true,
                    selectedColor: AppColors.yellow,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFDDE1E5)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onSelected: (_) => setState(() {
                      _isManagerial = true;
                      _managerialValidationError = false;
                      _hasUnsavedChanges = true;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const SizedBox(
                      width: double.infinity,
                      child: Text('Não', textAlign: TextAlign.center),
                    ),
                    selected: _isManagerial == false,
                    selectedColor: AppColors.yellow,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFDDE1E5)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    onSelected: (_) => setState(() {
                      _isManagerial = false;
                      _managerialValidationError = false;
                      _hasUnsavedChanges = true;
                    }),
                  ),
                ),
              ],
            ),
            if (_managerialValidationError) ...[
              const SizedBox(height: 8),
              Text(
                'Informe se o pedido é gerencial.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      _TextArea(
        controller: _notesController,
        onChanged: (_) => setState(() => _hasUnsavedChanges = true),
        label: 'Observações',
        hint: 'Registre aqui qualquer negociação comercial.',
      ),
      const SizedBox(height: 18),
    ],
  );

  String get _deliveryDateLabel {
    final days = int.tryParse(_deliveryDaysController.text.trim());
    if (days == null || days < 0) return 'Informe o prazo';
    final date = _draftCreatedAt.add(Duration(days: days));
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatMoney(BigInt cents) {
    final major = cents ~/ BigInt.from(100);
    final minor = (cents % BigInt.from(100)).toString().padLeft(2, '0');
    return 'R\$ ${major.toString()},$minor';
  }
}

final _primaryButtonStyle = FilledButton.styleFrom(
  backgroundColor: AppColors.yellow,
  foregroundColor: AppColors.ink,
  disabledBackgroundColor: const Color(0xFFFFE18A),
  disabledForegroundColor: const Color(0xFF5F5636),
  minimumSize: const Size.fromHeight(54),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);

class _SuccessConfirmationContent extends StatelessWidget {
  const _SuccessConfirmationContent({
    required this.message,
    this.detail,
    this.iconBackgroundColor = AppColors.lightYellow,
    this.iconColor = AppColors.ink,
    this.messageSize = 18,
  });

  final String message;
  final String? detail;
  final Color iconBackgroundColor;
  final Color iconColor;
  final double messageSize;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 31,
          backgroundColor: iconBackgroundColor,
          foregroundColor: iconColor,
          child: const Icon(Icons.check_rounded, size: 38),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: messageSize,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 7),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

class _OrderTabs extends StatelessWidget {
  const _OrderTabs({required this.selected, required this.onSelected});

  final _OrderTab selected;
  final ValueChanged<_OrderTab> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.yellow,
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
    child: Row(
      children: [
        Expanded(
          child: _OrderTabButton(
            label: 'Pedido',
            icon: Icons.assignment_outlined,
            selected: selected == _OrderTab.order,
            onTap: () => onSelected(_OrderTab.order),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OrderTabButton(
            label: 'Itens',
            icon: Icons.inventory_2_outlined,
            selected: selected == _OrderTab.items,
            onTap: () => onSelected(_OrderTab.items),
          ),
        ),
      ],
    ),
  );
}

class _OrderTabButton extends StatelessWidget {
  const _OrderTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.white : const Color(0x33FFFFFF),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.ink : const Color(0x55808080),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w800,
      color: AppColors.muted,
    ),
  );
}

class _SelectField extends StatelessWidget {
  const _SelectField({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDDE1E5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ],
    ),
  );
}

class _SearchPicker extends StatefulWidget {
  const _SearchPicker({
    required this.label,
    required this.hint,
    required this.lookup,
    required this.onSelected,
    this.selected,
    this.hasError = false,
  });

  final String label;
  final String hint;
  final _OrderSearchLookup lookup;
  final ValueChanged<_OrderSearchOption> onSelected;
  final _OrderSearchOption? selected;
  final bool hasError;

  @override
  State<_SearchPicker> createState() => _SearchPickerState();
}

class _SearchPickerState extends State<_SearchPicker> {
  late final TextEditingController _controller;
  List<_OrderSearchOption> _results = const [];
  bool _showNoResults = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.selected?.label ?? '');
  }

  @override
  void didUpdateWidget(covariant _SearchPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected &&
        widget.selected != null &&
        _controller.text != widget.selected!.label) {
      _controller.text = widget.selected!.label;
    }
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _results = const [];
          _showNoResults = false;
        });
      }
      return;
    }

    List<_OrderSearchOption> results;
    try {
      results = await widget.lookup(query);
    } on _CatalogException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted || _controller.text.trim() != query) return;
    setState(() {
      _results = results;
      _showNoResults = results.isEmpty;
    });
  }

  void _select(_OrderSearchOption option) {
    _controller.text = option.label;
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _showNoResults = false;
    });
    widget.onSelected(option);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: widget.hasError
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFDDE1E5),
      ),
    ),
    child: Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: _search,
          textInputAction: TextInputAction.search,
          scrollPadding: const EdgeInsets.only(bottom: 180),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search, color: AppColors.ink),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar pesquisa',
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final option = _results[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.search, size: 20),
                  title: Text(
                    option.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Código ${option.code}'),
                  onTap: () => _select(option),
                );
              },
            ),
          ),
        if (_showNoResults)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Nenhum resultado encontrado.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
      ],
    ),
  );
}

class _ProductChoiceGrid extends StatelessWidget {
  const _ProductChoiceGrid({
    required this.products,
    required this.onSelected,
    required this.formatMoney,
  });

  final List<_OrderSearchOption> products;
  final ValueChanged<_OrderSearchOption> onSelected;
  final String Function(BigInt) formatMoney;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: constraints.maxWidth < 400 ? 0.95 : 1.20,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final unitPrice = _itemTotalCents(
          _OrderLine(id: 'product-price', product: product, quantity: 1),
        );
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => onSelected(product),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE3E5E8),
                  width: 1.35,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1C2633).withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.92),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    product.label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              unitPrice == null
                                  ? 'Preço indisponível'
                                  : formatMoney(unitPrice),
                              style: TextStyle(
                                color: unitPrice == null
                                    ? Colors.red.shade700
                                    : AppColors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

double? _validQuantityFor(_OrderSearchOption product, String value) {
  final text = value.trim().replaceAll(',', '.');
  final pattern = '^[0-9]+(?:\\.[0-9]{1,${product.quantityPrecision}})?\$';
  if (!RegExp(pattern).hasMatch(text)) return null;
  final quantity = double.tryParse(text);
  return quantity != null && quantity > 0 ? quantity : null;
}

class _QuantityEntryPage extends StatefulWidget {
  const _QuantityEntryPage({
    required this.product,
    required this.formatMoney,
    required this.onAdd,
  });

  final _OrderSearchOption product;
  final String Function(BigInt) formatMoney;
  final Future<bool> Function(double quantity) onAdd;

  @override
  State<_QuantityEntryPage> createState() => _QuantityEntryPageState();
}

class _QuantityEntryPageState extends State<_QuantityEntryPage> {
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_adding) return;
    final quantity = _validQuantityFor(widget.product, _controller.text);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade maior que zero.')),
      );
      return;
    }
    final unitPrice = _itemTotalCents(
      _OrderLine(id: 'quantity-entry-price', product: widget.product, quantity: 1),
    );
    if (unitPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preço unitário indisponível. Atualize o catálogo antes de adicionar o item.',
          ),
        ),
      );
      return;
    }
    setState(() => _adding = true);
    final added = await widget.onAdd(quantity);
    if (!mounted) return;
    if (added) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final unitPrice = _itemTotalCents(
      _OrderLine(id: 'quantity-entry-price', product: widget.product, quantity: 1),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.ink,
        title: const Text(
          'Quantidade',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.product.label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.unit,
              style: const TextStyle(color: AppColors.muted, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              unitPrice == null
                  ? 'Preço indisponível'
                  : widget.formatMoney(unitPrice),
              style: TextStyle(
                color: unitPrice == null ? Colors.red.shade700 : AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 34),
            const Text(
              'Quantidade',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('quantity-entry-input'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF6F7F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: unitPrice == null || _adding ? null : _submit,
              icon: _adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart_outlined),
              label: Text(_adding ? 'Adicionando...' : 'Adicionar ao carrinho'),
              style: _primaryButtonStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrderLines extends StatelessWidget {
  const _EmptyOrderLines({
    this.message =
        'Selecione uma malha, informe a quantidade e adicione o item.',
  });
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.muted)),
  );
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}

class _CartIconButton extends StatelessWidget {
  const _CartIconButton({required this.itemCount, required this.onTap});

  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$itemCount itens no carrinho',
    button: true,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Abrir carrinho',
          onPressed: onTap,
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
        if (itemCount > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              key: const Key('cart-item-count'),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$itemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _OrderCartPage extends StatefulWidget {
  const _OrderCartPage({
    required this.lines,
    required this.formatQuantity,
    required this.formatMoney,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onSaveDraft,
    required this.savingDraft,
  });

  final List<_OrderLine> lines;
  final String Function(double) formatQuantity;
  final String Function(BigInt) formatMoney;
  final void Function(_OrderLine line, double quantity) onQuantityChanged;
  final ValueChanged<_OrderLine> onRemove;
  final Future<void> Function() onSaveDraft;
  final bool savingDraft;

  @override
  State<_OrderCartPage> createState() => _OrderCartPageState();
}

class _OrderCartPageState extends State<_OrderCartPage> {
  Future<void> _editQuantity(_OrderLine line) async {
    final controller = TextEditingController(
      text: widget.formatQuantity(line.quantity),
    );
    String? error;
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar quantidade'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantidade (${line.product.unit})',
              errorText: error,
              hintText: line.product.quantityPrecision == 0
                  ? 'Informe um número inteiro'
                  : 'Até ${line.product.quantityPrecision} casas decimais',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim().replaceAll(',', '.');
                final validFormat = RegExp(
                  '^[0-9]+(?:\\.[0-9]{1,${line.product.quantityPrecision}})?\$',
                ).hasMatch(text);
                final value = double.tryParse(text);
                if (!validFormat || value == null || value <= 0) {
                  setDialogState(() {
                    error = 'Informe uma quantidade positiva válida.';
                  });
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    // A rota do diálogo ainda pode estar em sua animação de saída neste ponto.
    // Adiar o descarte evita que o TextField em transição leia um controller já descartado.
    Future<void>.delayed(const Duration(milliseconds: 250), controller.dispose);
    if (quantity == null || !mounted) return;
    widget.onQuantityChanged(line, quantity);
    setState(() {});
  }

  void _remove(_OrderLine line) {
    widget.onRemove(line);
    setState(() {});
  }

  Future<void> _confirmRemove(_OrderLine line) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text(
          'Deseja realmente excluir o item ${line.product.label} do carrinho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir item'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _remove(line);
  }

  Map<String, double> get _totalsByUnit {
    final totals = <String, double>{};
    for (final line in widget.lines) {
      final unit = line.product.unit.trim().toUpperCase();
      totals.update(
        unit,
        (total) => total + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: AppColors.yellow,
      foregroundColor: AppColors.ink,
      title: const Text(
        'Carrinho',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: widget.lines.isEmpty
        ? const _EmptyCart()
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final line = widget.lines[index];
              return Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                shadowColor: const Color(0x18000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E5E9)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.lightYellow,
                        foregroundColor: AppColors.ink,
                        child: Icon(Icons.inventory_2_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: widget.formatQuantity(line.quantity),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' ${line.product.unit.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Builder(
                              builder: (_) {
                                final unitPrice = _itemTotalCents(
                                  _OrderLine(
                                    id: line.id,
                                    product: line.product,
                                    quantity: 1,
                                  ),
                                );
                                final subtotal = _itemTotalCents(line);
                                if (unitPrice == null || subtotal == null) {
                                  return Text(
                                    'Preço indisponível. Atualize o catálogo antes de salvar.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  );
                                }
                                return Text(
                                  'Preço unitário: ${widget.formatMoney(unitPrice)}\nSubtotal: ${widget.formatMoney(subtotal)}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'Editar quantidade',
                            onPressed: () => _editQuantity(line),
                            color: AppColors.ink,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Excluir item',
                            onPressed: () => _confirmRemove(line),
                            color: Colors.red.shade700,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    bottomNavigationBar: widget.lines.isEmpty
        ? null
        : _CartTotalsFooter(
            totals: _totalsByUnit,
            lineCount: widget.lines.length,
            formatQuantity: widget.formatQuantity,
            totalMoney: _totalMoney,
            hasUnavailablePrices: widget.lines.any(
              (line) => _itemTotalCents(line) == null,
            ),
            formatMoney: widget.formatMoney,
            onSaveDraft: widget.onSaveDraft,
            savingDraft: widget.savingDraft,
          ),
  );

  BigInt? get _totalMoney {
    var total = BigInt.zero;
    for (final line in widget.lines) {
      final subtotal = _itemTotalCents(line);
      if (subtotal == null) return null;
      total += subtotal;
    }
    return total;
  }
}

class _CartTotalsFooter extends StatelessWidget {
  const _CartTotalsFooter({
    required this.totals,
    required this.lineCount,
    required this.formatQuantity,
    required this.totalMoney,
    required this.hasUnavailablePrices,
    required this.formatMoney,
    required this.onSaveDraft,
    required this.savingDraft,
  });

  final Map<String, double> totals;
  final int lineCount;
  final String Function(double) formatQuantity;
  final BigInt? totalMoney;
  final bool hasUnavailablePrices;
  final String Function(BigInt) formatMoney;
  final Future<void> Function() onSaveDraft;
  final bool savingDraft;

  @override
  Widget build(BuildContext context) {
    final singleUnit = totals.length == 1 ? totals.keys.single : null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E4E8))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$lineCount ${lineCount == 1 ? 'produto diferente' : 'produtos diferentes'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              for (final entry in totals.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _labelFor(entry.key, singleUnit) +
                        formatQuantity(entry.value),
                    key: Key('cart-total-${entry.key}'),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                totalMoney == null
                    ? 'Total financeiro indisponível'
                    : 'Total financeiro: ${formatMoney(totalMoney!)}',
                style: TextStyle(
                  color: totalMoney == null
                      ? Colors.red.shade700
                      : AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (hasUnavailablePrices) ...[
                const SizedBox(height: 4),
                Text(
                  'Existem itens sem preço válido; o pedido não pode ser salvo.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: savingDraft || hasUnavailablePrices
                    ? null
                    : onSaveDraft,
                icon: savingDraft
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(savingDraft ? 'Salvando...' : 'Salvar pedido'),
                style: _primaryButtonStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelFor(String unit, String? singleUnit) {
    if (singleUnit == 'UN') return 'Total de peças: ';
    if (singleUnit != null) return 'Total em $unit: ';
    return 'Total $unit: ';
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.shopping_cart_outlined, size: 56, color: AppColors.muted),
          SizedBox(height: 14),
          Text(
            'Seu carrinho está vazio.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Volte à aba Itens para adicionar malhas ao pedido.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _FinishSummary extends StatelessWidget {
  const _FinishSummary({
    required this.client,
    required this.lines,
    required this.totals,
    required this.demoValue,
    required this.formatQuantity,
    required this.formatPrice,
  });

  final _OrderSearchOption client;
  final List<_OrderLine> lines;
  final Map<String, double> totals;
  final double demoValue;
  final String Function(double) formatQuantity;
  final String Function(double) formatPrice;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('RESUMO DO PEDIDO'),
        const SizedBox(height: 8),
        Text(
          client.label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const Divider(height: 24),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${line.product.label}\n${formatQuantity(line.quantity)} ${line.product.unit}',
            ),
          ),
        const Divider(height: 24),
        for (final entry in totals.entries)
          Text(
            'Total em ${entry.key}: ${formatQuantity(entry.value)} ${entry.key}',
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightYellow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Valor demonstrativo: ${formatPrice(demoValue)}\nNão representa preço comercial.',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

/* Legacy product-card prototype retained in source history only.
class _ProductCard extends StatefulWidget {
  const _ProductCard({super.key, required this.index});
  final int index;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  _OrderSearchOption? _selectedProduct;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Produto ${widget.index}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _SearchPicker(
          label: 'Tipo de malha/produto',
          hint: 'Descrição ou código do produto',
          lookup: _DemoOrderCatalog.searchProducts,
          selected: _selectedProduct,
          onSelected: (product) => setState(() => _selectedProduct = product),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: _CompactField(label: 'Quantidade', value: '100 kg'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompactField(
                label: 'Valor unitário',
                value: _formatPrice(_selectedProduct?.unitPrice ?? 24.90),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _formatPrice(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _CompactField extends StatelessWidget {
  const _CompactField({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

*/
class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.label,
    required this.hint,
    this.controller,
    this.onChanged,
  });
  final String label;
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    maxLines: 4,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE1E5)),
      ),
    ),
  );
}
