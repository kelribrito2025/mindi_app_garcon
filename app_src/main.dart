import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tema.dart';
import 'sessao.dart';
import 'estado.dart';
import 'notificacoes.dart';
import 'tela_login.dart';
import 'app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // lê o tema (claro/escuro) que o garçom escolheu
  await carregarTema();

  // lê se ele prefere ver as mesas em grade ou em lista
  await carregarModoDeVer();

  // lê o login salvo no celular antes de abrir a primeira tela
  await Sessao.carregar();

  // liga o Firebase (notificações)
  await Notificacoes.ligarFirebase();
  if (Sessao.logado) {
    // não usa await: o app abre na hora e o token vai em segundo plano
    Notificacoes.registrar();
  }

  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // o app inteiro se redesenha quando o tema muda
    return ValueListenableBuilder<bool>(
      valueListenable: modoEscuro,
      builder: (context, escuro, _) {
        // deixa a barra do Android combinando com o tema
        aplicarBarrasDoSistema();

        final brilho = escuro ? Brightness.dark : Brightness.light;

        return MaterialApp(
          // a chave muda junto com o tema: isso obriga TODAS as telas a
          // serem desenhadas de novo, senão algumas ficam com a cor velha
          key: ValueKey(escuro),
          title: 'Mindi - Garçom',
          debugShowCheckedModeBanner: false,

          // deixa datas e textos do sistema em português
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: ThemeData(
            useMaterial3: true,
            brightness: brilho,
            // mesma fonte do painel web
            fontFamily: GoogleFonts.inter().fontFamily,
            scaffoldBackgroundColor: T.bg,
            canvasColor: T.bg,
            colorScheme: ColorScheme.fromSeed(
              seedColor: T.red,
              brightness: brilho,
            ),
          ),

          // já logado vai direto pro app; senão, tela de login
          home: Sessao.logado ? const AppShell() : const TelaLogin(),
        );
      },
    );
  }
}
