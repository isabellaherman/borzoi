# Validate the subset before passing it to Bend-UI's top-to-bottom layout.
import Base
import ./Parser.bend as P
import ../vendor/bend-ui/DIAGRAM.bend as D
import ../vendor/bend-ui/TOKENS.bend as T

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



# Accented Latin letters lose their accent; the id keeps letters, digits and _.
def plain(+c: U32) -> U32:
  match c:
    case 224: 97
    case 225: 97
    case 226: 97
    case 227: 97
    case 228: 97
    case 192: 65
    case 193: 65
    case 194: 65
    case 195: 65
    case 196: 65
    case 232: 101
    case 233: 101
    case 234: 101
    case 235: 101
    case 200: 69
    case 201: 69
    case 202: 69
    case 236: 105
    case 237: 105
    case 238: 105
    case 239: 105
    case 205: 73
    case 242: 111
    case 243: 111
    case 244: 111
    case 245: 111
    case 246: 111
    case 211: 79
    case 212: 79
    case 213: 79
    case 249: 117
    case 250: 117
    case 251: 117
    case 252: 117
    case 218: 85
    case 220: 85
    case 231: 99
    case 199: 67
    case 241: 110
    case 209: 78
    case x: x

def id_char(+c: U32) -> U32:
  Bool.pick(U32, Char.is_alpha(Chr{plain(c)}) || Char.is_digit(Chr{plain(c)}), plain(c), 95)

def id_chars(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{Chr{+c}, t}: SCon{Chr{id_char(c)}, id_chars(t)}

def non_empty.keep(+w: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(w), rest, w <> rest)

def non_empty(ws: List<&2, String>) -> List<&2, String>:
  match ws:
    case Nil{}: Nil{}
    case +w <> t: non_empty.keep(w, non_empty(t))

def starts_with_digit(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{h, t}: Char.is_digit(h)

def id_base.fix(+s: String) -> String:
  Bool.pick(String, String.is_empty(s), "Node",
    Bool.pick(String, String.eq(String.to_lower(s), "end"), s ++ "_node",
      Bool.pick(String, starts_with_digit(s), "N" ++ s, s)))

# "Next step" → Next_step; one that starts with a digit gets an N; "end" is a Mermaid word, so it becomes end_node.
def id_base(+label: String) -> String:
  id_base.fix(String.join(non_empty(String.split(id_chars(String.trim(label)), '_')), "_"))

def readable_id.go(fuel: Nat, +ns: List<&2, P.Node>, +base: String, +k: Nat) -> String:
  match fuel:
    case 0n: base ++ "_" ++ Nat.show(k)
    case 1n+f: Bool.pick(String, P.has_node(ns, base ++ "_" ++ Nat.show(k)), readable_id.go(f, ns, base, 1n+k), base ++ "_" ++ Nat.show(k))

def readable_id.pick(+ns: List<&2, P.Node>, +base: String) -> String:
  Bool.pick(String, P.has_node(ns, base), readable_id.go(1n+count_nodes(ns), ns, base, 2n), base)

# The name as an id, with _2, _3, … when that id is taken.
def readable_id(+source: String, +label: String) -> String:
  readable_id.pick(nodes_of(P.parse(source)), id_base(label))

# The actions of the diagram's menu and drag.
def connect(+source: String, from: String, to: String) -> String:
  write_line(source, from ++ " --> " ++ to)

def add_node(+source: String, +label: String) -> String:
  write_line(source, node_text(readable_id(source, label), label))

def add_node_below(+source: String, from: String, +label: String) -> String:
  write_line(source, from ++ " --> " ++ node_text(readable_id(source, label), label))

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

# ---------- Colors: blue, green, yellow and red, the lib's four tones (accent, success, warning, danger), written as Mermaid classes (`A:::green`) ----------

# A color is written by its common name; each one is one of the lib's tones.
def color_tone(+name: String) -> String:
  Bool.pick(String, String.eq(name, "blue"), "accent",
    Bool.pick(String, String.eq(name, "green"), "success",
      Bool.pick(String, String.eq(name, "yellow"), "warning",
        Bool.pick(String, String.eq(name, "red"), "danger", ""))))

def tone_name(+name: String) -> String:
  color_tone(name)

type Tone is Data:
  Tone{id: String, tone: String}

def tones.keep(+tone: String, id: String, +rest: List<&2, Tone>) -> List<&2, Tone>:
  Bool.pick(List<&2, Tone>, String.is_empty(tone), rest, Tone{id, tone} <> rest)

def tones.go(cs: List<&2, P.Class>) -> List<&2, Tone>:
  match cs:
    case Nil{}: Nil{}
    case P.Class{id, +name} <> t: tones.keep(tone_name(name), id, tones.go(t))

# Every node's tone class, in order; the last one a node gets is its color.
def tones(source: String) -> List<&2, Tone>:
  tones.go(P.classes(source))

def tone_soft(+tone: String) -> String:
  Bool.pick(String, String.eq(tone, "accent"), T.color_accent_soft(), Bool.pick(String, String.eq(tone, "success"), T.color_success_soft(), Bool.pick(String, String.eq(tone, "warning"), T.color_warning_soft(), T.color_danger_soft())))

def tone_strong(+tone: String) -> String:
  Bool.pick(String, String.eq(tone, "accent"), T.color_accent(), Bool.pick(String, String.eq(tone, "success"), T.color_success(), Bool.pick(String, String.eq(tone, "warning"), T.color_warning(), T.color_danger())))

# How a color class looks in other Mermaid tools: the lib's own colors, from TOKENS.bend.
def tone_style(+name: String) -> String:
  "fill:" ++ tone_soft(tone_name(name)) ++ ",stroke:" ++ tone_strong(tone_name(name))
