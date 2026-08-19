import 'package:flutter/material.dart';
import 'icones.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'estado.dart';
import 'sessao.dart';

/* ================================================================== *
 *  TEMA — claro e escuro
 *  Cada cor sabe se o app está no modo claro ou escuro.
 *  Trocar o modo é só mexer em `modoEscuro` (estado.dart).
 * ================================================================== */
class T {
  static bool get escuro => modoEscuro.value;
  static Color _c(int claro, int escuroHex) =>
      Color(modoEscuro.value ? escuroHex : claro);

  // ---- superfícies ----
  static Color get bg => _c(0xFFF4F5F7, 0xFF09090B);
  static Color get card => _c(0xFFFFFFFF, 0xFF18181B);
  static Color get campo => _c(0xFFF7F8FA, 0xFF27272A);
  static Color get campo2 => _c(0xFFF1F2F5, 0xFF27272A);
  static Color get borda => _c(0xFFE7E9EE, 0xFF3F3F46);
  static Color get line => _c(0xFFF0F1F4, 0xFF27272A);

  // ---- textos ----
  static Color get ink => _c(0xFF1A1D26, 0xFFFAFAFA);
  static Color get inkMedio => _c(0xFF4A4F5C, 0xFFD4D4D8);
  static Color get rotulo => _c(0xFF6B7180, 0xFFA1A1AA);
  static Color get inkSoft => _c(0xFF8A8F9C, 0xFFA1A1AA);
  static Color get fraco => _c(0xFFB9BCC6, 0xFF52525B);
  static Color get tabOff => _c(0xFFB9BCC6, 0xFF71717A);

  // ---- vermelho da marca ----
  static Color get red => _c(0xFFEC5B57, 0xFFEF4444);
  static Color get redDark => _c(0xFFD8434B, 0xFFDC2626);
  static Color get redSuave => _c(0xFFFDECEC, 0xFF3A1D1F);
  static Color get redBorda => _c(0xFFFAD9D9, 0xFF522427);

  // ---- verde (concluído / online) ----
  static Color get green => _c(0xFF16A34A, 0xFF22C55E);
  static Color get greenEscuro => _c(0xFF15803D, 0xFF16A34A);
  static Color get greenSuave => _c(0xFFE8F7EE, 0xFF14301F);
  static Color get greenBorda => _c(0xFFCDEBD8, 0xFF1F5133);
  static Color get greenLight => _c(0xFF4ADE80, 0xFF4ADE80);

  // ---- amarelo (a receber / aviso) ----
  static Color get amarelo => _c(0xFF9A6B0F, 0xFFEAB308);
  static Color get amareloSuave => _c(0xFFFFF6D6, 0xFF3A2E0B);
  static Color get amareloBorda => _c(0xFFF3E2A6, 0xFF5C4A12);

  // ---- outras ----
  static Color get roxo => _c(0xFF7B4FE0, 0xFFA78BFA);
  static Color get roxoSuave => _c(0xFFF3EEFD, 0xFF251E3D);
  static Color get azul => _c(0xFF3B7DED, 0xFF60A5FA);
  static Color get azulSuave => _c(0xFFEAF1FE, 0xFF15243D);
  static Color get dark1 => _c(0xFF252A38, 0xFF27272A);
  static Color get dark2 => _c(0xFF191D28, 0xFF18181B);
  static Color get star => _c(0xFFF5A623, 0xFFF5A623);
}

/// deixa a barra de navegação do Android transparente e com os
/// ícones na cor certa para o tema atual
void aplicarBarrasDoSistema() {
  // o app desenha ate a borda da tela
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    // a barra do Android fica da mesma cor do fundo do app, em vez de
    // preta (no tema escuro) ou cinza (no claro)
    systemNavigationBarColor: T.bg,
    systemNavigationBarDividerColor: T.bg,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness:
        T.escuro ? Brightness.light : Brightness.dark,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
}

const double kBarH = 64;
const double kBarR = 22;
const double kNotchR = 30;
const double kBubble = 56;
const double kSide = 16;

/// Degradê vermelho usado no header e nos botões
LinearGradient get kGradRed => LinearGradient(
      colors: [T.red, T.redDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

/// Sombra suave dos cartões brancos
List<BoxShadow> sombraCard({double opacidade = .06, double blur = 10, double y = 2}) => [
      BoxShadow(
        color: (T.escuro ? Colors.black : const Color(0xFF1E233C))
            .withOpacity(T.escuro ? opacidade * 2.4 : opacidade),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];

/* ---------- cabeçalho vermelho reaproveitado pelas telas ---------- */
class HeaderVermelho extends StatelessWidget {
  final Widget child;
  final double alturaExtra;
  const HeaderVermelho({super.key, required this.child, this.alturaExtra = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: kGradRed),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, alturaExtra),
          child: child,
        ),
      ),
    );
  }
}

/* ---------- linha "Bem-vindo, Kelri" no topo vermelho ---------- */
class BarraBoasVindas extends StatelessWidget {
  /// tocar no avatar/nome leva para a aba Perfil
  final bool clicavel;
  const BarraBoasVindas({super.key, this.clicavel = true});

  @override
  Widget build(BuildContext context) {
    // se redesenha sozinho quando o garçom troca o nome no perfil
    return ListenableBuilder(
      listenable: versaoDoPerfil,
      builder: (context, _) => _conteudo(context),
    );
  }

