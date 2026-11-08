# A deliberately bounded Mermaid flowchart parser. No Mermaid runtime is used.
import Base

type Token is Data:
  Token{kind: U32, text: String, line: Nat}
type Lexed is Data:
  Lexed{tokens: List<&2, Token>, error: String, line: Nat}
type Node is Data:
  Node{id: String, label: String}
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
    case 124: Lexer{3, "", push_word(word, line, acc), line, ""}
    case 10: Lexer{0, "", Token{4, "", line} <> push_word(word, line, acc), 1n+line, ""}
    case 59: Lexer{0, "", Token{4, "", line} <> push_word(word, line, acc), line, ""}
    case 32: Lexer{0, "", push_word(word, line, acc), line, ""}
    case 9: Lexer{0, "", push_word(word, line, acc), line, ""}
    case 13: Lexer{0, "", push_word(word, line, acc), line, ""}
    case +c:
      Bool.pick(Lexer, Char.is_alpha(Chr{c}) || Char.is_digit(Chr{c}) || U32.is_eq(c, 95),
        Lexer{0, SCon{Chr{c}, word}, acc, line, ""},
        lexer_error(line, "Unsupported syntax. Use node IDs, [labels], --> and |edge labels|."))

def plain_label_step(code: U32, +word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 93: Lexer{0, "", Token{1, String.trim(String.reverse(word)), line} <> acc, line, ""}
    case 34:
      Bool.pick(Lexer, String.is_empty(String.trim(word)), Lexer{2, "", acc, line, ""}, lexer_error(line, "Put quotes around the whole label."))
    case 91: lexer_error(line, "Put a label containing brackets inside double quotes.")
    case 10: lexer_error(line, "Keep each label on one line.")
    case c: Lexer{1, SCon{Chr{c}, word}, acc, line, ""}

def quoted_step(code: U32, word: String, acc: List<&2, Token>, line: Nat) -> Lexer:
  match code:
    case 34: Lexer{4, word, acc, line, ""}
    case 10: lexer_error(line, "Keep each label on one line.")
    case c: Lexer{2, SCon{Chr{c}, word}, acc, line, ""}

def after_quote_step(code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 93: Lexer{0, "", Token{1, String.reverse(word), line} <> acc, line, ""}
    case 32: Lexer{4, word, acc, line, ""}
    case 9: Lexer{4, word, acc, line, ""}
    case _: lexer_error(line, "Expected ] after a quoted label.")

def edge_label_step(code: U32, word: String, acc: List<&2, Token>, +line: Nat) -> Lexer:
  match code:
    case 124: Lexer{0, "", Token{3, String.trim(String.reverse(word)), line} <> acc, line, ""}
    case 10: lexer_error(line, "Close the connection label with |.")
    case c: Lexer{3, SCon{Chr{c}, word}, acc, line, ""}

def step(mode: U32, +code: U32, word: String, +acc: List<&2, Token>, +line: Nat) -> Lexer:
  match mode:
    case 0: free_step(code, word, acc, line)
    case 1: plain_label_step(code, word, acc, line)
    case 2: quoted_step(code, word, acc, line)
    case 3: edge_label_step(code, word, acc, line)
    case 4: after_quote_step(code, word, acc, line)
    case 5:
      Bool.pick(Lexer, U32.is_eq(code, 10), Lexer{0, "", Token{4, "", line} <> acc, 1n+line, ""}, Lexer{5, "", acc, line, ""})
    case 6:
      Bool.pick(Lexer, U32.is_eq(code, 45), Lexer{7, "", acc, line, ""}, lexer_error(line, "Use --> for a directed connection."))
    case 7:
      Bool.pick(Lexer, U32.is_eq(code, 62), Lexer{0, "", Token{2, "", line} <> acc, line, ""}, lexer_error(line, "Use --> for a directed connection."))
    case 8:
      Bool.pick(Lexer, U32.is_eq(code, 37), Lexer{5, "", acc, line, ""}, lexer_error(line, "Comments begin with %% ."))
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
    case Lexer{mode, word, acc, line, SNil{}}: Lexed{Nil{}, "Unclosed label or incomplete connection.", line}
    case Lexer{mode, word, acc, line, SCon{h, t}}: Lexed{Nil{}, SCon{h, t}, line}

def lex(s: String) -> Lexed:
  finish(scan(s, Lexer{0, "", Nil{}, 1n, ""}))

def has_node(xs: List<&2, Node>, +id: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case Node{n, l} <> t: String.eq(n, id) || has_node(t, id)

def replace_label(xs: List<&2, Node>, +id: String, +label: String) -> List<&2, Node>:
  match xs:
    case Nil{}: Nil{}
    case Node{+n, l} <> t:
      Node{n, Bool.pick(String, String.eq(n, id), label, l)} <> replace_label(t, id, label)

def insert_node(xs: List<&2, Node>, id: String, label: String, exists: Bool, explicit: Bool) -> List<&2, Node>:
  match exists explicit:
    case True{} True{}: replace_label(xs, id, label)
    case True{} False{}: xs
    case False{} _: Node{id, label} <> xs

def add_node(+xs: List<&2, Node>, +id: String, label: String, explicit: Bool) -> List<&2, Node>:
  insert_node(xs, id, label, has_node(xs, id), explicit)

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
      parse_tokens(t, 1, id, "", add_node(nodes, id, id, False{}), edges)
    case Token{1, label, l} <> t 1:
      parse_tokens(t, 4, previous, "", add_node(nodes, previous, label, True{}), edges)
    case Token{2, w, l} <> t 1: parse_tokens(t, 2, previous, "", nodes, edges)
    case Token{2, w, l} <> t 4: parse_tokens(t, 2, previous, "", nodes, edges)
    case Token{3, label, l} <> t 2: parse_tokens(t, 3, previous, label, nodes, edges)
    case Token{0, +id, l} <> t 2:
      parse_tokens(t, 1, id, "", add_node(nodes, id, id, False{}), Edge{previous, id, ""} <> edges)
    case Token{0, +id, l} <> t 3:
      parse_tokens(t, 1, id, "", add_node(nodes, id, id, False{}), Edge{previous, id, edge_label} <> edges)
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

def parse(source: String) -> Graph:
  parse_lexed(lex(source))

def is_valid(g: Graph) -> Bool:
  match g:
    case Graph{n, e, error, l}: String.is_empty(error)
