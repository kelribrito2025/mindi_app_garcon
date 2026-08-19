import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'sessao.dart';
import 'estado.dart';

/* ================================================================== *
 *  CONEXÃO COM A API — App do Garçom
 *  Endereço do servidor. Sem barra no final.
 * ================================================================== */
const String kApiBase = 'https://dev.mindi.com.br';

/* ------------------------------------------------------------------ *
 *  SENHA DO AMBIENTE DE TESTES (basic auth do servidor)
 *  Deixe vazio quando o servidor liberar as rotas /api/waiter/.
 * ------------------------------------------------------------------ */
const String kBasicUsuario = '';
const String kBasicSenha = '';

bool get apiConfigurada => kApiBase.trim().isNotEmpty;
bool get temBasic => kBasicUsuario.isNotEmpty;

String get _basic =>
    'Basic ${base64Encode(utf8.encode('$kBasicUsuario:$kBasicSenha'))}';

/// Erro vindo da API, já com mensagem pronta para mostrar na tela
class ApiErro implements Exception {
  final int status;
  final String mensagem;

  /// código curto que o servidor manda
  /// ('TABLE_ALREADY_OPEN', 'PERMISSION_DENIED', ...)
  final String codigo;
  ApiErro(this.status, this.mensagem, {this.codigo = ''});
  @override
  String toString() => mensagem;

  /// alguém mexeu na mesa/comanda antes da gente
  bool get conflito => status == 409;
}

/// Cria uma chave única para o servidor não executar a mesma ação
/// duas vezes quando a internet falha e o app reenvia.
String novaChaveUnica() {
  const letras = '0123456789abcdef';
  final r = Random.secure();
  final b = StringBuffer();
  for (var i = 0; i < 32; i++) {
    b.write(letras[r.nextInt(16)]);
    if (i == 7 || i == 11 || i == 15 || i == 19) b.write('-');
  }
  return b.toString();
}

class Api {
  static const _timeout = Duration(seconds: 20);
  static const _raiz = '/api/waiter';

  static Uri _url(String caminho, [Map<String, String>? query]) {
    final u = Uri.parse('$kApiBase$caminho');
    return query == null ? u : u.replace(queryParameters: query);
  }

  static Map<String, String> _cabecalhos({
    bool comToken = true,
    String? chaveUnica,
  }) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (comToken && Sessao.token != null) {
      h['Authorization'] = 'Bearer ${Sessao.token}';
      if (temBasic) h['X-Basic-Auth'] = _basic;
    } else if (temBasic) {
      h['Authorization'] = _basic;
    }

