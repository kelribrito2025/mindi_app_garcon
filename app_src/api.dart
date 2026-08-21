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
        (codigo == 'ACCOUNT_DISABLED' || codigo == 'PERMISSION_DENIED');
    final sessaoMorta = r.statusCode == 401 &&
        (codigo == 'SESSION_REVOKED' ||
            codigo == 'UNAUTHORIZED' ||
            codigo == 'INVALID_REFRESH_TOKEN');

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
        case 'DELETE':
          r = await http
              .delete(url, headers: cab, body: body)
              .timeout(_timeout);
          break;
        default:
          throw ApiErro(0, 'Método não suportado.');
      }
    } catch (e) {
      if (e is ApiErro) rethrow;
      throw ApiErro(0, 'Sem conexão com o servidor. Verifique a internet.');
    }

    // 401 pode ser duas coisas bem diferentes: o token expirou, ou o
    // próprio endpoint recusou (senha atual errada, por exemplo).
    // Só faz sentido renovar o token no primeiro caso.
    if (r.statusCode == 401 &&
        comToken &&
        !jaTentouRenovar &&
        _ehTokenExpirado(r) &&
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

  /// olha o código de erro do corpo para saber se o 401 é de sessão
  static bool _ehTokenExpirado(http.Response r) {
    try {
      final corpo = jsonDecode(utf8.decode(r.bodyBytes));
      if (corpo is Map) {
        final codigo =
            '${corpo['code'] ?? corpo['errorCode'] ?? corpo['error'] ?? ''}'
                .toUpperCase();
        if (codigo.isEmpty) return true;
        return codigo == 'UNAUTHORIZED' ||
            codigo == 'SESSION_REVOKED' ||
            codigo == 'TOKEN_EXPIRED' ||
            codigo == 'INVALID_TOKEN';
      }
    } catch (_) {}
    return true;
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
      token: (r['accessToken'] ?? r['token']) as String,
      refreshToken: r['refreshToken'] as String?,
      garcom: r['user'] is Map
          ? (r['user'] as Map).cast<String, dynamic>()
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
        token: (c['accessToken'] ?? c['token']) as String,
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
      _mapa(await _enviar('GET', '$_raiz/me'));

  /// PUT /api/waiter/me/push-token
  static Future<void> registrarPushToken(String token) =>
      _enviar('PUT', '$_raiz/me/push-token', corpo: {'token': token});

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
      _mapa(await _enviar('GET', '$_raiz/tables/$id'));

  /// POST /api/waiter/tables/:id/open
  static Future<Map<String, dynamic>> abrirMesa(int id,
      {required int pessoas}) async {
    final r = await _enviar('POST', '$_raiz/tables/$id/open',
        corpo: {'guests': pessoas}, chaveUnica: novaChaveUnica());
    return _mapa(r);
  }

  /// POST /api/waiter/tables/:id/close
  static Future<void> fecharMesa(
    int id, {
    required String formaPagamento,
    required double valorPago,
    double troco = 0,
  }) =>
      _enviar('POST', '$_raiz/tables/$id/close',
          corpo: {
            'paymentMethod': formaPagamento,
            'paidAmount': valorPago,
            'changeAmount': troco,
          },
          chaveUnica: novaChaveUnica());

  /// POST /api/waiter/tables/:id/request-bill
  static Future<void> pedirConta(int id) =>
      _enviar('POST', '$_raiz/tables/$id/request-bill');

  /// POST /api/waiter/tables/:id/transfer-items
  /// Move itens da mesa :id para outra mesa.
  /// Erros: SOURCE_TAB_CLOSED, SAME_TABLE, TABLE_NOT_FOUND.
  static Future<Map<String, dynamic>> transferirItens(
    int id, {
    required int mesaDestino,
    required List<int> itens,
    bool levarIdentificacao = false,
  }) async =>
      _mapa(await _enviar('POST', '$_raiz/tables/$id/transfer-items',
          corpo: {
            'targetTableId': mesaDestino,
            'itemIds': itens,
            'transferLabel': levarIdentificacao,
          },
          chaveUnica: novaChaveUnica()));

  /* ---------------- impressora ----------------
     ATENÇÃO: estes dois ainda NÃO existem no servidor. A tela já trata
     a ausência deles sem quebrar (404 = "não dá para conferir daqui"). */

  /// GET /api/waiter/printer/status
  static Future<Map<String, dynamic>> impressora() async =>
      _mapa(await _enviar('GET', '$_raiz/printer/status'));

  /// POST /api/waiter/printer/test — sai um cupom pequeno de teste
  static Future<void> testarImpressora() =>
      _enviar('POST', '$_raiz/printer/test', chaveUnica: novaChaveUnica());

  /* ---------------- pagamentos da comanda ----------------
     Fechar parcial = o cliente paga ALGUNS ITENS e vai embora; a mesa
     continua aberta com o resto.
     Pagamento avulso = abate um VALOR do saldo, sem escolher item.
     Erros: TAB_ALREADY_CLOSED, AMOUNT_EXCEEDS_BALANCE, NO_VALID_ITEMS. */

  /// POST /api/waiter/tables/:id/partial-close
  static Future<void> fecharParcial(
    int id, {
    required List<int> itens,
    required String formaPagamento,
  }) =>
      _enviar('POST', '$_raiz/tables/$id/partial-close',
          corpo: {'itemIds': itens, 'paymentMethod': formaPagamento},
          chaveUnica: novaChaveUnica());

  /// POST /api/waiter/tables/:id/loose-payment
  static Future<void> pagamentoAvulso(
    int id, {
    required double valor,
    required String formaPagamento,
    String observacao = '',
  }) =>
      _enviar('POST', '$_raiz/tables/$id/loose-payment',
          corpo: {
            'amount': valor,
            'paymentMethod': formaPagamento,
            if (observacao.trim().isNotEmpty) 'notes': observacao.trim(),
          },
          chaveUnica: novaChaveUnica());

  /// GET /api/waiter/tables/:id/payments
  static Future<List<Map<String, dynamic>>> pagamentosDaMesa(int id) async =>
      _lista(await _enviar('GET', '$_raiz/tables/$id/payments'), 'payments');

  /* ---------------- juntar e separar mesas ----------------
     A regra de quem vira a principal é do servidor (o PDV usa a de
     MENOR número). O app só manda as duas e recarrega o salão.
     Erros esperados: ALREADY_MERGED, TABLE_REQUESTING_BILL,
     TABLE_CLOSED, TABLE_NOT_MERGED.                                  */

  /// POST /api/waiter/tables/:id/merge
  static Future<Map<String, dynamic>> juntarMesas(
    int id, {
    required int mesaAlvo,
  }) async {
    final r = await _enviar('POST', '$_raiz/tables/$id/merge',
        corpo: {'targetTableId': mesaAlvo}, chaveUnica: novaChaveUnica());
    return _mapa(r);
  }

  /// POST /api/waiter/tables/:id/unmerge
  static Future<void> separarMesa(int id) =>
      _enviar('POST', '$_raiz/tables/$id/unmerge',
          chaveUnica: novaChaveUnica());

  /* ================================================================ *
   *  3. CARDÁPIO
   * ================================================================ */

  /// GET /api/waiter/categories
  static Future<List<Map<String, dynamic>>> categorias() async =>
      _lista(await _enviar('GET', '$_raiz/categories'), 'categories');

  /// GET /api/waiter/products
  static Future<List<Map<String, dynamic>>> produtos({int? categoriaId}) async =>
      _lista(
          await _enviar('GET', '$_raiz/products',
              query: categoriaId == null
                  ? null
                  : {'categoryId': '$categoriaId'}),
          'products');

  /// GET /api/waiter/complements — todos de uma vez, o app guarda
  static Future<List<Map<String, dynamic>>> complementos() async =>
      _lista(await _enviar('GET', '$_raiz/complements'), 'complements');

  /* ================================================================ *
   *  3.5 GANHOS DO GARÇOM (comissão da taxa de serviço)
   *
   *  ATENÇÃO: estes dois endpoints ainda NÃO existem no servidor.
   *  Estão escritos aqui no formato combinado com o backend; a tela
   *  já trata a falta deles sem quebrar. Quando subirem, funciona.
   * ================================================================ */

  /// GET /api/waiter/earnings?from=&to=
  static Future<Map<String, dynamic>> ganhos({
    required DateTime de,
    required DateTime ate,
  }) async =>
      _mapa(await _enviar('GET', '$_raiz/earnings', query: {
        'from': _inicioDoDia(de),
        'to': _fimDoDia(ate),
      }));

  /// GET /api/waiter/history?from=&to= — as comandas que ELE fechou
  static Future<List<Map<String, dynamic>>> minhasComandas({
    required DateTime de,
    required DateTime ate,
  }) async =>
      _lista(
          await _enviar('GET', '$_raiz/history', query: {
            'from': _inicioDoDia(de),
            'to': _fimDoDia(ate),
          }),
          'history');

  /* ---------------- datas ----------------
     O servidor guarda tudo em UTC. Aqui vai o instante exato do começo
     e do fim do dia NO HORÁRIO DO CELULAR, já convertido. Sem isso,
     mesa fechada às 23h cai no dia seguinte. */

  static String _inicioDoDia(DateTime d) =>
      DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

  static String _fimDoDia(DateTime d) => DateTime(d.year, d.month, d.day)
      .add(const Duration(days: 1))
      .subtract(const Duration(seconds: 1))
      .toUtc()
      .toIso8601String();

  /* ================================================================ *
   *  4. COMANDA
   * ================================================================ */

  /// POST /api/waiter/tabs/:id/add-items
  /// Devolve a resposta do servidor. O campo `autoPrinted` diz se a
  /// comanda já saiu na impressora sozinha.
  static Future<Map<String, dynamic>> adicionarItens(
    int comandaId,
    List<Map<String, dynamic>> itens,
  ) async =>
      _mapa(await _enviar('POST', '$_raiz/tabs/$comandaId/add-items',
          corpo: {'items': itens}, chaveUnica: novaChaveUnica()));

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
    final m = _mapa(r);
    // a resposta vem como {success: true, name: "..."} — só o nome
    // interessa para a sessão
    final novo = m['name'];
    await Sessao.atualizarGarcom(
        {'name': novo is String && novo.isNotEmpty ? novo : nome});
  }

  /// PUT /api/waiter/me/password — troca a senha
  static Future<String> trocarSenha(String atual, String nova) async {
    final r = await _enviar('PUT', '$_raiz/me/password',
        corpo: {'currentPassword': atual, 'newPassword': nova});
    final m = _mapa(r);
    final msg = m['message'];
    return msg is String && msg.isNotEmpty ? msg : 'Senha alterada com sucesso.';
  }

  /* ----------------------------------------------------------------
     ATENÇÃO: este endpoint ainda NÃO existe na documentação da API do
     garçom — nem na Fase 1, nem na Fase 2. O caminho abaixo é a
     proposta a ser confirmada com o backend.
     ---------------------------------------------------------------- */

  /// POST /api/waiter/spaces — cria um espaço já com N mesas dentro
  static Future<Map<String, dynamic>> criarEspacoComMesas({
    required String nome,
    required int mesas,
  }) async {
    final r = await _enviar('POST', '$_raiz/spaces',
        corpo: {'name': nome, 'tableCount': mesas},
        chaveUnica: novaChaveUnica());
    return _mapa(r, 'space');
  }

  /// DELETE /api/waiter/spaces/:id — apaga o espaço e as mesas dele
  /// (endpoint ainda a confirmar com o backend)
  static Future<void> apagarEspaco(int id) =>
      _enviar('DELETE', '$_raiz/spaces/$id');

  /// PUT /api/waiter/spaces/:id — muda o nome do espaço
  static Future<void> renomearEspaco(int id, String nome) =>
      _enviar('PUT', '$_raiz/spaces/$id', corpo: {'name': nome});

  /// GET /api/waiter/tables/deleted — mesas na lixeira
  static Future<List<Map<String, dynamic>>> mesasExcluidas() async =>
      _lista(await _enviar('GET', '$_raiz/tables/deleted'), 'tables');

  /// POST /api/waiter/tables/:id/restore — traz a mesa de volta.
  /// Devolve {success, number, renumbered}
  static Future<Map<String, dynamic>> restaurarMesa(int id) async =>
      _mapa(await _enviar('POST', '$_raiz/tables/$id/restore'));

  /* ----------------------------------------------------------------
     Identificação, impressão e histórico.
     ---------------------------------------------------------------- */

  /// PUT /api/waiter/tables/:id/label — identificação do cliente na mesa
  static Future<void> identificarMesa(int id, String identificacao) =>
      _enviar('PUT', '$_raiz/tables/$id/label',
          corpo: {'label': identificacao});

  /// POST /api/waiter/tabs/:id/print
  /// Sem parâmetro sai só o que foi lançado agora.
  /// Com [tudo] sai a comanda inteira (papel rasgou, cozinha perdeu).
  /// Devolve true quando o papel saiu; false quando o servidor pulou
  /// a impressão (skipped) — aí o garçom precisa usar o Reimprimir.
  static Future<bool> imprimirComanda(int comandaId, {bool tudo = false}) async {
    final r = await _enviar('POST', '$_raiz/tabs/$comandaId/print',
        corpo: tudo ? {'all': true} : null, chaveUnica: novaChaveUnica());
    if (r is Map && r['skipped'] == true) return false;
    return true;
  }

  /// GET /api/waiter/tables/:id/history — pedidos já feitos nesta mesa
  static Future<List<Map<String, dynamic>>> historicoDaMesa(int id) async =>
      _lista(await _enviar('GET', '$_raiz/tables/$id/history'), 'history');
}
