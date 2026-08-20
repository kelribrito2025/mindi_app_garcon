import 'dart:async';
import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'estado.dart';
import 'modelos.dart';
import 'sheet_mesa.dart';
import 'sheet_criar_mesas.dart';
import 'sheet_apagar_espaco.dart';
import 'sheet_gerenciar.dart';
import 'sheet_juntar.dart';

/* ================================================================== *
 *  ABA MESAS — o mapa do salão
 *
 *  Esta tela já busca os dados de verdade em /api/waiter/tables.
 *  Enquanto o backend não estiver pronto, ela mostra o aviso de que
 *  não conseguiu falar com o servidor — é o comportamento certo.
 * ================================================================== */
class TelaMesas extends StatefulWidget {
  const TelaMesas({super.key});

  @override
  State<TelaMesas> createState() => _TelaMesasState();
}

class _TelaMesasState extends State<TelaMesas> {
  List<Espaco> _espacos = [];
  List<Mesa> _mesas = [];
  int _espacoAberto = 0; // 0 = ainda não carregou nenhum espaço

  /// filtro pela situação da mesa, escolhido na legenda do topo.
  /// null = mostra todas. Valores: 'ocupada', 'conta', 'livre'
  String? _filtro;
  bool _carregando = false;
  bool _primeiraVez = true;
  String? _erro;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _atualizar();
    // o mapa se atualiza sozinho a cada 15 segundos
    _relogio = Timer.periodic(const Duration(seconds: 15), (_) => _atualizar());
    avisoDeNovidade.addListener(_aoChegarAviso);
  }

  @override
  void dispose() {
    _relogio?.cancel();
    avisoDeNovidade.removeListener(_aoChegarAviso);
    super.dispose();
  }

  void _aoChegarAviso() {
    if (mounted) _atualizar();
  }

  Future<void> _atualizar() async {
    if (!apiConfigurada || _carregando) return;
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        Api.espacos(),
        Api.mesas(),
      ]);
      if (!mounted) return;
      setState(() {
        _espacos = (resultados[0]).map(Espaco.fromJson).toList();
        _mesas = (resultados[1]).map(Mesa.fromJson).toList();
        _erro = null;

        // sempre tem um espaço aberto: se nenhum foi escolhido ainda,
        // ou se o escolhido sumiu, abre o primeiro da lista
        final existe = _espacos.any((e) => e.id == _espacoAberto);
        if (!existe) {
          _espacoAberto = _espacos.isEmpty ? 0 : _espacos.first.id;
        }
      });
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar o salão.');
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
          _primeiraVez = false;
        });
      }
    }
  }

  /// todas as mesas do espaço aberto (é o que a legenda conta)
  List<Mesa> get _doEspaco =>
      _mesas.where((m) => m.espacoId == _espacoAberto).toList();

  /// o que aparece na grade: o espaço aberto, já com o filtro aplicado
  List<Mesa> get _visiveis {
    final lista = _doEspaco;
    switch (_filtro) {
      case 'ocupada':
        return lista.where((m) => !m.pareceLivre && !m.pedindoConta).toList();
      case 'conta':
        return lista.where((m) => m.pedindoConta).toList();
      case 'livre':
        return lista.where((m) => m.pareceLivre).toList();
      default:
        return lista;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: T.redDark,
      onRefresh: _atualizar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
            bottom: 130 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // mesmo topo vermelho das abas Ajustes e Perfil
            HeaderVermelho(child: BarraBoasVindas(direita: _contador())),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSide),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // o resumo saiu do vermelho e virou um cartão branco
                    _resumo(),
                    const SizedBox(height: 14),
                    // a fila sempre aparece: mesmo sem nenhum espaço
                    // cadastrado, o botão "+" precisa estar ali
                    _filtros(),
                    const SizedBox(height: 14),
                    _conteudo(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ---------------------------------------------------------------- *
   *  RESUMO DENTRO DO TOPO VERMELHO
   *  Reservada conta como ocupada: no salão a mesa não está livre.
   * ---------------------------------------------------------------- */
  int get _total => _doEspaco.length;
  int get _pedindoConta => _doEspaco.where((m) => m.pedindoConta).length;
  int get _livres => _doEspaco.where((m) => m.pareceLivre).length;
  int get _ocupadas => _total - _livres - _pedindoConta;

  /// "13/19 ocupadas" — texto simples, sem moldura
  Widget _contador() {
    if (_total == 0) return const SizedBox.shrink();
    return Text('${_total - _livres}/$_total ocupadas',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: -.2));
  }

  /// cartão branco com os três filtros (ocupadas, conta, livres)
  Widget _resumo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: sombraCard(opacidade: .09, blur: 20, y: 6),
      ),
      child: _legenda(),
    );
  }

  /// tocar na legenda filtra a grade; tocar de novo mostra tudo
  Widget _legenda() {
    return Row(
      children: [
        _pontinho(T.redDark, '$_ocupadas ocupadas', 'ocupada'),
        const SizedBox(width: 8),
        _pontinho(T.amarelo, '$_pedindoConta conta', 'conta'),
        const SizedBox(width: 8),
        _pontinho(T.green, '$_livres livres', 'livre'),
      ],
    );
  }

  Widget _pontinho(Color cor, String texto, String chave) {
    final ligado = _filtro == chave;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _filtro = ligado ? null : chave),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: ligado ? T.campo : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: ligado ? T.borda : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(texto,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: ligado ? FontWeight.w800 : FontWeight.w600,
                    color: ligado ? T.ink : T.inkMedio)),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // +2 no fim da lista: criar mesas e gerenciar
        itemCount: _espacos.length + 2,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == _espacos.length) return _botaoCriar();
          if (i == _espacos.length + 1) return _botaoGerenciar();
          final e = _espacos[i];
          final ativo = e.id == _espacoAberto;
          return AfundaAoTocar(
            onTap: () => setState(() => _espacoAberto = e.id),
            // segurar o dedo abre a opção de apagar o espaço
            onLongPress: () => _apagarEspaco(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ativo ? T.redDark : T.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ativo ? T.redDark : T.borda),
              ),
              child: Text(e.nome,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ativo ? Colors.white : T.inkMedio)),
            ),
          );
        },
      ),
    );
  }

  /// botão "+" no fim da fila de espaços: abre o modal de criar mesas
  Widget _botaoCriar() {
    return AfundaAoTocar(
      onTap: _criarMesas,
      child: Container(
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: T.borda),
        ),
        child: Icon(Ico.maisItem, size: 18, color: T.redDark),
      ),
    );
  }

  /// engrenagem no fim da fila: renomear espaço e restaurar mesa
  Widget _botaoGerenciar() {
    return AfundaAoTocar(
      onTap: _gerenciar,
      child: Container(
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: T.borda),
        ),
        child: Icon(Ico.ajustes, size: 17, color: T.inkMedio),
      ),
    );
  }

  Future<void> _gerenciar() async {
    final mudou = await mostrarGerenciar(context, _espacos);
    if (mudou == true && mounted) await _atualizar();
  }

  Future<void> _apagarEspaco(Espaco e) async {
    final doEspaco = _mesas.where((m) => m.espacoId == e.id).toList();
    final apagou = await mostrarApagarEspaco(
      context,
      espacoId: e.id,
      nome: e.nome,
      mesas: doEspaco.length,
      ocupadas: doEspaco.where((m) => !m.livre).length,
    );
    if (apagou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Espaço "${e.nome}" apagado'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.dark2,
      ));
      setState(() => _espacoAberto = 0); // deixa escolher o primeiro de novo
      await _atualizar();
    }
  }

  Future<void> _criarMesas() async {
    final criou = await mostrarCriarMesas(context);
    if (criou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Mesas criadas'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.dark2,
      ));
      await _atualizar();
    }
  }

  Widget _conteudo() {
    if (_primeiraVez && _carregando) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Espera(texto: 'Carregando o salão...'),
      );
    }

    if (_erro != null && _mesas.isEmpty) {
      return _vazio(Ico.semInternet, 'Sem conexão com o salão', _erro!);
    }

    if (_espacos.isEmpty) {
      return _vazio(Ico.mesas, 'Nenhum espaço cadastrado',
          'Toque no + ao lado para criar o primeiro espaço com as mesas.');
    }

    if (_visiveis.isEmpty && _filtro != null) {
      const nomes = {
        'ocupada': 'ocupada',
        'conta': 'com a conta pedida',
        'livre': 'livre',
      };
      return _vazio(Ico.mesas, 'Nenhuma mesa ${nomes[_filtro]}',
          'Toque de novo na legenda do topo para ver todas.');
    }

    if (_visiveis.isEmpty) {
      return _vazio(Ico.mesas, 'Nenhuma mesa neste espaço',
          'Crie mesas aqui pelo botão + ou escolha outro espaço.');
    }

    // grade ou lista, conforme a escolha em Ajustes
    return ValueListenableBuilder<bool>(
      valueListenable: modoLista,
      builder: (_, lista, __) => lista ? _emLista() : _emGrade(),
    );
  }

  Widget _emGrade() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // sem isso a grade se acha a rolagem principal da tela e reserva
      // um espaço no topo do tamanho da barra de status do celular
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: _visiveis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .92,
      ),
      itemBuilder: (_, i) => _arrastavel(
        _visiveis[i],
        _CardMesa(
          mesa: _visiveis[i],
          onTap: () => _abrirMesa(_visiveis[i]),
        ),
      ),
    );
  }

  Widget _emLista() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: _visiveis.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _arrastavel(
        _visiveis[i],
        _LinhaMesa(
          mesa: _visiveis[i],
          onTap: () => _abrirMesa(_visiveis[i]),
        ),
      ),
    );
  }

  /* ---------------- arrastar uma mesa em cima da outra ---------------- */

  /// Pode arrastar? Mesa fechada/reservada e mesa que já está num grupo
  /// ficam de fora — o servidor recusaria de qualquer jeito.
  bool _podeJuntar(Mesa m) =>
      !m.reservada && !m.pedindoConta && !m.emGrupo;

  Widget _arrastavel(Mesa mesa, Widget cartao) {
    // a mesa que não pode entrar em grupo continua sendo só um card
    if (!_podeJuntar(mesa)) return cartao;

    return DragTarget<Mesa>(
      onWillAccept: (vinda) =>
          vinda != null && vinda.id != mesa.id && _podeJuntar(mesa),
      onAccept: (vinda) => _confirmarJuntar(vinda, mesa),
      builder: (_, chegando, __) {
        final destacado = chegando.isNotEmpty;
        return LongPressDraggable<Mesa>(
          data: mesa,
          delay: const Duration(milliseconds: 220),
          feedback: Opacity(
            opacity: .9,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: 108, child: cartao),
            ),
          ),
          childWhenDragging: Opacity(opacity: .3, child: cartao),
          // o destaque é desenhado POR CIMA do card, não em volta:
          // uma moldura de verdade encolheria o card em 4px sempre,
          // mesmo transparente
          child: Stack(
            children: [
              cartao,
              if (destacado)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: T.redDark, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarJuntar(Mesa arrastada, Mesa alvo) async {
    final juntou = await mostrarJuntarMesas(
      context,
      arrastada: arrastada,
      alvo: alvo,
    );
    if (juntou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Mesas juntadas'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.dark2,
      ));
      await _atualizar();
    }
  }

  Widget _vazio(IconData icone, String titulo, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 46),
        child: Column(
          children: [
            Icon(icone, size: 40, color: T.fraco),
            const SizedBox(height: 12),
            Text(titulo,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: T.ink)),
            const SizedBox(height: 5),
            Text(texto,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: T.inkSoft)),
          ],
        ),
      );

  Future<void> _abrirMesa(Mesa m) async {
    // mesa encostada em outra não tem comanda própria: abre a principal
    var alvo = m;
    if (m.secundariaDoGrupo) {
      final principais = _mesas.where((x) => x.id == m.juntadaEm);
      if (principais.isNotEmpty) alvo = principais.first;
    }
    final mudou = await mostrarMesa(context, alvo);
    if (mudou == true && mounted) _atualizar();
  }
}

