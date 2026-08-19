import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'estado.dart';

/* ================================================================== *
 *  SESSÃO — guarda o token e os dados do garçom logado
 *  Fica salvo no celular, então o app não pede login toda hora.
 * ================================================================== */
class Sessao {
  static String? token;
  static String? refreshToken;
  static Map<String, dynamic> garcom = {};

  static const _kToken = 'token';
  static const _kRefresh = 'refreshToken';
  static const _kGarcom = 'garcom';

  static bool get logado => token != null && token!.isNotEmpty;

  /// nome do garçom (ou vazio)
  static String get nome => (garcom['name'] ?? '').toString();

  static String get email => (garcom['email'] ?? '').toString();

  /// bloco "establishment" que vem no login e no /me
  static Map<String, dynamic> get loja {
    final e = garcom['establishment'];
    return e is Map ? e.cast<String, dynamic>() : const {};
  }

  /// nome do restaurante
  static String get empresa => (loja['name'] ?? '').toString();

  /// taxa de serviço em % (ex.: 10.0)
  static double get taxaServico =>
      double.tryParse('${loja['serviceChargePercent'] ?? 0}'.replaceAll(',', '.')) ?? 0;

  static bool get aceitaDinheiro => loja['acceptsCash'] == true;
  static bool get aceitaCartao => loja['acceptsCard'] == true;
  static bool get aceitaPix => loja['acceptsPix'] == true;

  /// o garçom é o dono do estabelecimento?
  static bool get dono => garcom['role']?.toString() == 'owner';

  /// lista de permissões vinda do servidor
  static List<String> get permissoes {
    final p = garcom['permissions'];
    if (p is List) return p.map((e) => '$e').toList();
    return const [];
  }

  /// dono pode tudo; colaborador precisa da permissão
  static bool pode(String permissao) => dono || permissoes.contains(permissao);

  /// iniciais para o avatar: "João Silva" -> "JS"
  static String get iniciais {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  /* ---------------- gravar e ler do celular ---------------- */

  static Future<void> carregar() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    refreshToken = p.getString(_kRefresh);
    final d = p.getString(_kGarcom);
    if (d != null && d.isNotEmpty) {
      try {
        garcom = (jsonDecode(d) as Map).cast<String, dynamic>();
      } catch (_) {
        garcom = {};
      }
    }
    avisarPerfilMudou();
  }

  static Future<void> salvar({
    required String token,
    String? refreshToken,
    Map<String, dynamic>? garcom,
  }) async {
    Sessao.token = token;
    if (refreshToken != null) Sessao.refreshToken = refreshToken;
    if (garcom != null) Sessao.garcom = garcom;

    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (refreshToken != null) await p.setString(_kRefresh, refreshToken);
    if (garcom != null) await p.setString(_kGarcom, jsonEncode(garcom));
    avisarPerfilMudou();
  }

  static Future<void> atualizarToken({
    required String token,
    String? refreshToken,
  }) async {
    Sessao.token = token;
    if (refreshToken != null) Sessao.refreshToken = refreshToken;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (refreshToken != null) await p.setString(_kRefresh, refreshToken);
  }

  /// mistura os dados novos do /me com os que já existem
  static Future<void> atualizarGarcom(Map<String, dynamic> novo) async {
    garcom = {...garcom, ...novo};
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGarcom, jsonEncode(garcom));
    avisarPerfilMudou();
  }

  static Future<void> limpar() async {
    token = null;
    refreshToken = null;
    garcom = {};
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kRefresh);
    await p.remove(_kGarcom);
    avisarPerfilMudou();
  }
}
