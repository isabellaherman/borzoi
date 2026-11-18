# Diagrams inside documents. A figure's source is Mermaid whose first line points to the project's diagram:
# `%% borzoi diagram 12` (a Mermaid comment, so every tool reads the rest as the diagram). The document shows
# the diagram as it is now; the copy kept in the document is what shows if the diagram is deleted.
import Base
import ./Workspace.bend as D
import ../editor/Editor.bend as E
import ../editor/Markdown.bend as M

def ref_line(id: Nat) -> String:
  D.ref_prefix() ++ Nat.show(id)

def ref_of_line(+l: String) -> Nat:
  Bool.pick(Nat, String.starts_with(l, D.ref_prefix()), Maybe.default(&2, Nat, Nat.read(String.trim(String.drop(l, 18n))), 0n), 0n)

def ref_of_lines(ls: List<&2, String>) -> Nat:
  match ls:
    case Nil{}: 0n
    case l <> t: ref_of_line(l)

# The id of the diagram a figure points to, or 0.
def ref_of(source: String) -> Nat:
  ref_of_lines(M.lines(source))

def body_of_lines(+ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: Nil{}
    case +l <> +t: Bool.pick(List<&2, String>, String.starts_with(l, D.ref_prefix()), t, l <> t)

# The figure's own copy of the diagram: its source without the line that points to the diagram.
def body_of(source: String) -> String:
  M.unlines(body_of_lines(M.lines(source)))

# The source of a figure of the diagram `id`.
def with_ref(id: Nat, source: String) -> String:
  ref_line(id) ++ "\n" ++ source

# ---------- Keeping the copies fresh ----------

def sync_source(m: Maybe<&2, D.Diagram>, +source: String) -> String:
  match m:
    case None{}: source
    case Some{D.Diagram{i, n, s, h, wy}}: with_ref(i, s)

def sync_block(b: E.Block, ds: List<&2, D.Diagram>) -> E.Block:
  match b:
    case E.Block{E.Figure{lang, +source}, t, a, p}: E.Block{E.Figure{lang, sync_source(D.find_diagram(ds, ref_of(source)), source)}, t, a, p}
    case other: other

def sync.go(d: List<&2, E.Block>, +ds: List<&2, D.Diagram>, back: List<&2, E.Block>) -> List<&2, E.Block>:
  match d:
    case Nil{}: E.unwind(back, Nil{})
    case h <> t: sync.go(t, ds, sync_block(h, ds) <> back)

# Every figure whose diagram is in `ds` gets that diagram's source of now. The others keep their copy.
def sync(d: List<&2, E.Block>, ds: List<&2, D.Diagram>) -> List<&2, E.Block>:
  sync.go(d, ds, Nil{})

# ---------- Why, as Mermaid comments ----------

def why_line(y: D.Why) -> String:
  match y:
    case D.Why{stamp, idea, tradeoff}:
      "%% " ++ E.take(stamp, 10n) ++ " " ++ E.clean(idea) ++ ". Trade-off: " ++ E.clean(tradeoff)

# The oldest entry first, under a `%% why` line. No entries, no lines.
def why_lines.go(ys: List<&2, D.Why>, acc: String) -> String:
  match ys:
    case Nil{}: acc
    case y <> t: why_lines.go(t, why_line(y) ++ "\n" ++ acc)

def why_lines(ys: List<&2, D.Why>) -> String:
  match ys:
    case Nil{}: ""
    case y <> t: "%% why\n" ++ why_lines.go(y <> t, "")

# A diagram for an agent: why it is the way it is, then its Mermaid.
def for_agent(d: D.Diagram) -> String:
  match d:
    case D.Diagram{i, n, s, h, wy}: why_lines(wy) ++ s

# ---------- A document to copy ----------

def plain_source(m: Maybe<&2, D.Diagram>, source: String, why: Bool) -> String:
  match m why:
    case None{} _: body_of(source)
    case Some{D.Diagram{i, n, s, h, wy}} True{}: why_lines(wy) ++ s
    case Some{D.Diagram{i, n, s, h, wy}} False{}: s

def plain_block(b: E.Block, ds: List<&2, D.Diagram>, why: Bool) -> E.Block:
  match b:
    case E.Block{E.Figure{lang, +source}, t, a, p}: E.Block{E.Figure{lang, plain_source(D.find_diagram(ds, ref_of(source)), source, why)}, t, a, p}
    case other: other

def plain.go(d: List<&2, E.Block>, +ds: List<&2, D.Diagram>, +why: Bool, back: List<&2, E.Block>) -> List<&2, E.Block>:
  match d:
    case Nil{}: E.unwind(back, Nil{})
    case h <> t: plain.go(t, ds, why, plain_block(h, ds, why) <> back)

# The document as Markdown for other tools: its name as the title, each figure as the diagram's Mermaid of now,
# without the line that points to the diagram and, when `why` is on, with the diagram's Why entries.
def export(name: String, d: List<&2, E.Block>, ds: List<&2, D.Diagram>, why: Bool) -> String:
  "# " ++ E.clean(name) ++ "\n\n" ++ M.write(plain.go(d, ds, why, Nil{}))