    if (chaveUnica != null) h['Idempotency-Key'] = chaveUnica;
    return h;
  }

  /* ---------------- tratamento das respostas ---------------- */
  static dynamic _tratar(http.Response r) {
    if (r.statusCode == 204 || r.body.isEmpty) return null;

    dynamic corpo;
    try {
      corpo = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      corpo = null;
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return corpo;

    String? doServidor;
    String codigo = '';
    if (corpo is Map) {
      for (final chave in ['message', 'detail', 'msg', 'error']) {
        final v = corpo[chave];
        if (v is String && v.trim().isNotEmpty) {
          doServidor = v.trim();
          break;
        }
      }
      for (final chave in ['code', 'errorCode', 'error']) {
        final v = corpo[chave];
        if (v is String && v.trim().isNotEmpty) {
          codigo = v.trim().toUpperCase();
          break;
        }
      }
    }

    final msg = doServidor ?? _mensagemPadrao(r.statusCode);

    // Casos em que não adianta continuar logado
    final contaFora = r.statusCode == 403 &&
        (codigo == 'ACCOUNT_DISABLED' ||
            codigo == 'DELETED' ||
            codigo == 'DISABLED');
    final sessaoMorta = r.statusCode == 401 &&
        (codigo == 'SESSION_REVOKED' || codigo == 'UNAUTHORIZED');

    if ((contaFora || sessaoMorta) && Sessao.logado) {
      Sessao.limpar();
      sessaoEncerrada.value = msg;
    }

    throw ApiErro(r.statusCode, msg, codigo: codigo);
  }

  static String _mensagemPadrao(int s) {
    switch (s) {
      case 401:
        return 'E-mail ou senha incorretos.';
      case 403:
        return 'Você não tem permissão para isso.';
      case 404:
        return 'Não encontrado.';
      case 409:
        return 'Outra pessoa mexeu nessa mesa. Atualizando...';
      case 422:
        return 'Dados inválidos.';
      case 429:
        return 'Muitas tentativas. Espere um minuto e tente de novo.';
      default:
        return s >= 500
            ? 'O servidor está fora do ar. Tente de novo em instantes.'
            : 'Não foi possível completar a ação.';
    }
  }

  /* ---------------- chamada base ---------------- */
  static Future<dynamic> _enviar(
    String metodo,
    String caminho, {
    Object? corpo,
    Map<String, String>? query,
    bool comToken = true,
    String? chaveUnica,
    bool jaTentouRenovar = false,
  }) async {
    if (!apiConfigurada) {
      throw ApiErro(0, 'API não configurada.');
    }

    final url = _url(caminho, query);
    final cab = _cabecalhos(comToken: comToken, chaveUnica: chaveUnica);
    final body = corpo == null ? null : jsonEncode(corpo);

    late http.Response r;
    try {
      switch (metodo) {
        case 'GET':
          r = await http.get(url, headers: cab).timeout(_timeout);
          break;
        case 'POST':
          r = await http.post(url, headers: cab, body: body).timeout(_timeout);
          break;
        case 'PUT':
          r = await http.put(url, headers: cab, body: body).timeout(_timeout);
          break;
        default:
          throw ApiErro(0, 'Método não suportado.');
      }
    } catch (e) {
      if (e is ApiErro) rethrow;
      throw ApiErro(0, 'Sem conexão com o servidor. Verifique a internet.');
    }

    // token expirou: tenta renovar uma vez e repete a chamada
    if (r.statusCode == 401 &&
        comToken &&
        !jaTentouRenovar &&
        Sessao.refreshToken != null) {
      final renovou = await renovarToken();
      if (renovou) {
        return _enviar(metodo, caminho,
            corpo: corpo,
            query: query,
            comToken: comToken,
            chaveUnica: chaveUnica,
            jaTentouRenovar: true);
      }
      if (Sessao.logado) {
        Sessao.limpar();
        sessaoEncerrada.value =
            'Sua sessão expirou. Entre de novo para continuar.';
      }
    }

    return _tratar(r);
  }

  static List<Map<String, dynamic>> _lista(dynamic r, String chave) {
    if (r is List) return r.map((e) => (e as Map).cast<String, dynamic>()).toList();
    if (r is Map && r[chave] is List) {
      return (r[chave] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  static Map<String, dynamic> _mapa(dynamic r, [String? chave]) {
    if (r is Map && chave != null && r[chave] is Map) {
      return (r[chave] as Map).cast<String, dynamic>();
    }
    if (r is Map) return r.cast<String, dynamic>();
    return {};
  }

  /* ================================================================ *
   *  1. SESSÃO
   * ================================================================ */

  /// POST /api/waiter/auth/login
  static Future<void> login(String email, String senha) async {
    final r = await _enviar('POST', '$_raiz/auth/login',
        corpo: {'email': email.trim(), 'password': senha}, comToken: false);

    await Sessao.salvar(
      token: r['token'] as String,
      refreshToken: r['refreshToken'] as String?,
      garcom: (r['waiter'] ?? r['user'] ?? r['collaborator']) is Map
          ? ((r['waiter'] ?? r['user'] ?? r['collaborator']) as Map)
              .cast<String, dynamic>()
          : null,
    );
  }

  /// POST /api/waiter/auth/refresh
  static Future<bool> renovarToken() async {
    if (Sessao.refreshToken == null) return false;
    try {
      final r = await http
          .post(_url('$_raiz/auth/refresh'),
              headers: _cabecalhos(comToken: false),
              body: jsonEncode({'refreshToken': Sessao.refreshToken}))
          .timeout(_timeout);
      if (r.statusCode != 200) return false;
      final c = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      await Sessao.atualizarToken(
        token: c['token'] as String,
        refreshToken: c['refreshToken'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/waiter/auth/logout
  static Future<void> sair() async {
    try {
      await _enviar('POST', '$_raiz/auth/logout',
          corpo: {'refreshToken': Sessao.refreshToken});
    } catch (_) {
      // mesmo se falhar, o app limpa a sessão local
    }
  }

  /// GET /api/waiter/me
  static Future<Map<String, dynamic>> meusDados() async =>
      _mapa(await _enviar('GET', '$_raiz/me'), 'waiter');

  /// PUT /api/waiter/me/push-token
  static Future<void> registrarPushToken(String token) => _enviar(
      'PUT', '$_raiz/me/push-token',
      corpo: {'pushToken': token, 'platform': 'android'});

  /* ================================================================ *
   *  2. MESAS
   * ================================================================ */

  /// GET /api/waiter/spaces — Salão, Varanda, etc.
  static Future<List<Map<String, dynamic>>> espacos() async =>
      _lista(await _enviar('GET', '$_raiz/spaces'), 'spaces');

  /// GET /api/waiter/tables — o mapa de mesas inteiro
  static Future<List<Map<String, dynamic>>> mesas() async =>
      _lista(await _enviar('GET', '$_raiz/tables'), 'tables');

  /// GET /api/waiter/tables/:id — detalhe com a comanda
  static Future<Map<String, dynamic>> mesa(int id) async =>
      _mapa(await _enviar('GET', '$_raiz/tables/$id'), 'table');

  /// POST /api/waiter/tables/:id/open
  static Future<Map<String, dynamic>> abrirMesa(int id,
      {required int pessoas, String? identificacao}) async {
    final r = await _enviar('POST', '$_raiz/tables/$id/open',
        corpo: {
          'people': pessoas,
          if (identificacao != null && identificacao.isNotEmpty)
            'label': identificacao,
        },
        chaveUnica: novaChaveUnica());
    return _mapa(r, 'table');
  }

  /// POST /api/waiter/tables/:id/close
  static Future<Map<String, dynamic>> fecharMesa(
    int id, {
    required String formaPagamento,
    required String valorPago,
    String? troco,
  }) async {
    final r = await _enviar('POST', '$_raiz/tables/$id/close',
        corpo: {
          'paymentMethod': formaPagamento,
          'amountPaid': valorPago,
          if (troco != null) 'change': troco,
        },
        chaveUnica: novaChaveUnica());
    return _mapa(r, 'table');
  }

  /// POST /api/waiter/tables/:id/request-bill
  static Future<void> pedirConta(int id) =>
      _enviar('POST', '$_raiz/tables/$id/request-bill');

  /* ================================================================ *
   *  3. CARDÁPIO
   * ================================================================ */

  /// GET /api/waiter/categories
  static Future<List<Map<String, dynamic>>> categorias() async =>
      _lista(await _enviar('GET', '$_raiz/categories'), 'categories');

  /// GET /api/waiter/products
  static Future<List<Map<String, dynamic>>> produtos() async =>
      _lista(await _enviar('GET', '$_raiz/products'), 'products');

  /// GET /api/waiter/complements — todos de uma vez, o app guarda
  static Future<List<Map<String, dynamic>>> complementos() async =>
      _lista(await _enviar('GET', '$_raiz/complements'), 'complements');

  /* ================================================================ *
   *  4. COMANDA
   * ================================================================ */

  /// POST /api/waiter/tabs/:id/add-items
  static Future<Map<String, dynamic>> adicionarItens(
    int comandaId,
    List<Map<String, dynamic>> itens,
  ) async {
    final r = await _enviar('POST', '$_raiz/tabs/$comandaId/add-items',
        corpo: {'items': itens}, chaveUnica: novaChaveUnica());
    return _mapa(r, 'tab');
  }

  /* ----------------------------------------------------------------
     ATENÇÃO: estes dois endpoints ainda NÃO estão na documentação da
     API do garçom (o plano do backend não previu "editar meus dados"
     nem "trocar minha senha"). Os caminhos abaixo são o palpite mais
     provável, seguindo o mesmo padrão do app do entregador.
     Precisa confirmar com o backend antes de valer.
     ---------------------------------------------------------------- */

  /// PUT /api/waiter/me — muda o nome que aparece no app
  static Future<void> editarPerfil({required String nome}) async {
    final r = await _enviar('PUT', '$_raiz/me', corpo: {'name': nome});
    final m = _mapa(r, 'waiter');
    if (m.isNotEmpty) await Sessao.atualizarGarcom(m);
  }

  /// PUT /api/waiter/me/password — troca a senha
  static Future<String> trocarSenha(String atual, String nova) async {
    final r = await _enviar('PUT', '$_raiz/me/password',
        corpo: {'currentPassword': atual, 'newPassword': nova});
    final m = _mapa(r);
    final msg = m['message'];
    return msg is String && msg.isNotEmpty ? msg : 'Senha alterada com sucesso.';
  }
}
