# Edits from the diagram that change lines already written: rename, delete a node, remove an arrow,
# add a node between two, and the manual layout lines. Each line is read on its own with the parser;
# only the lines that mention what changes are rewritten, every other line stays exactly as it was.
import Base
import ./Parser.bend as P
import ./Graph.bend as G

type Emitted is Data:
  Emitted{lines: List<&2, String>, used: List<&2, String>}
type Place is Data:
  Place{id: String, x: Nat, y: Nat}

# ---------- One line on its own ----------

def line_graph(+line: String) -> P.Graph:
  P.parse("flowchart TD\n" ++ line)

def is_header(+line: String) -> Bool:
  String.starts_with(String.trim(line), "flowchart") || String.starts_with(String.trim(line), "graph")

def edges_of(g: P.Graph) -> List<&2, P.Edge>:
  match g:
    case P.Graph{ns, es, error, line}: es

def mentions(+line: String, +id: String) -> Bool:
  Bool.not(is_header(line)) && P.has_node(G.nodes_of(line_graph(line)), id)

def mentions_edge(+line: String, +from: String, +to: String) -> Bool:
  Bool.not(is_header(line)) && G.has_edge(edges_of(line_graph(line)), from, to)

def mention_count.add(here: Bool, +rest: Nat) -> Nat:
  Bool.pick(Nat, here, 1n+rest, rest)

def mention_count(ls: List<&2, String>, +id: String) -> Nat:
  match ls:
    case Nil{}: 0n
    case +l <> t: mention_count.add(mentions(l, id), mention_count(t, id))

