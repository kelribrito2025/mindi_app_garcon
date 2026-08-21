import 'dart:convert';

/* ================================================================== *
 *  MODELOS — traduzem o JSON da API para o app
 *
 *  Baseados na documentação "API REST — App Garçom (Mindi)" v1.0.
 *  Se um campo mudar no servidor, o conserto é só aqui dentro.
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

/// versão curta, sem centavos — usada nos números pequenos da aba Ganhos
String reaisCurto(double v) => 'R\$ ${v.toStringAsFixed(0)}';

/// como o servidor manda dinheiro em texto ("15.50"), o app devolve
/// no mesmo formato quando precisa enviar de volta
String paraServidor(double v) => v.toStringAsFixed(2);
/* ================================================================== *
 *  ESPAÇO — Salão, Varanda, Terraço...
 * ================================================================== */
class Espaco {
  final int id;
  final String nome;
  final int ordem;

  /// quantas mesas existem neste espaço (vem do servidor)
  final int mesas;

  const Espaco({
    required this.id,
    required this.nome,
    this.ordem = 0,
    this.mesas = 0,
  });

  factory Espaco.fromJson(Map<String, dynamic> j) => Espaco(
        id: _int(j['id']),
        nome: (j['name'] ?? '').toString(),
        ordem: _int(j['sortOrder']),
        mesas: _int(j['tableCount']),
      );
}

/* ================================================================== *
 *  MESA NA LIXEIRA
 * ================================================================== */
class MesaExcluida {
  final int id;
  final int numero;
  final String nome;
  final int espacoId;
  final String espacoNome;
  final DateTime? excluidaEm;

  const MesaExcluida({
    required this.id,
    required this.numero,
    this.nome = '',
    this.espacoId = 0,
    this.espacoNome = '',
    this.excluidaEm,
  });

  factory MesaExcluida.fromJson(Map<String, dynamic> j) => MesaExcluida(
        id: _int(j['id']),
        numero: _int(j['number']),
        nome: (j['name'] ?? '').toString(),
        espacoId: _int(j['spaceId']),
        espacoNome: (j['spaceName'] ?? '').toString(),
        excluidaEm: _data(j['deletedAt']),
      );

  String get titulo => nome.isNotEmpty ? nome : 'Mesa $numero';

  /// "há 2 dias", "há 3 horas"
  String get quando {
    final d = excluidaEm;
    if (d == null) return '';
    final dif = DateTime.now().difference(d);
    if (dif.inMinutes < 60) return 'há ${dif.inMinutes} min';
    if (dif.inHours < 24) {
      return 'há ${dif.inHours} ${dif.inHours == 1 ? "hora" : "horas"}';
    }
    return 'há ${dif.inDays} ${dif.inDays == 1 ? "dia" : "dias"}';
  }
}

/* ================================================================== *
 *  RESUMO DA COMANDA — o que vem junto de cada mesa em /tables
 * ================================================================== */
class ResumoComanda {
  final int id;
  final String numero;
  final String status;
  final double subtotal;
  final double taxaServico;
  final double desconto;
  final double total;
  final int itens;
  final double pago;
  final DateTime? abertaEm;

  const ResumoComanda({
    required this.id,
    this.numero = '',
    this.status = '',
    this.subtotal = 0,
    this.taxaServico = 0,
    this.desconto = 0,
    this.total = 0,
    this.itens = 0,
    this.pago = 0,
    this.abertaEm,
  });

