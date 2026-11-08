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

# ---------- Writing from the diagram: every action is one Mermaid line after everything already written ----------

# The source a line is added to: an empty source starts as a flowchart.
def base(+source: String) -> String:
  Bool.pick(String, String.is_empty(source), "flowchart TD", source)

def line_break(+source: String) -> String:
  Bool.pick(String, String.ends_with(source, "\n"), "", "\n")

# One new line at the end. Nothing already written changes.
def write_line(+source: String, line: String) -> String:
  base(source) ++ line_break(base(source)) ++ "  " ++ line

# A label in double quotes, so any text is a valid label; a double quote inside becomes a single one.
def quote_safe(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{Chr{+c}, t}: SCon{Chr{Bool.pick(U32, U32.is_eq(c, 34), 39, c)}, quote_safe(t)}

def node_text(id: String, label: String) -> String:
  id ++ "[\"" ++ quote_safe(String.trim(label)) ++ "\"]"

def nodes_of(g: P.Graph) -> List<&2, P.Node>:
  match g:
    case P.Graph{ns, es, error, line}: ns

# The first of N1, N2, … that no node uses yet.
def fresh_id.go(fuel: Nat, +ns: List<&2, P.Node>, +k: Nat) -> String:
  match fuel:
    case 0n: "N" ++ Nat.show(k)
    case 1n+f: Bool.pick(String, P.has_node(ns, "N" ++ Nat.show(k)), fresh_id.go(f, ns, 1n+k), "N" ++ Nat.show(k))

def fresh_id(+source: String) -> String:
  +ns = nodes_of(P.parse(source))
  fresh_id.go(1n+count_nodes(ns), ns, 1n)

# The actions of the diagram's menu and drag.
def connect(+source: String, from: String, to: String) -> String:
  write_line(source, from ++ " --> " ++ to)

def add_node(+source: String, label: String) -> String:
  write_line(source, node_text(fresh_id(source), label))

def add_node_below(+source: String, from: String, label: String) -> String:
  write_line(source, from ++ " --> " ++ node_text(fresh_id(source), label))

# Mermaid keeps a node's last label, so renaming is the node written again with its new label.
def rename_node(+source: String, id: String, label: String) -> String:
  write_line(source, node_text(id, label))

def has_edge(es: List<&2, P.Edge>, +from: String, +to: String) -> Bool:
  match es:
    case Nil{}: False{}
    case P.Edge{f, t, label} <> rest:
      (String.eq(f, from) && String.eq(t, to)) || has_edge(rest, from, to)

def graph_has_edge(g: P.Graph, +from: String, +to: String) -> Bool:
  match g:
    case P.Graph{ns, es, error, line}: has_edge(es, from, to)

# A connection is allowed when the source is valid now, the ends differ, the arrow isn't there yet,
# and the source stays valid with it (no loop, within the size limits).
def can_connect(+source: String, +from: String, +to: String) -> Bool:
  P.is_valid(parse(source)) && Bool.not(String.eq(from, to)) && Bool.not(graph_has_edge(parse(source), from, to)) && P.is_valid(parse(connect(source, from, to)))
