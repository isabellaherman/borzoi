# A deliberately bounded Mermaid flowchart parser. No Mermaid runtime is used.
import Base

type Token is Data:
  Token{kind: U32, text: String, line: Nat}
type Lexed is Data:
  Lexed{tokens: List<&2, Token>, error: String, line: Nat}
# shape 0 is a box, A[text]; shape 1 is a decision, A{text}.
type Node is Data:
  Node{id: String, label: String, shape: U32}
type Edge is Data:
  Edge{from: String, to: String, label: String}
type Graph is Data:
  Graph{nodes: List<&2, Node>, edges: List<&2, Edge>, error: String, line: Nat}

def push_word(word: String, +line: Nat, acc: List<&2, Token>) -> List<&2, Token>:
  match word:
    case SNil{}: acc
    case SCon{h, t}:
      +text = String.reverse(SCon{h, t})
      Token{Bool.pick(U32, String.eq(text, "end"), 5, 0), text, line} <> acc

def reverse_tokens(xs: List<&2, Token>, acc: List<&2, Token>) -> List<&2, Token>:
  match xs:
    case Nil{}: acc
    case h <> t: reverse_tokens(t, h <> acc)

type Lexer is Data:
  Lexer{mode: U32, word: String, tokens: List<&2, Token>, line: Nat, error: String}

def lexer_error(line: Nat, message: String) -> Lexer:
  Lexer{0, "", Nil{}, line, message}