  factory ResumoComanda.fromJson(Map<String, dynamic> j) => ResumoComanda(
        id: _int(j['id']),
        numero: (j['tabNumber'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        subtotal: _num(j['subtotal']),
        taxaServico: _num(j['serviceCharge']),
        desconto: _num(j['discount']),
        total: _num(j['total']),
        itens: _int(j['itemCount']),
        pago: _num(j['paidAmount']),
        abertaEm: _data(j['openedAt']),
      );

  double get falta => (total - pago) < 0 ? 0 : total - pago;
}

/* ================================================================== *
 *  MESA
 * ================================================================== */
class Mesa {
  final int id;
  final int numero;
  final String nome;
  final String mostrarNumero;
  final int capacidade;
  final String status;
  final int pessoas;
  final int espacoId;
  final String identificacao;
  final DateTime? ocupadaEm;
  final DateTime? contaPedidaEm;
  final String contaPedidaPor;
  final ResumoComanda? comanda;

  /// juntar mesas: id da mesa principal (null quando não está junta
  /// ou quando ELA é a principal)
  final int? juntadaEm;

  /// ids das mesas secundárias — só vem preenchido na principal
  final List<int> mesasJuntadas;

  const Mesa({
    required this.id,
    required this.numero,
    this.nome = '',
    this.mostrarNumero = '',
    this.capacidade = 0,
    this.status = 'free',
    this.pessoas = 0,
    this.espacoId = 0,
    this.identificacao = '',
    this.ocupadaEm,
    this.contaPedidaEm,
    this.contaPedidaPor = '',
    this.comanda,
    this.juntadaEm,
    this.mesasJuntadas = const [],
  });

  factory Mesa.fromJson(Map<String, dynamic> j) {
    final t = j['tab'];
    return Mesa(
      id: _int(j['id']),
      numero: _int(j['number']),
      nome: (j['name'] ?? '').toString(),
      mostrarNumero: (j['displayNumber'] ?? '').toString(),
      capacidade: _int(j['capacity']),
      status: (j['status'] ?? 'free').toString(),
      pessoas: _int(j['currentGuests']),
      espacoId: _int(j['spaceId']),
      identificacao: (j['label'] ?? '').toString(),
      ocupadaEm: _data(j['occupiedAt']),
      contaPedidaEm: _data(j['requestingBillAt']),
      contaPedidaPor: (j['requestingBillBy'] ?? '').toString(),
      comanda:
          t is Map ? ResumoComanda.fromJson(t.cast<String, dynamic>()) : null,
      juntadaEm: j['mergedIntoId'] == null ? null : _int(j['mergedIntoId']),
      mesasJuntadas: _idsJuntadas(j['mergedTableIds']),
    );
  }

  /// o servidor manda isso como texto JSON: "[6]" ou "[6, 7]"
  static List<int> _idsJuntadas(dynamic bruto) {
    if (bruto == null) return const [];
    if (bruto is List) return bruto.map(_int).toList();
    final texto = bruto.toString().trim();
    if (texto.isEmpty || texto == 'null') return const [];
    try {
      final lido = jsonDecode(texto);
      if (lido is List) return lido.map(_int).toList();
    } catch (_) {
      // formato inesperado: melhor ignorar do que quebrar a tela
    }
    return const [];
  }

  /// o que aparece grande no card
  String get titulo =>
      mostrarNumero.isNotEmpty ? mostrarNumero : numero.toString();

  bool get livre => status == 'free';
  bool get ocupada => status == 'occupied';
  bool get reservada => status == 'reserved';
  bool get pedindoConta => status == 'requesting_bill';

  double get total => comanda?.total ?? 0;
  int get itens => comanda?.itens ?? 0;
  int? get comandaId => comanda?.id;

  /// Mesa aberta mas ainda sem nenhum item lançado.
  /// No card ela continua contando como livre — só vira ocupada
  /// depois que o garçom lança o primeiro item.
  bool get semConsumo => ocupada && itens == 0 && !secundariaDoGrupo;

  /* ---------------- juntar mesas ---------------- */

  /// está dentro de um grupo (principal ou secundária)?
  bool get emGrupo => juntadaEm != null || mesasJuntadas.isNotEmpty;

  /// é a mesa que segura a comanda do grupo
  bool get principalDoGrupo => mesasJuntadas.isNotEmpty;

  /// é uma mesa encostada em outra (sem comanda própria)
  bool get secundariaDoGrupo => juntadaEm != null;

  /// "5-6" quando junta; senão o número normal
  String get tituloDoGrupo => mostrarNumero.isNotEmpty
      ? mostrarNumero
      : (principalDoGrupo
          ? '$numero-${mesasJuntadas.join("-")}'
          : numero.toString());

  /// quantas mesas o grupo tem (contando a principal)
  int get quantasNoGrupo {
    if (mostrarNumero.isNotEmpty) return mostrarNumero.split('-').length;
    return principalDoGrupo ? 1 + mesasJuntadas.length : 1;
  }

  /// Versão curta para caber no card: até 4 mesas mostra todas,
  /// daí em diante mostra 3 e um "+N". Sem isso o texto vaza do card.
  String get tituloDoGrupoCurto {
    final partes = tituloDoGrupo.split('-');
    if (partes.length <= 4) return tituloDoGrupo;
    final sobra = partes.length - 3;
    return '${partes.take(3).join('-')} +$sobra';
  }

  /// É isso que manda na cor do card e nos contadores.
  bool get pareceLivre => livre || semConsumo;

  /// "45min" ou "1h20" desde que a mesa foi aberta
  String get tempoAberta {
    final d = ocupadaEm;
    if (d == null) return '';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'agora';
    if (m < 60) return '${m}min';
    return '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}';
  }
}

/* ================================================================== *
 *  ITEM DA COMANDA
 * ================================================================== */
class ItemComanda {
  final int id;
  final int produtoId;
  final String nome;
  final int quantidade;
  final double precoUnitario;
  final double precoTotal;
  final String observacao;
  final String status;
  final List<String> complementos;

  const ItemComanda({
    required this.id,
    this.produtoId = 0,
    required this.nome,
    required this.quantidade,
    this.precoUnitario = 0,
    this.precoTotal = 0,
    this.observacao = '',
    this.status = '',
    this.complementos = const [],
  });

  factory ItemComanda.fromJson(Map<String, dynamic> j) {
    final comps =
        (j['complements'] is List) ? j['complements'] as List : const [];
    return ItemComanda(
      id: _int(j['id']),
      produtoId: _int(j['productId']),
      nome: (j['productName'] ?? '').toString(),
      quantidade: _int(j['quantity']),
      precoUnitario: _num(j['unitPrice']),
      precoTotal: _num(j['totalPrice']),
      observacao: (j['notes'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      complementos: comps.whereType<Map>().map((c) {
        final q = _int(c['quantity']);
        final n = (c['name'] ?? '').toString();
        return q > 1 ? '${q}x $n' : n;
      }).where((n) => n.isNotEmpty).toList(),
    );
  }

  bool get pronto => status == 'ready';
  bool get cancelado => status == 'cancelled';

  String get situacao {
    switch (status) {
      case 'pending':
        return 'Aguardando';
      case 'preparing':
        return 'Preparando';
      case 'ready':
        return 'Pronto';
      case 'delivered':
        return 'Entregue';
      case 'cancelled':
        return 'Cancelado';
      default:
        return '';
    }
  }
}

/* ================================================================== *
 *  COMANDA COMPLETA — vem em GET /tables/:id
 * ================================================================== */
class Comanda {
  final int id;
  final String numero;
  final String status;
  final double subtotal;
  final double taxaServico;
  final double desconto;
  final double total;
  final double pago;
  final DateTime? abertaEm;
  final List<ItemComanda> itens;

  const Comanda({
    required this.id,
    this.numero = '',
    this.status = '',
    this.subtotal = 0,
    this.taxaServico = 0,
    this.desconto = 0,
    this.total = 0,
    this.pago = 0,
    this.abertaEm,
    this.itens = const [],
  });

  factory Comanda.fromJson(Map<String, dynamic> j) {
    final lista = (j['items'] is List) ? j['items'] as List : const [];
    return Comanda(
      id: _int(j['id']),
      numero: (j['tabNumber'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      subtotal: _num(j['subtotal']),
      taxaServico: _num(j['serviceCharge']),
      desconto: _num(j['discount']),
      total: _num(j['total']),
      pago: _num(j['paidAmount']),
      abertaEm: _data(j['openedAt']),
      itens: lista
          .whereType<Map>()
          .map((e) => ItemComanda.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  double get falta => (total - pago) < 0 ? 0 : total - pago;
}

/* ================================================================== *
 *  CARDÁPIO
 * ================================================================== */
class Categoria {
  final int id;
  final String nome;
  final String descricao;
  final int ordem;
  final int produtos;

  const Categoria({
    required this.id,
    required this.nome,
    this.descricao = '',
    this.ordem = 0,
    this.produtos = 0,
  });

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
        id: _int(j['id']),
        nome: (j['name'] ?? '').toString(),
        descricao: (j['description'] ?? '').toString(),
        ordem: _int(j['sortOrder']),
        produtos: _int(j['productCount']),
      );
}

class Produto {
  final int id;
  final int categoriaId;
  final String nome;
  final String descricao;
  final double preco;
  final double? precoPromocional;
  final String imagem;
  final String status;
  final bool controlaEstoque;
  final int? estoque;
  final bool temComplementos;

  const Produto({
    required this.id,
    required this.categoriaId,
    required this.nome,
    this.descricao = '',
    this.preco = 0,
    this.precoPromocional,
    this.imagem = '',
    this.status = 'active',
    this.controlaEstoque = false,
    this.estoque,
    this.temComplementos = false,
  });

  factory Produto.fromJson(Map<String, dynamic> j) {
    final imgs = (j['images'] is List) ? j['images'] as List : const [];
    return Produto(
      id: _int(j['id']),
      categoriaId: _int(j['categoryId']),
      nome: (j['name'] ?? '').toString(),
      descricao: (j['description'] ?? '').toString(),
      preco: _num(j['price']),
      precoPromocional:
          j['promotionalPrice'] == null ? null : _num(j['promotionalPrice']),
      imagem: imgs.isEmpty ? '' : '${imgs.first}',
      status: (j['status'] ?? 'active').toString(),
      controlaEstoque: j['hasStock'] == true,
      estoque: j['stockQuantity'] == null ? null : _int(j['stockQuantity']),
      temComplementos: j['hasComplements'] == true,
    );
  }

  double get precoValendo => precoPromocional ?? preco;

  bool get disponivel {
    if (status != 'active') return false;
    if (controlaEstoque && (estoque ?? 0) <= 0) return false;
    return true;
  }
}

class OpcaoComplemento {
  final int id;
  final String nome;
  final double preco;
  final double? precoPromocional;
  final bool ativo;
  final bool controlaEstoque;
  final int? estoque;

  const OpcaoComplemento({
    required this.id,
    required this.nome,
    this.preco = 0,
    this.precoPromocional,
    this.ativo = true,
    this.controlaEstoque = false,
    this.estoque,
  });

  factory OpcaoComplemento.fromJson(Map<String, dynamic> j) => OpcaoComplemento(
        id: _int(j['id']),
        nome: (j['name'] ?? '').toString(),
        preco: _num(j['price']),
        precoPromocional:
            j['promotionalPrice'] == null ? null : _num(j['promotionalPrice']),
        ativo: j['isActive'] != false,
        controlaEstoque: j['hasStock'] == true,
        estoque: j['stockQuantity'] == null ? null : _int(j['stockQuantity']),
      );

  double get precoValendo => precoPromocional ?? preco;

  bool get disponivel {
    if (!ativo) return false;
    if (controlaEstoque && (estoque ?? 0) <= 0) return false;
    return true;
  }
}

class GrupoComplemento {
  final int id;
  final int produtoId;
  final String nome;
  final int minimo;
  final int maximo;
  final bool obrigatorio;
  final String tipo;
  final List<OpcaoComplemento> opcoes;

  const GrupoComplemento({
    required this.id,
    required this.produtoId,
    required this.nome,
    this.minimo = 0,
    this.maximo = 0,
    this.obrigatorio = false,
    this.tipo = 'complement',
    this.opcoes = const [],
  });

  factory GrupoComplemento.fromJson(Map<String, dynamic> j) {
    final lista = (j['items'] is List) ? j['items'] as List : const [];
    return GrupoComplemento(
      id: _int(j['id']),
      produtoId: _int(j['productId']),
      nome: (j['name'] ?? '').toString(),
      minimo: _int(j['minQuantity']),
      maximo: _int(j['maxQuantity']),
      obrigatorio: j['isRequired'] == true,
      tipo: (j['groupType'] ?? 'complement').toString(),
      opcoes: lista
          .whereType<Map>()
          .map((e) => OpcaoComplemento.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// nome bonito da forma de pagamento
String formaPagamento(String? p) {
  switch ((p ?? '').toLowerCase()) {
    case 'cash':
    case 'dinheiro':
    case 'money':
      return 'Dinheiro';
    case 'pix':
      return 'PIX';
    case 'card':
    case 'cartao':
    case 'cartão':
    case 'credit':
    case 'debit':
      return 'Cartão';
    default:
      return p == null || p.isEmpty ? '—' : p;
  }
}

/* ================================================================== *
 *  COMANDA FECHADA — o que vem em GET /tables/:id/history
 * ================================================================== */
class ComandaFechada {
  final int id;
  final String numero;
  final String status;
  final double subtotal;
  final double desconto;
  final double taxaServico;
  final double total;
  final String pagamento;
  final double pago;
  final double troco;
  final DateTime? abertaEm;
  final DateTime? fechadaEm;
  final List<ItemComanda> itens;

  const ComandaFechada({
    required this.id,
    this.numero = '',
    this.status = '',
    this.subtotal = 0,
    this.desconto = 0,
    this.taxaServico = 0,
    this.total = 0,
    this.pagamento = '',
    this.pago = 0,
    this.troco = 0,
    this.abertaEm,
    this.fechadaEm,
    this.itens = const [],
  });

  factory ComandaFechada.fromJson(Map<String, dynamic> j) {
    final lista = (j['items'] is List) ? j['items'] as List : const [];
    return ComandaFechada(
      id: _int(j['id']),
      numero: (j['tabNumber'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      subtotal: _num(j['subtotal']),
      desconto: _num(j['discount']),
      taxaServico: _num(j['serviceCharge']),
      total: _num(j['total']),
      pagamento: (j['paymentMethod'] ?? '').toString(),
      pago: _num(j['paidAmount']),
      troco: _num(j['changeAmount']),
      abertaEm: _data(j['openedAt']),
      fechadaEm: _data(j['closedAt']),
      itens: lista
          .whereType<Map>()
          .map((e) => ItemComanda.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// "19/08 às 16:45"
  String get quando {
    final d = fechadaEm ?? abertaEm;
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} às ${dois(d.hour)}:${dois(d.minute)}';
  }

  int get totalDeItens =>
      itens.fold(0, (soma, i) => soma + i.quantidade);
}

/* ================================================================== *
 *  UM PAGAMENTO DA COMANDA
 *  Vem de GET /tables/:id/payments e também dentro do histórico.
 * ================================================================== */
class Pagamento {
  final int id;
  final double valor;
  final String forma;
  final String observacao;
  final String registradoPor;
  final DateTime? quando;

  const Pagamento({
    required this.id,
    this.valor = 0,
    this.forma = '',
    this.observacao = '',
    this.registradoPor = '',
    this.quando,
  });

  factory Pagamento.fromJson(Map<String, dynamic> j) => Pagamento(
        id: _int(j['id']),
        valor: _num(j['amount']),
        forma: (j['paymentMethod'] ?? '').toString(),
        observacao: (j['notes'] ?? '').toString(),
        registradoPor: (j['createdByName'] ?? j['registeredBy'] ?? '')
            .toString(),
        quando: _data(j['createdAt']),
      );

  String get formaBonita => formaPagamento(forma);

  /// "16:45"
  String get hora {
    final d = quando;
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.hour)}:${dois(d.minute)}';
  }
}

/* ================================================================== *
 *  COMANDA NO HISTÓRICO DE GANHOS DO GARÇOM
 *  Vem de GET /api/waiter/history — uma mesa que ELE fechou.
 * ================================================================== */
class ComandaDoGarcom {
  final int id;
  final String mesa;
  final String identificacao;
  final double total;
  final double comissao;
  final bool comissaoPaga;
  final DateTime? fechadaEm;

  /// forma usada no fechamento final
  final String formaDoFechamento;

  /// pagamentos avulsos / parciais que aconteceram nessa comanda
  final List<Pagamento> pagamentos;

  const ComandaDoGarcom({
    required this.id,
    this.mesa = '',
    this.identificacao = '',
    this.total = 0,
    this.comissao = 0,
    this.comissaoPaga = true,
    this.fechadaEm,
    this.formaDoFechamento = '',
    this.pagamentos = const [],
  });

  factory ComandaDoGarcom.fromJson(Map<String, dynamic> j) => ComandaDoGarcom(
        id: _int(j['id']),
        // mesa junta manda displayNumber ("5-6"); mesa normal, tableNumber
        mesa: (j['displayNumber'] ?? j['tableNumber'] ?? j['tabNumber'] ?? '')
            .toString(),
        identificacao: (j['label'] ?? '').toString(),
        total: _num(j['total']),
        // enquanto o servidor não mandar "commission", a taxa de serviço
        // da comanda é a melhor aproximação
        comissao: j['commission'] == null
            ? _num(j['serviceCharge'])
            : _num(j['commission']),
        comissaoPaga: j['commissionPaid'] != false,
        fechadaEm: _data(j['closedAt']),
        formaDoFechamento: (j['paymentMethod'] ?? '').toString(),
        pagamentos: (j['payments'] is List)
            ? (j['payments'] as List)
                .whereType<Map>()
                .map((e) => Pagamento.fromJson(e.cast<String, dynamic>()))
                .toList()
            : const [],
      );

  String get titulo => mesa.isEmpty ? 'Mesa' : 'Mesa $mesa';

  /// "Dinheiro" ou "Dinheiro, Cartão e PIX" — tudo que entrou nessa mesa
  String get formasUsadas {
    final nomes = <String>[];
    for (final p in pagamentos) {
      final n = p.formaBonita;
      if (n.isNotEmpty && n != '—' && !nomes.contains(n)) nomes.add(n);
    }
    final fim = formaPagamento(formaDoFechamento);
    if (fim.isNotEmpty && fim != '—' && !nomes.contains(fim)) nomes.add(fim);

    if (nomes.isEmpty) return '';
    if (nomes.length == 1) return nomes.first;
    return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
  }

  /// quanto entrou em pagamentos avulsos antes do fechamento
  double get totalAvulso =>
      pagamentos.fold(0.0, (soma, p) => soma + p.valor);

  /// "16:45"
  String get hora {
    final d = fechadaEm;
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.hour)}:${dois(d.minute)}';
  }

  /// "19/08 às 16:45"
  String get quando {
    final d = fechadaEm;
    if (d == null) return '';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} às ${dois(d.hour)}:${dois(d.minute)}';
  }
}