  Widget _conteudo(BuildContext context) {
    final nome = Sessao.nome.isNotEmpty ? Sessao.nome : 'Garçom';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: clicavel ? () => abaSelecionada.value = 2 : null,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.18),
                    border: Border.all(
                        color: Colors.white.withOpacity(.45), width: 1.5),
                  ),
                  child: Text(Sessao.iniciais,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bem-vindo,',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(.78))),
                      Text(nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ---------- abre link fora do app (Maps, telefone, WhatsApp) ---------- */
Future<void> abrirLink(BuildContext context, String? url) async {
  if (url == null || url.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Link indisponível'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.dark2,
    ));
    return;
  }
  try {
    final ok = await launchUrl(Uri.parse(url.trim()),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nenhum aplicativo encontrado para abrir isso'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.dark2,
      ));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Não foi possível abrir'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.dark2,
      ));
    }
  }
}

/// abre o WhatsApp do suporte
Future<void> abrirSuporte(BuildContext context) => abrirLink(context,
    'https://api.whatsapp.com/send/?phone=5534998807793&text=Ol%C3%A1%2C+queria+tirar+uma+duvida%2C+pode+me+ajudar%3F&type=phone_number&app_absent=0');

/* ================================================================== *
 *  TELA INTERNA — usada pelas telas abertas a partir do Perfil
 *  (faixa vermelha em cima + painel branco com botão voltar e título)
 * ================================================================== */
class TelaInterna extends StatelessWidget {
  final String titulo;
  final Widget child;
  final bool rolavel;
  const TelaInterna(
      {super.key,
      required this.titulo,
      required this.child,
      this.rolavel = true});

  @override
  Widget build(BuildContext context) {
    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.campo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.borda),
                ),
                child: Icon(Ico.voltar,
                    size: 26, color: T.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.4)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    );

    // Com o teclado aberto sobra pouca tela. Nessa hora o header vermelho
    // sai de cena para o formulário caber inteiro.
    final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: T.bg,
      // o Scaffold já encolhe o corpo na altura do teclado,
      // por isso NÃO somamos viewInsets no padding (senão conta duas vezes)
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          if (tecladoAberto)
            SizedBox(height: MediaQuery.of(context).padding.top)
          else
            const HeaderVermelho(
              child: BarraBoasVindas(clicavel: false),
            ),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, tecladoAberto ? 0 : -44),
              child: Container(
                decoration: BoxDecoration(
                  color: T.bg,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(tecladoAberto ? 0 : 28)),
                ),
                // viewPadding (e não padding) porque o Scaffold já
                // "consome" o padding — e aí a barra do Android acabava
                // ficando por cima do botão de salvar.
                padding: EdgeInsets.fromLTRB(
                    kSide,
                    tecladoAberto ? 10 : 22,
                    kSide,
                    26 + MediaQuery.viewPaddingOf(context).bottom),
                child: rolavel
                    ? SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: conteudo,
                      )
                    : conteudo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- spinner de carregando (mesmo visual da aba Início) ---------- */
class Espera extends StatelessWidget {
  final String texto;
  final double tamanho;
  const Espera({super.key, this.texto = 'Carregando...', this.tamanho = 15});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: tamanho,
          height: tamanho,
          child: CircularProgressIndicator(
              strokeWidth: 2.6, color: T.redDark),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: tamanho,
                  fontWeight: FontWeight.w800,
                  color: T.ink,
                  letterSpacing: -.3)),
        ),
      ],
    );
  }
}

/* ---------- interruptor no mesmo estilo do header ---------- */
class ToggleMindi extends StatelessWidget {
  final bool ligado;
  final ValueChanged<bool>? aoMudar;

  /// cor da trilha quando está ligado
  final Color? corLigado;

  /// cor da trilha quando está desligado
  final Color? corDesligado;

  const ToggleMindi({
    super.key,
    required this.ligado,
    this.aoMudar,
    this.corLigado,
    this.corDesligado,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoMudar == null ? null : () => aoMudar!(!ligado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2.5),
        alignment: ligado ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: ligado
              ? (corLigado ?? const Color(0xFF2ECC71))
              : (corDesligado ?? T.fraco),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Container(
          width: 17,
          height: 17,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/* ---------- afunda um pouco quando o dedo toca ----------
   Serve para o entregador sentir que o toque pegou, mesmo
   de luva ou com o celular no suporte da moto.
--------------------------------------------------------- */
class AfundaAoTocar extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// quanto encolhe (1 = não encolhe). Cards usam menos que botões.
  final double escala;

  const AfundaAoTocar({
    super.key,
    required this.child,
    this.onTap,
    this.escala = .96,
  });

  @override
  State<AfundaAoTocar> createState() => _AfundaAoTocarState();
}

class _AfundaAoTocarState extends State<AfundaAoTocar> {
  bool _pressionado = false;

  void _muda(bool v) {
    if (_pressionado != v && mounted) setState(() => _pressionado = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _muda(true),
      onTapUp: (_) => _muda(false),
      onTapCancel: () => _muda(false),
      child: AnimatedScale(
        scale: _pressionado ? widget.escala : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/* ================================================================== *
 *  CAIXINHA DE MARCAR — o quadradinho de "Lembrar-me" e afins
 * ================================================================== */
class Caixinha extends StatelessWidget {
  final bool marcada;
  const Caixinha({super.key, required this.marcada});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: marcada ? T.redDark : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: marcada ? T.redDark : T.borda, width: 1.6),
      ),
      child: marcada
          ? const Icon(Ico.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