def free_step(code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 45: Lexer{6, "", push_word(word, line, acc), line, ""}
    case 37: Lexer{8, "", push_word(word, line, acc), line, ""}
    case 91: Lexer{1, "", push_word(word, line, acc), line, ""}
    case 123: Lexer{12, "", push_word(word, line, acc), line, ""}
    case 124: Lexer{3, "", push_word(word, line, acc), line, ""}
    case 58: Lexer{9, "", push_word(word, line, acc), line, ""}
    case 10: Lexer{0, "", Token{4, "", line} <> push_word(word, line, acc), 1n+line, ""}
    case 59: Lexer{0, "", Token{4, "", line} <> push_word(word, line, acc), line, ""}
    case 32: Lexer{0, "", push_word(word, line, acc), line, ""}
    case 9: Lexer{0, "", push_word(word, line, acc), line, ""}
    case 13: Lexer{0, "", push_word(word, line, acc), line, ""}
    case +c:
      Bool.pick(Lexer, Char.is_alpha(Chr{c}) || Char.is_digit(Chr{c}) || U32.is_eq(c, 95),
        Lexer{0, SCon{Chr{c}, word}, acc, line, ""},
        lexer_error(line, "Unsupported syntax. Use node IDs, [labels], --> and |edge labels|."))

# A label is read the same way in a box, A[text] (shape 0), and in a decision, A{text} (shape 1).
def close_of(s: U32) -> U32:
  match s:
    case 0: 93
    case _: 125

def open_of(s: U32) -> U32:
  match s:
    case 0: 91
    case _: 123

def plain_mode(s: U32) -> U32:
  match s:
    case 0: 1
    case _: 12

def quoted_mode(s: U32) -> U32:
  match s:
    case 0: 2
    case _: 13

def after_mode(s: U32) -> U32:
  match s:
    case 0: 4
    case _: 14

def label_kind(s: U32) -> U32:
  match s:
    case 0: 1
    case _: 7

def nested_message(s: U32) -> String:
  match s:
    case 0: "Put a label containing brackets inside double quotes."
    case _: "Put a label containing braces inside double quotes."

def close_message(s: U32) -> String:
  match s:
    case 0: "Expected ] after a quoted label."
    case _: "Expected } after a quoted label."

def plain_label_step(code: U32, +word: String, +acc: List<&2, Token>, +line: Nat, +s: U32) -> Lexer:
  match code:
    case 34:
      Bool.pick(Lexer, String.is_empty(String.trim(word)), Lexer{quoted_mode(s), "", acc, line, ""}, lexer_error(line, "Put quotes around the whole label."))
    case 10: lexer_error(line, "Keep each label on one line.")
    case +c:
      Bool.pick(Lexer, U32.is_eq(c, close_of(s)), Lexer{0, "", Token{label_kind(s), String.trim(String.reverse(word)), line} <> acc, line, ""},
        Bool.pick(Lexer, U32.is_eq(c, open_of(s)), lexer_error(line, nested_message(s)), Lexer{plain_mode(s), SCon{Chr{c}, word}, acc, line, ""}))

def quoted_step(code: U32, word: String, acc: List<&2, Token>, line: Nat, +s: U32) -> Lexer:
  match code:
    case 34: Lexer{after_mode(s), word, acc, line, ""}
    case 10: lexer_error(line, "Keep each label on one line.")
    case c: Lexer{quoted_mode(s), SCon{Chr{c}, word}, acc, line, ""}

def after_quote_step(code: U32, +word: String, +acc: List<&2, Token>, +line: Nat, +s: U32) -> Lexer:
  match code:
    case 32: Lexer{after_mode(s), word, acc, line, ""}
    case 9: Lexer{after_mode(s), word, acc, line, ""}
    case +c:
      Bool.pick(Lexer, U32.is_eq(c, close_of(s)), Lexer{0, "", Token{label_kind(s), String.reverse(word), line} <> acc, line, ""}, lexer_error(line, close_message(s)))

def edge_label_step(code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 124: Lexer{0, "", Token{3, String.trim(String.reverse(word)), line} <> acc, line, ""}
    case 10: lexer_error(line, "Close the connection label with |.")
    case c: Lexer{3, SCon{Chr{c}, word}, acc, line, ""}

# A class after a node, Mermaid's `A:::name`: the name is a Token{6}; the character that ends it is read as usual.
def class_end(code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match word:
    case SNil{}: lexer_error(line, "Write a class name after :::.")
    case SCon{h, t}: free_step(code, "", Token{6, String.reverse(SCon{h, t}), line} <> acc, line)

def class_step.go(more: Bool, +code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match more:
    case True{}: Lexer{11, SCon{Chr{code}, word}, acc, line, ""}
    case False{}: class_end(code, word, acc, line)

def class_step(+code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  class_step.go(Char.is_alpha(Chr{code}) || Char.is_digit(Chr{code}) || U32.is_eq(code, 95), code, word, acc, line)

# Text in the middle of an arrow, Mermaid's `A -- text --> B`: read up to the `-->` that ends it. It becomes
# the same tokens as `A -->|text| B`.
def two_dashes(w: String) -> Bool:
  match w:
    case SCon{Chr{a}, SCon{Chr{b}, r}}: U32.is_eq(a, 45) && U32.is_eq(b, 45)
    case _: False{}

def drop_two(w: String) -> String:
  match w:
    case SCon{a, SCon{b, r}}: r
    case _: SNil{}

def arrow_text_end(done: Bool, +word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match done:
    case True{}: Lexer{0, "", Token{3, String.trim(String.reverse(drop_two(word))), line} <> Token{2, "", line} <> acc, line, ""}
    case False{}: Lexer{15, SCon{Chr{62}, word}, acc, line, ""}

def arrow_text_step(code: U32, +word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 62: arrow_text_end(two_dashes(word), word, acc, line)
    case 10: lexer_error(line, "End the arrow text with -->, as in A -- yes --> B.")
    case c: Lexer{15, SCon{Chr{c}, word}, acc, line, ""}

def arrow_step(code: U32, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 62: Lexer{0, "", Token{2, "", line} <> acc, line, ""}
    case 45: lexer_error(line, "Use --> for a directed connection.")
    case 10: lexer_error(line, "Use --> for a directed connection.")
    case c: Lexer{15, SCon{Chr{c}, SNil{}}, acc, line, ""}

def step(mode: U32, +code: U32, word: String, +acc: List<&2, Token>, +line: Nat) -> Lexer:
  match mode:
    case 0: free_step(code, word, acc, line)
    case 1: plain_label_step(code, word, acc, line, 0)
    case 2: quoted_step(code, word, acc, line, 0)
    case 3: edge_label_step(code, word, acc, line)
    case 4: after_quote_step(code, word, acc, line, 0)
    case 5:
      Bool.pick(Lexer, U32.is_eq(code, 10), Lexer{0, "", Token{4, "", line} <> acc, 1n+line, ""}, Lexer{5, "", acc, line, ""})
    case 6:
      Bool.pick(Lexer, U32.is_eq(code, 45), Lexer{7, "", acc, line, ""}, lexer_error(line, "Use --> for a directed connection."))
    case 7: arrow_step(code, acc, line)
    case 8:
      Bool.pick(Lexer, U32.is_eq(code, 37), Lexer{5, "", acc, line, ""}, lexer_error(line, "Comments begin with %% ."))
    case 9:
      Bool.pick(Lexer, U32.is_eq(code, 58), Lexer{10, "", acc, line, ""}, lexer_error(line, "Use ::: before a class name."))
    case 10:
      Bool.pick(Lexer, U32.is_eq(code, 58), Lexer{11, "", acc, line, ""}, lexer_error(line, "Use ::: before a class name."))
    case 11: class_step(code, word, acc, line)
    case 12: plain_label_step(code, word, acc, line, 1)
    case 13: quoted_step(code, word, acc, line, 1)
    case 14: after_quote_step(code, word, acc, line, 1)
    case 15: arrow_text_step(code, word, acc, line)
    case _: lexer_error(line, "Unknown lexer state.")

def scan(s: String, state: Lexer) -> Lexer:
  match s state:
    case SNil{} st: st
    case SCon{h, t} Lexer{mode, word, acc, line, SNil{}}:
      scan(t, step(mode, Char.to_u32(h), word, acc, line))
    case SCon{h, t} st: st

def finish(state: Lexer) -> Lexed:
  match state:
    case Lexer{0, word, acc, +line, SNil{}}: Lexed{reverse_tokens(push_word(word, line, acc), Nil{}), "", line}
    case Lexer{5, word, acc, line, SNil{}}: Lexed{reverse_tokens(acc, Nil{}), "", line}
    case Lexer{9, word, acc, line, SNil{}}: Lexed{Nil{}, "Write a class name after :::.", line}
    case Lexer{10, word, acc, line, SNil{}}: Lexed{Nil{}, "Write a class name after :::.", line}
    case Lexer{11, SNil{}, acc, line, SNil{}}: Lexed{Nil{}, "Write a class name after :::.", line}
    case Lexer{11, SCon{h, t}, acc, +line, SNil{}}: Lexed{reverse_tokens(Token{6, String.reverse(SCon{h, t}), line} <> acc, Nil{}), "", line}
    case Lexer{mode, word, acc, line, SNil{}}: Lexed{Nil{}, "Unclosed label or incomplete connection.", line}
    case Lexer{mode, word, acc, line, SCon{h, t}}: Lexed{Nil{}, SCon{h, t}, line}

def lex(s: String) -> Lexed:
  finish(scan(s, Lexer{0, "", Nil{}, 1n, ""}))

def has_node(xs: List<&2, Node>, +id: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case Node{n, l, sh} <> t: String.eq(n, id) || has_node(t, id)

def replace_label(xs: List<&2, Node>, +id: String, +label: String, +shape: U32) -> List<&2, Node>:
  match xs:
    case Nil{}: Nil{}
    case Node{+n, l, sh} <> t:
      Node{n, Bool.pick(String, String.eq(n, id), label, l), Bool.pick(U32, String.eq(n, id), shape, sh)} <> replace_label(t, id, label, shape)

def insert_node(xs: List<&2, Node>, id: String, label: String, exists: Bool, explicit: Bool, shape: U32) -> List<&2, Node>:
  match exists explicit:
    case True{} True{}: replace_label(xs, id, label, shape)
    case True{} False{}: xs
    case False{} _: Node{id, label, shape} <> xs

# Slanted shapes ([/text/], [\text\], [/text\], [\text/]) are read as their text; the node is drawn as a box.
def is_slant(+c: U32) -> Bool:
  U32.is_eq(c, 47) || U32.is_eq(c, 92)

def last_is_slant(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, SNil{}}: is_slant(c)
    case SCon{h, SCon{a, b}}: last_is_slant(SCon{a, b})

def drop_last(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{h, SNil{}}: SNil{}
    case SCon{h, SCon{a, b}}: SCon{h, drop_last(SCon{a, b})}

def shape_text(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{Chr{+c}, +t}: Bool.pick(String, is_slant(c) && last_is_slant(t), String.trim(drop_last(t)), SCon{Chr{c}, t})

def add_node(+xs: List<&2, Node>, +id: String, label: String, explicit: Bool, shape: U32) -> List<&2, Node>:
  insert_node(xs, id, label, has_node(xs, id), explicit, shape)

# ---------- Text in labels: Mermaid's entity codes and quoted arrow labels ----------

# `#quot;` `#amp;` `#lt;` `#gt;` `#nbsp;` and numbers such as `#35;` become their character; any other `#` stays.
type Entity is Data:
  Entity{code: U32, rest: String}

def all_digits(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{h, t}: Char.is_digit(h) && all_digits(t)

def digits_value(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}: acc
    case SCon{Chr{c}, t}: digits_value(t, U32.add(U32.mul(acc, 10), U32.sub(c, 48)))

def entity_code(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "quot"), 34,
    Bool.pick(U32, String.eq(name, "amp"), 38,
      Bool.pick(U32, String.eq(name, "lt"), 60,
        Bool.pick(U32, String.eq(name, "gt"), 62,
          Bool.pick(U32, String.eq(name, "nbsp"), 160,
            Bool.pick(U32, all_digits(name), digits_value(name, 0), 0))))))

# The letters and digits after `#`, at most n of them.
def entity_name(n: Nat, t: String) -> String:
  match n t:
    case 0n _: SNil{}
    case _ SNil{}: SNil{}
    case 1n+m SCon{Chr{+c}, r}: Bool.pick(String, Char.is_alpha(Chr{c}) || Char.is_digit(Chr{c}), SCon{Chr{c}, entity_name(m, r)}, SNil{})

def entity.found(+name: String, +t: String) -> Entity:
  Bool.pick(Entity, Bool.not(String.is_empty(name)) && String.starts_with(String.drop(t, String.length(name)), ";"),
    Entity{entity_code(name), String.drop(t, 1n+String.length(name))}, Entity{0, t})

# What follows a `#`: the character it stands for (0 when it is a plain #) and the text after it.
def entity(+t: String) -> Entity:
  entity.found(entity_name(8n, t), t)

def decode.piece(+c: U32, e: Entity) -> String:
  match e:
    case Entity{+code, rest}: SCon{Chr{Bool.pick(U32, U32.is_eq(c, 35) && Bool.not(U32.is_zero(code)), code, c)}, SNil{}}

def decode.next(+c: U32, +t: String, e: Entity) -> String:
  match e:
    case Entity{+code, rest}: Bool.pick(String, U32.is_eq(c, 35) && Bool.not(U32.is_zero(code)), rest, t)

# Each step takes at least one character, so the text's length is enough steps.
def decode.go(n: Nat, s: String) -> String:
  match n s:
    case 0n _: s
    case _ SNil{}: SNil{}
    case 1n+m SCon{Chr{+c}, +t}: decode.piece(c, entity(t)) ++ decode.go(m, decode.next(c, t, entity(t)))

def decode(+s: String) -> String:
  decode.go(String.length(s), s)

# An arrow label in double quotes, `-->|"text"|` or `-- "text" -->`, is read without them.
def drop_first(s: String) -> String:
  match s:
    case SNil{}: SNil{}
    case SCon{h, t}: t

def unquote(+s: String) -> String:
  Bool.pick(String, String.starts_with(s, "\"") && String.ends_with(s, "\"") && Nat.is_gt(String.length(s), 1n), drop_last(drop_first(s)), s)

def reverse_nodes(xs: List<&2, Node>, acc: List<&2, Node>) -> List<&2, Node>:
  match xs:
    case Nil{}: acc
    case h <> t: reverse_nodes(t, h <> acc)

def reverse_edges(xs: List<&2, Edge>, acc: List<&2, Edge>) -> List<&2, Edge>:
  match xs:
    case Nil{}: acc
    case h <> t: reverse_edges(t, h <> acc)

# Phase 0: statement; 1: node just read; 2: arrow needs target; 3: edge label read.
def parse_tokens(ts: List<&2, Token>, phase: U32, +previous: String, edge_label: String,
                 nodes: List<&2, Node>, edges: List<&2, Edge>) -> Graph:
  match ts phase:
    case Nil{} 2: Graph{Nil{}, Nil{}, "Expected a node after -->.", 0n}
    case Nil{} 3: Graph{Nil{}, Nil{}, "Expected a node after the connection label.", 0n}
    case Nil{} _: Graph{reverse_nodes(nodes, Nil{}), reverse_edges(edges, Nil{}), "", 0n}
    case Token{4, w, l} <> t 0: parse_tokens(t, 0, "", "", nodes, edges)
    case Token{4, w, l} <> t 1: parse_tokens(t, 0, "", "", nodes, edges)
    case Token{4, w, l} <> t 4: parse_tokens(t, 0, "", "", nodes, edges)
    case Token{0, +id, l} <> t 0:
      parse_tokens(t, 1, id, "", add_node(nodes, id, id, False{}, 0), edges)
    case Token{1, label, l} <> t 1:
      parse_tokens(t, 4, previous, "", add_node(nodes, previous, decode(shape_text(label)), True{}, 0), edges)
    case Token{7, label, l} <> t 1:
      parse_tokens(t, 4, previous, "", add_node(nodes, previous, decode(label), True{}, 1), edges)
    case Token{6, w, l} <> t 1: parse_tokens(t, 1, previous, "", nodes, edges)
    case Token{6, w, l} <> t 4: parse_tokens(t, 4, previous, "", nodes, edges)
    case Token{2, w, l} <> t 1: parse_tokens(t, 2, previous, "", nodes, edges)
    case Token{2, w, l} <> t 4: parse_tokens(t, 2, previous, "", nodes, edges)
    case Token{3, label, l} <> t 2: parse_tokens(t, 3, previous, decode(unquote(label)), nodes, edges)
    case Token{0, +id, l} <> t 2:
      parse_tokens(t, 1, id, "", add_node(nodes, id, id, False{}, 0), Edge{previous, id, ""} <> edges)
    case Token{0, +id, l} <> t 3:
      parse_tokens(t, 1, id, "", add_node(nodes, id, id, False{}, 0), Edge{previous, id, edge_label} <> edges)
    case Token{k, w, l} <> t p:
      Graph{Nil{}, Nil{}, "Expected a node, --> connection, or a new line. See the syntax guide.", l}

def header_body(ts: List<&2, Token>, valid: Bool) -> Graph:
  match valid:
    case True{}: parse_tokens(ts, 0, "", "", Nil{}, Nil{})
    case False{}: Graph{Nil{}, Nil{}, "Start with flowchart TD or graph TD. This version supports top-to-bottom flows.", 1n}

def header(ts: List<&2, Token>) -> Graph:
  match ts:
    case Token{4, w, l} <> t: header(t)
    case Token{0, +kind, l} <> Token{0, +direction, l2} <> t:
      header_body(t, (String.eq(kind, "flowchart") || String.eq(kind, "graph")) && (String.eq(direction, "TD") || String.eq(direction, "TB")))
    case _: Graph{Nil{}, Nil{}, "Start with flowchart TD, then add your nodes and connections.", 1n}

def parse_lexed(result: Lexed) -> Graph:
  match result:
    case Lexed{tokens, SNil{}, l}: header(tokens)
    case Lexed{tokens, SCon{h, t}, l}: Graph{Nil{}, Nil{}, SCon{h, t}, l}

# `classDef name …` lines say how a class looks; the diagram's shape doesn't depend on them, so they are read
# like comments (the line stays, so line numbers in messages stay right).
def without_class_definition(+line: String) -> String:
  Bool.pick(String, String.starts_with(String.trim(line), "classDef ") || String.eq(String.trim(line), "classDef"), "", line)

def without_class_definitions(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> t: without_class_definition(l) <> without_class_definitions(t)

def readable(source: String) -> String:
  String.join(without_class_definitions(String.lines(source)), "\n")

def parse(source: String) -> Graph:
  parse_lexed(lex(readable(source)))

# ---------- Classes: which node has which class (`A:::name`), in order ----------

type Class is Data:
  Class{id: String, name: String}

def classes.go(ts: List<&2, Token>, +last: String) -> List<&2, Class>:
  match ts:
    case Nil{}: Nil{}
    case Token{0, +w, l} <> t: classes.go(t, w)
    case Token{6, w, l} <> t: Class{last, w} <> classes.go(t, last)
    case Token{k, w, l} <> t: classes.go(t, last)

def classes.lexed(x: Lexed) -> List<&2, Class>:
  match x:
    case Lexed{ts, error, l}: classes.go(ts, "")

def classes(source: String) -> List<&2, Class>:
  classes.lexed(lex(readable(source)))

def is_valid(g: Graph) -> Bool:
  match g:
    case Graph{n, e, error, l}: String.is_empty(error)
