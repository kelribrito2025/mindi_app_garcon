import 'api.dart';
import 'modelos.dart';

/* ================================================================== *
 *  CARDÁPIO EM MEMÓRIA
 *  Baixa uma vez e guarda. O garçom digita e a busca acontece no
 *  celular, sem esperar internet a cada letra.
 * ================================================================== */
class Cardapio {
  static List<Categoria> categorias = [];
  static List<Produto> produtos = [];
  static List<GrupoComplemento> complementos = [];

  static bool carregado = false;
  static bool _carregando = false;

  /// baixa o cardápio inteiro (categorias, produtos e complementos)
  static Future<void> carregar({bool forcar = false}) async {
    if (_carregando) return;
    if (carregado && !forcar) return;
    if (!apiConfigurada) return;

    _carregando = true;
    try {
      final r = await Future.wait([
        Api.categorias(),
        Api.produtos(),
        Api.complementos(),
      ]);
      categorias = (r[0]).map(Categoria.fromJson).toList();
      produtos = (r[1]).map(Produto.fromJson).toList();
      complementos = (r[2]).map(GrupoComplemento.fromJson).toList();
      carregado = true;
    } finally {
      _carregando = false;
    }
  }

  /// esquece tudo (usado ao sair da conta)
  static void limpar() {
    categorias = [];
    produtos = [];
    complementos = [];
    carregado = false;
  }

  static String nomeDaCategoria(int id) {
    for (final c in categorias) {
      if (c.id == id) return c.nome;
    }
    return '';
  }

  static List<GrupoComplemento> gruposDe(int produtoId) =>
      complementos.where((g) => g.produtoId == produtoId).toList();

  /// busca sem acento e sem ligar para maiúsculas
  static List<Produto> buscar(String termo) {
    final t = _limpo(termo);
    if (t.isEmpty) return const [];

    // Só entra na lista o produto em que ALGUMA palavra do nome COMEÇA
    // com o que foi digitado. Nada de casar no meio da palavra: digitar
    // "t" não pode trazer "Batata".
    final achados = produtos
        .where((p) => p.disponivel && _comecaCom(p.nome, t))
        .toList();

    // quem começa na primeira palavra aparece primeiro
    achados.sort((a, b) {
      final ca = _limpo(a.nome).startsWith(t) ? 0 : 1;
      final cb = _limpo(b.nome).startsWith(t) ? 0 : 1;
      if (ca != cb) return ca - cb;
      return a.nome.compareTo(b.nome);
    });
    return achados.take(30).toList();
  }

  /// true se o trecho digitado começa uma palavra do nome.
  /// "bat" acha "Batata"; "t" NÃO acha "Batata"; "batata f" acha
  /// "Batata Frita".
  static bool _comecaCom(String nome, String t) {
    final n = _limpo(nome);
    var de = 0;
    while (true) {
      final i = n.indexOf(t, de);
      if (i < 0) return false;
      if (i == 0 || !_letra(n[i - 1])) return true;
      de = i + 1;
    }
  }

  static bool _letra(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 97 && u <= 122) || (u >= 48 && u <= 57);
  }

  static String _limpo(String s) {
    var t = s.toLowerCase().trim();
    const de = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < de.length; i++) {
      t = t.replaceAll(de[i], para[i]);
    }
    return t;
  }
}

/* ================================================================== *
 *  ITEM QUE O GARÇOM ESTÁ MONTANDO (ainda não enviado)
 * ================================================================== */
class ItemNovo {
  final Produto produto;
  int quantidade;

  /// complementos escolhidos: opção -> quantidade
  final Map<OpcaoComplemento, int> extras;

  /// observação para a cozinha: "sem cebola", "ao ponto"...
  String observacao;

  ItemNovo({
    required this.produto,
    this.quantidade = 1,
    this.observacao = '',
    Map<OpcaoComplemento, int>? extras,
  }) : extras = extras ?? {};

  /// duas linhas do carrinho só se juntam se forem idênticas:
  /// mesmo produto, mesmos complementos e mesma observação
  String get assinatura =>
      '${produto.id}|${nomesDosExtras.join(",")}|${observacao.trim()}';

  double get precoDosExtras {
    var soma = 0.0;
    extras.forEach((op, q) => soma += op.precoValendo * q);
    return soma;
  }

  /// preço de uma unidade, já com os complementos
  double get precoUnitario => produto.precoValendo + precoDosExtras;

  double get total => precoUnitario * quantidade;

  List<String> get nomesDosExtras => extras.entries
      .where((e) => e.value > 0)
      .map((e) => e.value > 1 ? '${e.value}x ${e.key.nome}' : e.key.nome)
      .toList();

  /// vira o JSON que a API espera em add-items
  Map<String, dynamic> paraApi() => {
        'productId': produto.id,
        'productName': produto.nome,
        'quantity': quantidade,
        'unitPrice': paraServidor(produto.precoValendo),
        'totalPrice': paraServidor(total),
        'complements': extras.entries
            .where((e) => e.value > 0)
            .map((e) => {
                  'name': e.key.nome,
                  'price': e.key.precoValendo,
                  'quantity': e.value,
                })
            .toList(),
        if (observacao.trim().isNotEmpty) 'notes': observacao.trim(),
      };
}