# The spaces a line starts with, so a rewritten line keeps its indentation.
def indent_of(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{Chr{+c}, t}: Bool.pick(String, U32.is_eq(c, 32) || U32.is_eq(c, 9), SCon{Chr{c}, indent_of(t)}, SNil{})

# ---------- Writing a line again from what it says ----------



def in_edges(es: List<&2, P.Edge>, +id: String) -> Bool:
  match es:
    case Nil{}: False{}
    case P.Edge{f, t, label} <> rest: String.eq(f, id) || String.eq(t, id) || in_edges(rest, id)




# A rewritten line that says nothing any more is removed.
def keep_unless_empty(+s: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(String.trim(s)), rest, s <> rest)

def lines_of(+source: String) -> List<&2, String>:
  String.lines(source)

def text_of(ls: List<&2, String>) -> String:
  String.join(ls, "\n")

def drop_node.keep(drop: Bool, +n: P.Node, +rest: List<&2, P.Node>) -> List<&2, P.Node>:
  Bool.pick(List<&2, P.Node>, drop, rest, n <> rest)

# ---------- Delete a node: its arrows go with it, and its layout line ----------

def drop_node(ns: List<&2, P.Node>, +id: String) -> List<&2, P.Node>:
  match ns:
    case Nil{}: Nil{}
    case P.Node{+n, +label, +shape} <> t: drop_node.keep(String.eq(n, id), P.Node{n, label, shape}, drop_node(t, id))

def drop_edge.keep(drop: Bool, +e: P.Edge, +rest: List<&2, P.Edge>) -> List<&2, P.Edge>:
  Bool.pick(List<&2, P.Edge>, drop, rest, e <> rest)

def drop_touching(es: List<&2, P.Edge>, +id: String) -> List<&2, P.Edge>:
  match es:
    case Nil{}: Nil{}
    case P.Edge{+f, +t, +label} <> rest:
      drop_edge.keep(String.eq(f, id) || String.eq(t, id), P.Edge{f, t, label}, drop_touching(rest, id))

def member(xs: List<&2, String>, +id: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, id) || member(t, id)

# A node's own label, or "" when it is just its id (a box whose label is its id).
def label_of(ns: List<&2, P.Node>, +id: String) -> String:
  match ns:
    case Nil{}: ""
    case P.Node{+n, +l, +s} <> t: Bool.pick(String, String.eq(n, id), Bool.pick(String, String.eq(n, l) && U32.is_zero(s), "", l), label_of(t, id))

def shape_of(ns: List<&2, P.Node>, +id: String) -> U32:
  match ns:
    case Nil{}: 0
    case P.Node{+n, l, +s} <> t: Bool.pick(U32, String.eq(n, id), s, shape_of(t, id))

def endpoint(+id: String, +ns: List<&2, P.Node>, +used: List<&2, String>) -> String:
  Bool.pick(String, String.is_empty(label_of(ns, id)) || member(used, id), id, G.shaped_text(id, label_of(ns, id), shape_of(ns, id)))

def mark(+id: String, +ns: List<&2, P.Node>, +used: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(label_of(ns, id)) || member(used, id), used, id <> used)

def arrow(+from: String, +label: String, +to: String) -> String:
  Bool.pick(String, String.is_empty(label), from ++ " --> " ++ to, from ++ " -->|" ++ label ++ "| " ++ to)


def emitted_cons(+s: String, e: Emitted) -> Emitted:
  match e:
    case Emitted{ls, u}: Emitted{s <> ls, u}

def edge_statements(es: List<&2, P.Edge>, +ns: List<&2, P.Node>, +used: List<&2, String>) -> Emitted:
  match es:
    case Nil{}: Emitted{Nil{}, used}
    case P.Edge{+f, +t, +label} <> rest:
      emitted_cons(arrow(endpoint(f, ns, used), label, endpoint(t, ns, mark(f, ns, used))), edge_statements(rest, ns, mark(t, ns, mark(f, ns, used))))

def node_statements.keep(written: Bool, +statement: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, written, statement <> rest, rest)

# A node gets its own line when its label wasn't written on an arrow, or when nothing else would keep it
# in the diagram: no arrow left on this line and no other line that mentions it.
def node_statements(ns: List<&2, P.Node>, +es: List<&2, P.Edge>, +all: List<&2, String>, +used: List<&2, String>) -> List<&2, String>:
  match ns:
    case Nil{}: Nil{}
    case P.Node{+id, +label, +shape} <> t:
      node_statements.keep(Bool.not(member(used, id)) && (Bool.not(String.eq(id, label) && U32.is_zero(shape)) || (Bool.not(in_edges(es, id)) && (mention_count(all, id) <= 1n : Nat))),
        Bool.pick(String, String.eq(id, label) && U32.is_zero(shape), id, G.shaped_text(id, label, shape)), node_statements(t, es, all, used))

def append(xs: List<&2, String>, ys: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: ys
    case x <> t: x <> append(t, ys)

# The classes the line gave its nodes are written back as `id:::name`, for the nodes still on it.
def class_statements(cs: List<&2, P.Class>, +ns: List<&2, P.Node>) -> List<&2, String>:
  match cs:
    case Nil{}: Nil{}
    case P.Class{+id, +name} <> t: node_statements.keep(P.has_node(ns, id), id ++ ":::" ++ name, class_statements(t, ns))

def emit.go(+indent: String, e: Emitted, +ns: List<&2, P.Node>, +es: List<&2, P.Edge>, +all: List<&2, String>, cs: List<&2, P.Class>) -> String:
  match e:
    case Emitted{lines, +used}: indent ++ String.join(append(append(lines, node_statements(ns, es, all, used)), class_statements(cs, ns)), "\n" ++ indent)

def emit(+indent: String, +ns: List<&2, P.Node>, +es: List<&2, P.Edge>, +all: List<&2, String>, cs: List<&2, P.Class>) -> String:
  emit.go(indent, edge_statements(es, ns, Nil{}), ns, es, all, cs)

def drop_classes_of.keep(drop: Bool, +c: P.Class, +rest: List<&2, P.Class>) -> List<&2, P.Class>:
  Bool.pick(List<&2, P.Class>, drop, rest, c <> rest)

def drop_classes_of(cs: List<&2, P.Class>, +id: String, +tones_only: Bool) -> List<&2, P.Class>:
  match cs:
    case Nil{}: Nil{}
    case P.Class{+n, +name} <> t:
      drop_classes_of.keep(String.eq(n, id) && (Bool.not(tones_only) || Bool.not(String.is_empty(G.tone_name(name)))), P.Class{n, name}, drop_classes_of(t, id, tones_only))

def without_node_line.go(+indent: String, g: P.Graph, +id: String, +all: List<&2, String>, cs: List<&2, P.Class>) -> String:
  match g:
    case P.Graph{ns, +es, error, l}: emit(indent, drop_node(ns, id), drop_touching(es, id), all, cs)

def without_node_line(+line: String, +id: String, +all: List<&2, String>) -> String:
  without_node_line.go(indent_of(line), line_graph(line), id, all, drop_classes_of(P.classes(line), id, False{}))

def is_place_of(+line: String, +id: String) -> Bool:
  String.starts_with(String.trim(line), "%% borzoi " ++ id ++ " ")

def without_node.keep(place: Bool, mentioned: Bool, +l: String, +rewritten: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, place, rest, Bool.pick(List<&2, String>, mentioned, keep_unless_empty(rewritten, rest), l <> rest))

def without_node(ls: List<&2, String>, +id: String, +all: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_node.keep(is_place_of(l, id), mentions(l, id), l, without_node_line(l, id, all), without_node(t, id, all))

def delete_node(+source: String, +id: String) -> String:
  text_of(without_node(lines_of(source), id, lines_of(source)))

# ---------- Remove an arrow: both nodes stay ----------

def drop_edge(es: List<&2, P.Edge>, +from: String, +to: String) -> List<&2, P.Edge>:
  match es:
    case Nil{}: Nil{}
    case P.Edge{+f, +t, +label} <> rest:
      drop_edge.keep(String.eq(f, from) && String.eq(t, to), P.Edge{f, t, label}, drop_edge(rest, from, to))

def without_edge_line.go(+indent: String, g: P.Graph, +from: String, +to: String, +all: List<&2, String>, cs: List<&2, P.Class>) -> String:
  match g:
    case P.Graph{ns, es, error, l}: emit(indent, ns, drop_edge(es, from, to), all, cs)

def without_edge_line(+line: String, +from: String, +to: String, +all: List<&2, String>) -> String:
  without_edge_line.go(indent_of(line), line_graph(line), from, to, all, P.classes(line))

def without_edge.keep(mentioned: Bool, +l: String, +rewritten: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, mentioned, keep_unless_empty(rewritten, rest), l <> rest)

def without_edge(ls: List<&2, String>, +from: String, +to: String, +all: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_edge.keep(mentions_edge(l, from, to), l, without_edge_line(l, from, to, all), without_edge(t, from, to, all))

def remove_edge(+source: String, +from: String, +to: String) -> String:
  text_of(without_edge(lines_of(source), from, to, lines_of(source)))


def relabel(ns: List<&2, P.Node>, +id: String, +label: String) -> List<&2, P.Node>:
  match ns:
    case Nil{}: Nil{}
    case P.Node{+n, old, +shape} <> t: Bool.pick(P.Node, String.eq(n, id), P.Node{n, label, shape}, P.Node{n, old, shape}) <> relabel(t, id, label)

def labels(ns: List<&2, P.Node>, +id: String) -> Bool:
  match ns:
    case Nil{}: False{}
    case P.Node{+n, +label, shape} <> t: (String.eq(n, id) && Bool.not(String.eq(n, label))) || labels(t, id)

# A line labels a node when it gives it a label different from its id, or writes it with brackets
# (`Idea["Idea"]` reads the same as `Idea`, but it is where the label lives; so is `Idea{Idea}`).
def labels_node(+line: String, +id: String) -> Bool:
  Bool.not(is_header(line)) && P.has_node(G.nodes_of(line_graph(line)), id) && (labels(G.nodes_of(line_graph(line)), id) || String.contains(line, id ++ "[") || String.contains(line, id ++ "{"))

def any_labels(ls: List<&2, String>, +id: String) -> Bool:
  match ls:
    case Nil{}: False{}
    case +l <> t: labels_node(l, id) || any_labels(t, id)

def relabel_line.go(+indent: String, g: P.Graph, +id: String, +label: String, +all: List<&2, String>, cs: List<&2, P.Class>) -> String:
  match g:
    case P.Graph{ns, +es, error, l}: emit(indent, relabel(ns, id, label), es, all, cs)

def relabel_line(+line: String, +id: String, +label: String, +all: List<&2, String>) -> String:
  relabel_line.go(indent_of(line), line_graph(line), id, label, all, P.classes(line))

def relabel_lines(ls: List<&2, String>, +id: String, +label: String, +all: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: Bool.pick(String, labels_node(l, id), relabel_line(l, id, label, all), l) <> relabel_lines(t, id, label, all)

# With no line that labels the node yet, the label is written once at the end.
def rename(+source: String, +id: String, +label: String) -> String:
  Bool.pick(String, any_labels(lines_of(source), id),
    text_of(relabel_lines(lines_of(source), id, label, lines_of(source))),
    G.rename_node(source, id, label))

# ---------- Manual layout: `%% borzoi manual` and one `%% borzoi <id> <x> <y>` line per node ----------
# Mermaid ignores %% lines, so other tools read the same diagram and lay it out on their own.


def is_manual_line(+line: String) -> Bool:
  String.eq(String.trim(line), "%% borzoi manual")

def any_manual(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}: False{}
    case +l <> t: is_manual_line(l) || any_manual(t)

def is_manual(+source: String) -> Bool:
  any_manual(lines_of(source))

def without_manual.keep(drop: Bool, +l: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, drop, rest, l <> rest)

def without_manual(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_manual.keep(is_manual_line(l), l, without_manual(t))

def set_manual(+source: String, on: Bool) -> String:
  match on:
    case True{}: Bool.pick(String, is_manual(source), source, G.write_line(source, "%% borzoi manual"))
    case False{}: text_of(without_manual(lines_of(source)))

def digit(+c: U32) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, (c >= 48 : U32) && (c <= 57 : U32), Some{U32.to_nat((c - 48 : U32))}, None{})

def digits.add(d: Maybe<&2, Nat>, rest: Maybe<&2, List<&2, Nat>>) -> Maybe<&2, List<&2, Nat>>:
  match d rest:
    case Some{n} Some{ns}: Some{n <> ns}
    case _ _: None{}

def digits(s: String) -> Maybe<&2, List<&2, Nat>>:
  match s:
    case SNil{}: Some{Nil{}}
    case SCon{Chr{+c}, t}: digits.add(digit(c), digits(t))

def value(ds: List<&2, Nat>, +acc: Nat) -> Nat:
  match ds:
    case Nil{}: acc
    case d <> t: value(t, (acc * 10n + d : Nat))

def number.of(ds: Maybe<&2, List<&2, Nat>>) -> Maybe<&2, Nat>:
  match ds:
    case None{}: None{}
    case Some{Nil{}}: None{}
    case Some{d <> t}: Some{value(d <> t, 0n)}

def number(s: String) -> Maybe<&2, Nat>:
  number.of(digits(s))

def words.keep(ws: List<&2, String>) -> List<&2, String>:
  match ws:
    case Nil{}: Nil{}
    case +w <> t: without_manual.keep(String.is_empty(w), w, words.keep(t))

def words(+s: String) -> List<&2, String>:
  words.keep(String.split(String.trim(s), ' '))

def place_of.go(ok: Bool, id: String, x: Maybe<&2, Nat>, y: Maybe<&2, Nat>) -> Maybe<&2, Place>:
  match ok x y:
    case True{} Some{a} Some{b}: Some{Place{id, a, b}}
    case _ _ _: None{}

def place_of(ws: List<&2, String>) -> Maybe<&2, Place>:
  match ws:
    case +a <> +b <> id <> x <> y <> Nil{}:
      place_of.go(String.eq(a, "%%") && String.eq(b, "borzoi"), id, number(x), number(y))
    case _: None{}

def places.add(p: Maybe<&2, Place>, rest: List<&2, Place>) -> List<&2, Place>:
  match p:
    case None{}: rest
    case Some{x}: x <> rest

def places.go(ls: List<&2, String>) -> List<&2, Place>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: places.add(place_of(words(l)), places.go(t))

# Every saved position in the source, in order.
def places(+source: String) -> List<&2, Place>:
  places.go(lines_of(source))

def place_line(id: String, +x: Nat, +y: Nat) -> String:
  "%% borzoi " ++ id ++ " " ++ Nat.show(x) ++ " " ++ Nat.show(y)

def without_place(ls: List<&2, String>, +id: String) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_manual.keep(is_place_of(l, id), l, without_place(t, id))

def has_place(ls: List<&2, String>, +id: String) -> Bool:
  match ls:
    case Nil{}: False{}
    case +l <> t: is_place_of(l, id) || has_place(t, id)

def replace_place(ls: List<&2, String>, +id: String, +line: String) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: Bool.pick(String, is_place_of(l, id), indent_of(l) ++ line, l) <> replace_place(t, id, line)

# Moving a node rewrites its own position line, or writes one at the end.
def move_node(+source: String, +id: String, +x: Nat, +y: Nat) -> String:
  Bool.pick(String, has_place(lines_of(source), id),
    text_of(replace_place(lines_of(source), id, place_line(id, x, y))),
    G.write_line(source, place_line(id, x, y)))

# ---------- Writing a line again from what it says ----------
# Arrows first, each node's label inline at its first appearance; then the nodes that need a line of their own.


# ---------- Add a node between two connected nodes: the arrow's label goes to the first new arrow ----------

def edge_label(es: List<&2, P.Edge>, +from: String, +to: String) -> String:
  match es:
    case Nil{}: ""
    case P.Edge{+f, +t, +label} <> rest: Bool.pick(String, String.eq(f, from) && String.eq(t, to), label, edge_label(rest, from, to))

def insert_between.go(+source: String, +from: String, +to: String, +label: String, +id: String, +old: String) -> String:
  remove_edge(G.write_line(G.write_line(source, arrow(from, old, G.node_text(id, label))), id ++ " --> " ++ to), from, to)

def insert_between(+source: String, +from: String, +to: String, +label: String) -> String:
  insert_between.go(source, from, to, label, G.readable_id(source, label), edge_label(edges_of(G.parse(source)), from, to))

# ---------- Color a node: its tone classes go, `id:::tone` is written at the end, with its classDef once ----------

def has_tone_of(cs: List<&2, P.Class>, +id: String) -> Bool:
  match cs:
    case Nil{}: False{}
    case P.Class{+n, +name} <> t: (String.eq(n, id) && Bool.not(String.is_empty(G.tone_name(name)))) || has_tone_of(t, id)

def without_tone_line.go(+indent: String, g: P.Graph, +all: List<&2, String>, cs: List<&2, P.Class>) -> String:
  match g:
    case P.Graph{+ns, +es, error, l}: emit(indent, ns, es, all, cs)

def without_tone_line(+line: String, +id: String, +all: List<&2, String>) -> String:
  without_tone_line.go(indent_of(line), line_graph(line), all, drop_classes_of(P.classes(line), id, True{}))

def without_tone(ls: List<&2, String>, +id: String, +all: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_edge.keep(has_tone_of(P.classes(l), id), l, without_tone_line(l, id, all), without_tone(t, id, all))

def has_definition(ls: List<&2, String>, +tone: String) -> Bool:
  match ls:
    case Nil{}: False{}
    case +l <> t: String.starts_with(String.trim(l), "classDef " ++ tone ++ " ") || has_definition(t, tone)

def with_definition(+source: String, +tone: String) -> String:
  Bool.pick(String, has_definition(lines_of(source), tone), source, G.write_line(source, "classDef " ++ tone ++ " " ++ G.tone_style(tone)))

# A classDef for one of the four tones goes away once no node uses that tone.
def uses(cs: List<&2, P.Class>, +name: String) -> Bool:
  match cs:
    case Nil{}: False{}
    case P.Class{id, n} <> t: String.eq(n, name) || uses(t, name)

# The color class a classDef line defines, or "" for any other line.
def definition_class(ws: List<&2, String>) -> String:
  match ws:
    case +k <> +name <> rest: Bool.pick(String, String.eq(k, "classDef") && Bool.not(String.is_empty(G.tone_name(name))), name, "")
    case _: ""

def unused_definition(+line: String, +cs: List<&2, P.Class>) -> Bool:
  Bool.not(String.is_empty(definition_class(words(line)))) && Bool.not(uses(cs, definition_class(words(line))))

def prune(ls: List<&2, String>, +cs: List<&2, P.Class>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_manual.keep(unused_definition(l, cs), l, prune(t, cs))

def pruned(+source: String) -> String:
  text_of(prune(lines_of(source), P.classes(source)))

def set_tone.go(+clean: String, +id: String, +tone: String) -> String:
  pruned(Bool.pick(String, String.is_empty(G.tone_name(tone)), clean, with_definition(G.write_line(clean, id ++ ":::" ++ tone), tone)))

# A name that isn't a color (e.g. "") just removes the node's color.
def set_tone(+source: String, +id: String, +tone: String) -> String:
  set_tone.go(text_of(without_tone(lines_of(source), id, lines_of(source))), id, tone)
