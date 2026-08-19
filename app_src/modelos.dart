/* ================================================================== *
 *  MODELOS — traduzem o JSON da API para o app
 *
 *  ATENÇÃO: estes modelos foram montados a partir do PLANO da API.
 *  Quando a documentação final chegar, os nomes dos campos podem
 *  mudar — o ajuste é só aqui dentro, as telas não precisam mexer.
 * ================================================================== */

/// converte "15.50", 15.5 ou null em número
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

DateTime? _data(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String reais(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// como o servidor manda dinheiro em texto ("15.50"), o app devolve
/// no mesmo formato quando precisa enviar de volta
String paraServidor(double v) => v.toStringAsFixed(2);

/* ================================================================== *
 *  ESPAÇO — Salão, Varanda, Área externa...
 * ================================================================== */
class Espaco {
  final int id;
  final String nome;
  const Espaco({required this.id, required this.nome});

  factory Espaco.fromJson(Map<String, dynamic> j) => Espaco(
        id: _int(j['id']),
        nome: (j['name'] ?? '').toString(),
      );
}

/* ================================================================== *
 *  MESA
 * ================================================================== */
class Mesa {
  final int id;
  final String numero;
  final String status; // free, occupied, reserved, requesting_bill
  final int espacoId;
  final String espacoNome;
  final int pessoas;
  final String identificacao; // "João", "Aniversário"
  final double total;
  final int itens;
  final DateTime? abertaEm;
  final int? comandaId;
  final bool minha;

  const Mesa({
    required this.id,
    required this.numero,
    required this.status,
    this.espacoId = 0,
    this.espacoNome = '',
    this.pessoas = 0,
    this.identificacao = '',
    this.total = 0,
    this.itens = 0,
    this.abertaEm,
    this.comandaId,
    this.minha = false,
  });

  factory Mesa.fromJson(Map<String, dynamic> j) => Mesa(
        id: _int(j['id']),
        numero: (j['number'] ?? j['name'] ?? j['id']).toString(),
        status: (j['status'] ?? 'free').toString(),
        espacoId: _int(j['spaceId']),
        espacoNome: (j['spaceName'] ?? '').toString(),
        pessoas: _int(j['people']),
        identificacao: (j['label'] ?? '').toString(),
        total: _num(j['total']),
        itens: _int(j['itemCount']),
        abertaEm: _data(j['openedAt']),
        comandaId: j['tabId'] == null ? null : _int(j['tabId']),
        minha: j['isMine'] == true,
      );

  bool get livre => status == 'free';
  bool get ocupada => status == 'occupied';
  bool get reservada => status == 'reserved';
  bool get pedindoConta => status == 'requesting_bill';
}

/* ================================================================== *
 *  ITEM DA COMANDA
 * ================================================================== */
class ItemComanda {
  final int id;
  final String nome;
  final int quantidade;
  final double preco;
  final String observacao;
  final String status; // pending, preparing, ready, delivered
  final List<String> complementos;

  const ItemComanda({
    required this.id,
    required this.nome,
    required this.quantidade,
    required this.preco,
    this.observacao = '',
    this.status = '',
    this.complementos = const [],
  });

  factory ItemComanda.fromJson(Map<String, dynamic> j) {
    final comps = (j['complements'] is List) ? j['complements'] as List : const [];
    return ItemComanda(
      id: _int(j['id']),
      nome: (j['name'] ?? j['productName'] ?? '').toString(),
      quantidade: _int(j['quantity']),
      preco: _num(j['price'] ?? j['unitPrice']),
      observacao: (j['notes'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      complementos: comps
          .whereType<Map>()
          .map((c) => (c['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toList(),
    );
  }

  double get subtotal => preco * quantidade;
  bool get pronto => status == 'ready';
}

/* ================================================================== *
 *  COMANDA
 * ================================================================== */
class Comanda {
  final int id;
  final int mesaId;
  final List<ItemComanda> itens;
  final double subtotal;
  final double taxaServico;
  final double total;
  final double pago;

  const Comanda({
    required this.id,
    required this.mesaId,
    this.itens = const [],
    this.subtotal = 0,
    this.taxaServico = 0,
    this.total = 0,
    this.pago = 0,
  });

  factory Comanda.fromJson(Map<String, dynamic> j) {
    final lista = (j['items'] is List) ? j['items'] as List : const [];
    return Comanda(
      id: _int(j['id']),
      mesaId: _int(j['tableId']),
      itens: lista
          .whereType<Map>()
          .map((e) => ItemComanda.fromJson(e.cast<String, dynamic>()))
          .toList(),
      subtotal: _num(j['subtotal']),
      taxaServico: _num(j['serviceFee']),
      total: _num(j['total']),
      pago: _num(j['paidAmount']),
    );
  }

  double get falta => total - pago;
}

/* ================================================================== *
 *  CARDÁPIO
 * ================================================================== */
class Categoria {
  final int id;
  final String nome;
  final int produtos;
  const Categoria({required this.id, required this.nome, this.produtos = 0});

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
        id: _int(j['id']),
        nome: (j['name'] ?? '').toString(),
        produtos: _int(j['productCount']),
      );
}

class Produto {
  final int id;
  final int categoriaId;
  final String nome;
  final String descricao;
  final double preco;
  final String imagem;
  final bool disponivel;
  final List<int> gruposDeComplemento;

  const Produto({
    required this.id,
    required this.categoriaId,
    required this.nome,
    this.descricao = '',
    this.preco = 0,
    this.imagem = '',
    this.disponivel = true,
    this.gruposDeComplemento = const [],
  });

  factory Produto.fromJson(Map<String, dynamic> j) {
    final grupos = (j['complementGroupIds'] is List)
        ? (j['complementGroupIds'] as List).map(_int).toList()
        : <int>[];
    return Produto(
      id: _int(j['id']),
      categoriaId: _int(j['categoryId']),
      nome: (j['name'] ?? '').toString(),
      descricao: (j['description'] ?? '').toString(),
      preco: _num(j['price']),
      imagem: (j['imageUrl'] ?? j['image'] ?? '').toString(),
      disponivel: j['available'] != false && j['isActive'] != false,
      gruposDeComplemento: grupos,
    );
  }
}

class OpcaoComplemento {
  final int id;
  final String nome;
  final double preco;
  const OpcaoComplemento(
      {required this.id, required this.nome, this.preco = 0});

  factory OpcaoComplemento.fromJson(Map<String, dynamic> j) =>
      OpcaoComplemento(
        id: _int(j['id']),
        nome: (j['name'] ?? '').toString(),
        preco: _num(j['price']),
      );
}

class GrupoComplemento {
  final int id;
  final String nome;
  final int minimo;
  final int maximo;
  final List<OpcaoComplemento> opcoes;

  const GrupoComplemento({
    required this.id,
    required this.nome,
    this.minimo = 0,
    this.maximo = 0,
    this.opcoes = const [],
  });

  factory GrupoComplemento.fromJson(Map<String, dynamic> j) {
    final lista = (j['options'] is List) ? j['options'] as List : const [];
    return GrupoComplemento(
      id: _int(j['id']),
      nome: (j['name'] ?? '').toString(),
      minimo: _int(j['min']),
      maximo: _int(j['max']),
      opcoes: lista
          .whereType<Map>()
          .map((e) => OpcaoComplemento.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  bool get obrigatorio => minimo > 0;
}
