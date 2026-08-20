import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'sessao.dart';
import 'estado.dart';
import 'atualizacao.dart';
import 'notificacoes.dart';
import 'cardapio.dart';
import 'tela_editar_perfil.dart';
import 'tela_login.dart';

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  bool _carregando = false;
  bool _saindo = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    // recarrega sempre que o garçom volta para a aba Perfil
    abaSelecionada.addListener(_aoTrocarAba);
    // redesenha assim que o nome muda em "Meus dados"
    versaoDoPerfil.addListener(_aoMudarPerfil);
  }

  @override
  void dispose() {
    abaSelecionada.removeListener(_aoTrocarAba);
    versaoDoPerfil.removeListener(_aoMudarPerfil);
    super.dispose();
  }

  void _aoMudarPerfil() {
    if (mounted) setState(() {});
  }

  void _aoTrocarAba() {
    if (abaSelecionada.value == 3 && mounted) _carregar();
  }

  /// busca os dados do garçom na API
  Future<void> _carregar() async {
    if (!apiConfigurada) return;
    setState(() => _carregando = true);
    try {
      final me = await Api.meusDados();
      if (me.isNotEmpty) await Sessao.atualizarGarcom(me);
    } catch (_) {
      // sem internet: segue com o que já está salvo no celular
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  DateTime? get _entrouEm {
    final c = Sessao.garcom['createdAt'];
    return c is String ? DateTime.tryParse(c) : null;
  }

  /// "8 meses", "1 ano", "12 dias"
  String get _tempoNaEquipe {
    final d = _entrouEm;
    if (d == null) return '—';
    final dias = DateTime.now().difference(d).inDays;
    if (dias < 31) return '$dias dia${dias == 1 ? '' : 's'}';
    final meses = (dias / 30.44).floor();
    if (meses < 12) return '$meses mês${meses == 1 ? '' : 'es'}';
    final anos = (meses / 12).floor();
    return '$anos ano${anos == 1 ? '' : 's'}';
  }

  String get _cargo => Sessao.dono ? 'Dono' : 'Garçom';

  Future<void> _sair() async {
    setState(() => _saindo = true);
    try {
      await Api.sair();
    } catch (_) {
      // mesmo sem internet o app encerra a sessão local
    }
    Cardapio.limpar();
    await Notificacoes.esquecer();
    await Sessao.limpar();
    if (!mounted) return;
    abaSelecionada.value = 0;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaLogin()),
      (rota) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = Sessao.nome.isNotEmpty ? Sessao.nome : 'Garçom';
    final empresa = Sessao.empresa.isNotEmpty ? Sessao.empresa : 'Restaurante';

    return RefreshIndicator(
      color: T.redDark,
      onRefresh: _carregar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
            bottom: 130 + MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            const HeaderVermelho(
              child: BarraBoasVindas(clicavel: false),
            ),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSide),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- CARTÃO DE IDENTIDADE ----------
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: T.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: sombraCard(opacidade: .09, blur: 20, y: 6),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: kGradRed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: T.redDark.withOpacity(.3),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(Sessao.iniciais,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .5)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(nome,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: T.ink,
                                                  letterSpacing: -.4)),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Ico.selo,
                                            size: 16, color: T.green),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(empresa,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            color: T.inkSoft)),
                                  ],
                                ),
                              ),
                              if (_carregando)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: T.tabOff),
                                ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Divider(color: T.line, height: 1),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              _Stat(valor: _cargo, label: 'no salão'),
                              _Stat(
                                  valor: _tempoNaEquipe,
                                  label: 'na equipe',
                                  divisor: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ---------- CONTA ----------
                    const _Titulo('CONTA'),
                    _Grupo(itens: [
                      _Item(
                        icone: Ico.perfil,
                        cor: T.azul,
                        fundo: T.azulSuave,
                        titulo: 'Meus dados',
                        sub: 'Seu nome no app',
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const TelaEditarPerfil()));
                          if (mounted) setState(() {});
                        },
                      ),
                    ]),

                    // ---------- APARÊNCIA ----------
                    const _Titulo('APARÊNCIA'),
                    _Grupo(itens: [
                      _Item(
                        icone: modoEscuro.value ? Ico.lua : Ico.sol,
                        cor: T.amarelo,
                        fundo: T.amareloSuave,
                        titulo: 'Tema escuro',
                        sub: modoEscuro.value ? 'Ligado' : 'Desligado',
                        ligado: modoEscuro.value,
                        aoAlternar: (v) async {
                          await salvarTema(v);
                          if (mounted) setState(() {});
                        },
                      ),
                    ]),

                    // ---------- SUPORTE ----------
                    const _Titulo('SUPORTE'),
                    _Grupo(itens: [
                      _Item(
                        icone: Ico.ajuda,
                        cor: T.roxo,
                        fundo: T.roxoSuave,
                        titulo: 'Ajuda e suporte',
                        sub: 'Fale com a gente pelo WhatsApp',
                        onTap: () => abrirSuporte(context),
                      ),
                      _Item(
                        icone: Ico.sair,
                        cor: T.redDark,
                        fundo: T.redSuave,
                        titulo: 'Sair da conta',
                        perigo: true,
                        carregando: _saindo,
                        onTap: _sair,
                      ),
                    ]),

                    const SizedBox(height: 14),
                    // mostra também qual correção pelo ar já entrou,
                    // para saber se o celular pegou o último conserto
                    ValueListenableBuilder<int?>(
                      valueListenable: correcaoAtual,
                      builder: (_, correcao, __) => Text(
                          correcao == null
                              ? 'Versão $kVersaoDoApp'
                              : 'Versão $kVersaoDoApp · correção $correcao',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11.5, color: T.inkSoft)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- pedaços da tela ---------------- */
class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 7),
        child: Text(texto,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: T.inkSoft)),
      );
}

