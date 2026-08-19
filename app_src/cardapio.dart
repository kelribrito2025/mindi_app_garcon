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
    final achados = produtos
        .where((p) => p.disponivel && _limpo(p.nome).contains(t))
        .toList();
    // quem começa com o que foi digitado aparece primeiro
    achados.sort((a, b) {
      final ca = _limpo(a.nome).startsWith(t) ? 0 : 1;
      final cb = _limpo(b.nome).startsWith(t) ? 0 : 1;
      if (ca != cb) return ca - cb;
      return a.nome.compareTo(b.nome);
    });
    return achados.take(30).toList();
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

  ItemNovo({
    required this.produto,
    this.quantidade = 1,
    Map<OpcaoComplemento, int>? extras,
  }) : extras = extras ?? {};

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
      };
}
