import 'dart:async';
import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'estado.dart';
import 'modelos.dart';
import 'sheet_mesa.dart';
import 'sheet_criar_mesas.dart';

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
  int _espacoAberto = 0; // 0 = todos
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

  List<Mesa> get _visiveis => _espacoAberto == 0
      ? _mesas
      : _mesas.where((m) => m.espacoId == _espacoAberto).toList();

  int get _ocupadas => _mesas.where((m) => !m.livre).length;

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
            HeaderVermelho(
              alturaExtra: 74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [BarraBoasVindas()],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSide),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _resumo(),
                    const SizedBox(height: 18),
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

  Widget _resumo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: sombraCard(opacidade: .09, blur: 20, y: 6),
      ),
      child: Row(
        children: [
          _numero('${_mesas.length}', 'mesas'),
          _divisor(),
          _numero('$_ocupadas', 'ocupadas', cor: T.redDark),
          _divisor(),
          _numero('${_mesas.length - _ocupadas}', 'livres', cor: T.green),
        ],
      ),
    );
  }

  Widget _divisor() => Container(width: 1, height: 34, color: T.line);

  Widget _numero(String valor, String label, {Color? cor}) => Expanded(
        child: Column(
          children: [
            Text(valor,
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: cor ?? T.ink,
                    letterSpacing: -.6)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: T.inkSoft)),
          ],
        ),
      );

  Widget _filtros() {
    final todos = [const Espaco(id: 0, nome: 'Todos'), ..._espacos];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // +1 no fim da lista: o botão de criar mesas
        itemCount: todos.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == todos.length) return _botaoCriar();
          final e = todos[i];
          final ativo = e.id == _espacoAberto;
          return AfundaAoTocar(
            onTap: () => setState(() => _espacoAberto = e.id),
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

    if (_visiveis.isEmpty) {
      return _vazio(Ico.mesas, 'Nenhuma mesa por aqui',
          'Cadastre as mesas no painel para elas aparecerem aqui.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _visiveis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .92,
      ),
      itemBuilder: (_, i) => _CardMesa(
        mesa: _visiveis[i],
        // a numeração recomeça em cada espaço, então em "Todos" pode
        // existir mais de uma mesa 1. Aí o card mostra de onde ela é.
        espaco: _espacoAberto == 0 ? _nomeDoEspaco(_visiveis[i].espacoId) : '',
        onTap: () => _abrirMesa(_visiveis[i]),
      ),
    );
  }

  String _nomeDoEspaco(int id) {
    for (final e in _espacos) {
      if (e.id == id) return e.nome;
    }
    return '';
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
    final mudou = await mostrarMesa(context, m);
    if (mudou == true && mounted) _atualizar();
  }
}

/* ---------------- card de uma mesa ---------------- */
class _CardMesa extends StatelessWidget {
  final Mesa mesa;

  /// nome do espaço — só vem preenchido quando o filtro está em "Todos"
  final String espaco;
  final VoidCallback onTap;
  const _CardMesa({
    required this.mesa,
    required this.onTap,
    this.espaco = '',
  });

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
    } else if (mesa.ocupada) {
      cor = T.redDark;
      fundo = T.redSuave;
      // mesa ocupada não precisa de rótulo: a borda vermelha, o valor e
      // a quantidade de pessoas já dizem tudo
      rotulo = '';
    } else {
      cor = T.green;
      fundo = T.greenSuave;
      rotulo = 'LIVRE';
    }

    return AfundaAoTocar(
      onTap: onTap,
      escala: .96,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: mesa.livre ? T.borda : cor, width: 1.4),
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
                  child: Text(mesa.titulo,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 15,
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
            if (rotulo.isNotEmpty)
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