/* ---------------- card de uma mesa ---------------- */
class _CardMesa extends StatelessWidget {
  final Mesa mesa;
  final VoidCallback onTap;
  const _CardMesa({required this.mesa, required this.onTap});

  /// linha de baixo do card: quem está na mesa ou há quanto tempo
  String get _legenda {
    if (mesa.identificacao.isNotEmpty) return mesa.identificacao;
    if (mesa.livre) return '';
    return mesa.tempoAberta;
  }

  @override
  Widget build(BuildContext context) {
    late final Color cor;
    late final Color fundo;
    late final String rotulo;

    if (mesa.pedindoConta) {
      cor = T.amarelo;
      fundo = T.amareloSuave;
      rotulo = 'CONTA';
    } else if (mesa.reservada) {
      cor = T.azul;
      fundo = T.azulSuave;
      rotulo = 'RESERVADA';
    } else if (mesa.ocupada && !mesa.semConsumo) {
      cor = T.redDark;
      fundo = T.redSuave;
      // mesa ocupada não precisa de rótulo: a borda vermelha, o valor e
      // a quantidade de pessoas já dizem tudo
      rotulo = '';
    } else {
      cor = T.green;
      fundo = T.greenSuave;
      // mesa aberta sem nenhum item ainda não conta como ocupada
      rotulo = mesa.semConsumo ? 'ABERTA' : 'LIVRE';
    }

    return AfundaAoTocar(
      onTap: onTap,
      escala: .96,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: mesa.pareceLivre ? T.borda : cor, width: 1.4),
          boxShadow: sombraCard(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // o quadradinho colorido agora carrega o número da mesa
                Container(
                  constraints: const BoxConstraints(minWidth: 30),
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fundo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                      mesa.principalDoGrupo
                          ? mesa.tituloDoGrupo
                          : mesa.titulo,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: mesa.principalDoGrupo ? 13 : 15,
                          fontWeight: FontWeight.w800,
                          color: cor,
                          letterSpacing: -.3)),
                ),
                const Spacer(),
                if (mesa.pessoas > 0)
                  Row(
                    children: [
                      Icon(Ico.pessoas, size: 12, color: T.inkSoft),
                      const SizedBox(width: 3),
                      Text('${mesa.pessoas}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: T.inkSoft)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // quem está na mesa; se ninguém identificou, o tempo aberta
            if (_legenda.isNotEmpty)
              Text(_legenda,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: T.inkMedio)),
            const Spacer(),
            if (mesa.secundariaDoGrupo)
              Row(
                children: [
                  Icon(Ico.juntar, size: 10, color: cor),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text('JUNTA',
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                            color: cor)),
                  ),
                ],
              )
            else if (rotulo.isNotEmpty)
              Text(rotulo,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: cor)),
            if (mesa.total > 0)
              Text(reais(mesa.total),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
          ],
        ),
      ),
    );
  }
}

