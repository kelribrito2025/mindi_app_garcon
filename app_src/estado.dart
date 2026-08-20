import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* ================================================================== *
 *  ESTADO GLOBAL — informações que várias telas precisam ver
 *  (quando o valor muda, quem estiver "ouvindo" se atualiza sozinho)
 * ================================================================== */

/// Tema escuro ligado? (fica salvo no celular)
final modoEscuro = ValueNotifier<bool>(false);

const _kTema = 'modoEscuro';

Future<void> carregarTema() async {
  final p = await SharedPreferences.getInstance();
  modoEscuro.value = p.getBool(_kTema) ?? false;
}

Future<void> salvarTema(bool escuro) async {
  modoEscuro.value = escuro;
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kTema, escuro);
}

/* ---------- Como as mesas aparecem: grade ou lista ---------- */

/// false = grade (padrão), true = lista
final modoLista = ValueNotifier<bool>(false);

const _kModoLista = 'mesasEmLista';

Future<void> carregarModoDeVer() async {
  final p = await SharedPreferences.getInstance();
  modoLista.value = p.getBool(_kModoLista) ?? false;
}

Future<void> salvarModoDeVer(bool lista) async {
  modoLista.value = lista;
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kModoLista, lista);
}

/// Na grade: 3 mesas por linha (padrão) ou 5, arrastando para o lado.
/// Os cards continuam do mesmo tamanho; só cabe mais na linha.
final cincoPorLinha = ValueNotifier<bool>(false);

const _kCincoPorLinha = 'mesasCincoPorLinha';

Future<void> carregarLarguraDaGrade() async {
  final p = await SharedPreferences.getInstance();
  cincoPorLinha.value = p.getBool(_kCincoPorLinha) ?? false;
}

Future<void> salvarLarguraDaGrade(bool cinco) async {
  cincoPorLinha.value = cinco;
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kCincoPorLinha, cinco);
}

/* ---------- "Lembrar-me" da tela de login ---------- */
const _kLembrar = 'loginLembrar';
const _kLoginEmail = 'loginEmail';
const _kLoginSenha = 'loginSenha';

Future<Map<String, String>> lerLoginSalvo() async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool(_kLembrar) != true) return {};
  return {
    'email': p.getString(_kLoginEmail) ?? '',
    'senha': p.getString(_kLoginSenha) ?? '',
  };
}

Future<void> salvarLoginSalvo({
  required bool lembrar,
  required String email,
  required String senha,
}) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kLembrar, lembrar);
  if (lembrar) {
    await p.setString(_kLoginEmail, email);
    await p.setString(_kLoginSenha, senha);
  } else {
    await p.remove(_kLoginEmail);
    await p.remove(_kLoginSenha);
  }
}

/// Quando o servidor diz que a conta foi removida, desativada ou perdeu
/// a permissão, guarda a mensagem aqui. O app volta para o login.
final sessaoEncerrada = ValueNotifier<String?>(null);

/// Aba aberta na barra de baixo (0 Mesas, 1 Cozinha, 2 Perfil)
final abaSelecionada = ValueNotifier<int>(0);

/// Sobe +1 sempre que os dados do garçom mudam (nome, foto...).
/// Quem mostra o nome na tela "ouve" isso e se redesenha na hora.
final versaoDoPerfil = ValueNotifier<int>(0);
void avisarPerfilMudou() => versaoDoPerfil.value = versaoDoPerfil.value + 1;

/// Id da mesa que veio de uma notificação tocada pelo garçom.
/// A tela Mesas "ouve" isso e abre a mesa sozinha.
final mesaDaNotificacao = ValueNotifier<int?>(null);

/// Sobe +1 toda vez que chega uma notificação (pedido pronto, conta
/// solicitada). Serve para as telas buscarem na hora, sem esperar os 15s.
final avisoDeNovidade = ValueNotifier<int>(0);
