# Validate the subset before passing it to Bend-UI's top-to-bottom layout.
import Base
import ./Parser.bend as P
import ../vendor/bend-ui/DIAGRAM.bend as D

def count_nodes(ns: List<&2, P.Node>) -> Nat:
  match ns:
    case Nil{}: 0n
    case h <> t: 1n+count_nodes(t)

def count_edges(es: List<&2, P.Edge>) -> Nat:
  match es:
    case Nil{}: 0n
    case h <> t: 1n+count_edges(t)

def index_of(ns: List<&2, P.Node>, +id: String, +index: Nat) -> Nat:
  match ns:
    case Nil{}: index
    case P.Node{n, label} <> t:
      Bool.pick(Nat, String.eq(n, id), index, index_of(t, id, 1n+index))

def layout_edges(es: List<&2, P.Edge>, +ns: List<&2, P.Node>) -> List<&2, D.Edge>:
  match es:
    case Nil{}: Nil{}
    case P.Edge{f, t, label} <> rest:
      D.Edge{index_of(ns, f, 0n), index_of(ns, t, 0n)} <> layout_edges(rest, ns)

def all_forward(es: List<&2, D.Edge>, +rows: List<&2, Nat>) -> Bool:
  match es:
    case Nil{}: True{}
    case D.Edge{f, t} <> rest: (D.get(rows, f) < D.get(rows, t) : Nat) && all_forward(rest, rows)

def check_layout(+g: P.Graph, forward: Bool) -> P.Graph:
  match forward:
    case True{}: g
    case False{}: P.Graph{Nil{}, Nil{}, "Return loops are not supported in this first version. Your source is still saved.", 0n}

def check_size(g: P.Graph, fits: Bool) -> P.Graph:
  match g fits:
    case P.Graph{+ns, +es, error, line} False{}:
      P.Graph{Nil{}, Nil{}, "This version supports up to 60 nodes and 120 connections per diagram.", 0n}
    case P.Graph{+ns, +es, error, line} True{}:
      +connections = layout_edges(es, ns)
      check_layout(P.Graph{ns, es, error, line}, all_forward(connections, D.rows(count_nodes(ns), connections)))

def validate(g: P.Graph) -> P.Graph:
  match g:
    case P.Graph{+ns, +es, SNil{}, line}:
      check_size(P.Graph{ns, es, "", line}, (count_nodes(ns) <= 60n : Nat) && (count_edges(es) <= 120n : Nat))
    case P.Graph{ns, es, SCon{h, t}, line}: P.Graph{ns, es, SCon{h, t}, line}

def parse(source: String) -> P.Graph:
  validate(P.parse(source))