/* ---------------- uma mesa em modo lista ---------------- */
class _LinhaMesa extends StatelessWidget {
  final Mesa mesa;
  final VoidCallback onTap;
  const _LinhaMesa({required this.mesa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    late final Color cor;
    late final Color fundo;
    late final String rotulo;

    if (mesa.pedindoConta) {
      cor = T.amarelo;
      fundo = T.amareloSuave;
      rotulo = 'CONTA';
    } else if (mesa.reservada) {
      cor = T.azul;
      fundo = T.azulSuave;
      rotulo = 'RESERVADA';
    } else if (mesa.ocupada && !mesa.semConsumo) {
      cor = T.redDark;
      fundo = T.redSuave;
      rotulo = 'OCUPADA';
    } else {
      cor = T.green;
      fundo = T.greenSuave;
      rotulo = mesa.semConsumo ? 'ABERTA' : 'LIVRE';
    }

    final detalhe = <String>[
      if (mesa.secundariaDoGrupo) 'junta com outra mesa',
      if (mesa.identificacao.isNotEmpty) mesa.identificacao,
      if (mesa.pessoas > 0) '${mesa.pessoas} pessoas',
      if (!mesa.livre && mesa.tempoAberta.isNotEmpty) mesa.tempoAberta,
    ].join(' · ');

    return AfundaAoTocar(
      onTap: onTap,
      escala: .98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: mesa.pareceLivre ? T.borda : cor, width: 1.4),
          boxShadow: sombraCard(),
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 42),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                  mesa.principalDoGrupo ? mesa.tituloDoGrupo : mesa.titulo,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: mesa.principalDoGrupo ? 14 : 17,
                      fontWeight: FontWeight.w800,
                      color: cor,
                      letterSpacing: -.3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rotulo,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                          color: cor)),
                  if (detalhe.isNotEmpty)
                    Text(detalhe,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: T.inkMedio)),
                ],
              ),
            ),
            if (mesa.total > 0)
              Text(reais(mesa.total),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
          ],
        ),
      ),
    );
  }
}