class _Grupo extends StatelessWidget {
  final List<Widget> itens;
  const _Grupo({required this.itens});

  @override
  Widget build(BuildContext context) {
    final filhos = <Widget>[];
    for (var i = 0; i < itens.length; i++) {
      filhos.add(itens[i]);
      if (i < itens.length - 1) {
        filhos.add(Divider(color: T.campo2, height: 1));
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: sombraCard(),
      ),
      child: Column(children: filhos),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icone;
  final Color cor, fundo;
  final String titulo;
  final String? sub;
  final bool perigo;
  final VoidCallback? onTap;
  /// quando vier preenchido, a linha mostra um interruptor no lugar da seta
  final bool? ligado;
  final ValueChanged<bool>? aoAlternar;

  /// troca o ícone da esquerda por um spinner enquanto a ação roda
  final bool carregando;
  const _Item({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.titulo,
    this.sub,
    this.perigo = false,
    this.onTap,
    this.ligado,
    this.aoAlternar,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ligado != null ? () => aoAlternar?.call(!ligado!) : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: carregando
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: cor),
                    )
                  : Icon(icone, size: 17, color: cor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.2,
                          color: perigo ? T.redDark : T.ink)),
                  if (sub != null) ...[
                    const SizedBox(height: 1),
                    Text(sub!,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: T.inkSoft)),
                  ],
                ],
              ),
            ),
            if (ligado != null)
              ToggleMindi(ligado: ligado!, aoMudar: aoAlternar)
            else
              Icon(Ico.avancar,
                  size: 20, color: T.fraco),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String valor, label;
  final Color? cor;
  final bool divisor;
  const _Stat(
      {required this.valor,
      required this.label,
      this.cor,
      this.divisor = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (divisor)
            Positioned(
              left: 0,
              top: 2,
              bottom: 2,
              child: Container(width: 1, color: T.line),
            ),
          Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valor,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                        color: cor ?? T.ink)),
              ),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: T.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
