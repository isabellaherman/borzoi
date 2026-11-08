# Product laws. Universal laws and finite regression laws are labeled separately.
import Base
import ./Domain.bend as D
import ./Parser.bend as P
import ./Graph.bend as G
import ./Edit.bend as E

# UNIVERSAL: typing cannot change any saved version.
law edit_preserves_history:
  for +d: D.Document
  for text: String
  {D.history(D.edit(d, text)) == D.history(d) : List<&2, D.Version>}

# UNIVERSAL: the editor preserves the exact source, including invalid syntax.
law edit_keeps_exact_text:
  for d: D.Document
  for +text: String
  {D.source(D.edit(d, text)) == text : String}

# UNIVERSAL: renaming cannot change the diagram's source or its history.
law rename_preserves_source:
  for +d: D.Document
  for name: String
  {D.source(D.rename(d, name)) == D.source(d) : String}

law rename_preserves_history:
  for +d: D.Document
  for name: String
  {D.history(D.rename(d, name)) == D.history(d) : List<&2, D.Version>}

# UNIVERSAL: an operation on an unselected document is the identity.
law unselected_is_unchanged:
  for +d: D.Document
  for a: D.Action
  {D.maybe_apply(d, a, False{}) == d : D.Document}

# UNIVERSAL: an unselected project is the identity, for every action.
law other_project_is_unchanged:
  for +p: D.Project
  for id: Nat
  for a: D.Action
  {D.edit_project(p, id, a, False{}) == p : D.Project}

# UNIVERSAL: restoration of a missing version is a no-op.
law missing_restore_is_unchanged:
  for +d: D.Document
  for stamp: String
  {D.restore_version(d, None{}, stamp) == d : D.Document}

# UNIVERSAL: reading a version never invents one in an empty history.
law empty_history_has_no_version:
  for i: Nat
  {D.version_at(Nil{}, i) == None{} : Maybe<&2, D.Version>}

# UNIVERSAL: changing modes preserves all saved project data.
law view_preserves_projects:
  for ps: List<&2, D.Project>
  for next: Nat
  for p: Nat
  for d: Nat
  for m: U32
  {D.set_mode(D.Workspace{ps, next, p, d, m}, 0) == D.Workspace{ps, next, p, d, 0} : D.Workspace}

# REGRESSION: restoring keeps both the working source and the old version.
law restore_retains_work:
  {D.restore(D.Document{1n, "D", "working", [D.Version{"old", "then"}]}, 0n, "now") ==
   D.Document{1n, "D", "old", [D.Version{"old", "now"}, D.Version{"working", "now"}, D.Version{"old", "then"}]} : D.Document}

law unchanged_checkpoint_is_not_duplicated:
  {D.checkpoint(D.Document{1n, "D", "same", [D.Version{"same", "then"}]}, "now") ==
   D.Document{1n, "D", "same", [D.Version{"same", "then"}]} : D.Document}

law arrow_preserves_direction:
  {P.parse("flowchart TD\nA --> B") == P.Graph{[P.Node{"A", "A"}, P.Node{"B", "B"}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

law labels_preserve_unicode:
  {P.parse("flowchart TD\nA[Pesquisa ação] --> B[結果]") == P.Graph{[P.Node{"A", "Pesquisa ação"}, P.Node{"B", "結果"}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

law incomplete_arrow_is_rejected:
  {P.is_valid(P.parse("flowchart TD\nA -->")) == False{} : Bool}

law repeated_reference_keeps_label:
  {P.parse("flowchart TD\nA[Idea]\nA --> B") == P.Graph{[P.Node{"A", "Idea"}, P.Node{"B", "B"}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

# REGRESSION: production starts in edit mode, with no projects or selection.
law initial_is_empty:
  {D.initial() == D.Workspace{Nil{}, 1n, 0n, 0n, 1} : D.Workspace}

# UNIVERSAL: a newly created document has no source or invented versions.
law new_document_is_blank:
  for +id: Nat
  for +name: String
  {D.new_document(id, name) == D.Document{id, name, "", Nil{}} : D.Document}

# UNIVERSAL: checkpointing an untouched blank document invents no version.
law blank_checkpoint_has_no_history:
  for +id: Nat
  for +name: String
  for stamp: String
  {D.checkpoint(D.new_document(id, name), stamp) == D.new_document(id, name) : D.Document}

# REGRESSION: an empty input event cannot create a project.
law empty_write_has_no_projects:
  {D.write_source(D.initial(), "") == D.initial() : D.Workspace}

# UNIVERSAL: writing from the diagram never edits what is already written; it adds one line at the end.
law write_line_only_appends:
  for +source: String
  for line: String
  {G.write_line(source, line) == G.base(source) ++ G.line_break(G.base(source)) ++ "  " ++ line : String}

# UNIVERSAL: a connection is exactly the line `from --> to`.
law connect_writes_one_arrow:
  for +source: String
  for from: String
  for to: String
  {G.connect(source, from, to) == G.write_line(source, from ++ " --> " ++ to) : String}

# REGRESSION: the new arrow goes on its own line at the end, with or without a final line break.
law connect_adds_a_line:
  {G.connect("flowchart TD\nA --> B", "B", "C") == "flowchart TD\nA --> B\n  B --> C" : String}

law connect_after_line_break:
  {G.connect("flowchart TD\nA --> B\n", "B", "C") == "flowchart TD\nA --> B\n  B --> C" : String}

# REGRESSION: the connected source parses with the new arrow.
law connected_source_has_the_arrow:
  {G.parse(G.connect("flowchart TD\nA --> B\nC", "A", "C")) ==
   P.Graph{[P.Node{"A", "A"}, P.Node{"B", "B"}, P.Node{"C", "C"}], [P.Edge{"A", "B", ""}, P.Edge{"A", "C", ""}], "", 0n} : P.Graph}

# REGRESSION: allowed and refused connections.
law new_arrow_is_allowed:
  {G.can_connect("flowchart TD\nA --> B\nC", "A", "C") == True{} : Bool}

law loop_is_refused:
  {G.can_connect("flowchart TD\nA --> B", "B", "A") == False{} : Bool}

law repeated_arrow_is_refused:
  {G.can_connect("flowchart TD\nA --> B", "A", "B") == False{} : Bool}

law self_arrow_is_refused:
  {G.can_connect("flowchart TD\nA --> B", "A", "A") == False{} : Bool}

law invalid_source_is_refused:
  {G.can_connect("flowchart LR\nA --> B\nC", "A", "C") == False{} : Bool}

# REGRESSION: a new node's id is its name, readable, with _2 when that id is taken.
law new_node_takes_a_free_id:
  {G.add_node("flowchart TD\nStep --> B", "Step") == "flowchart TD\nStep --> B\n  Step_2[\"Step\"]" : String}

law readable_id_drops_accents_and_spaces:
  {G.add_node("flowchart TD\n  A", "Próximo passo") == "flowchart TD\n  A\n  Proximo_passo[\"Próximo passo\"]" : String}

law first_node_starts_a_flowchart:
  {G.add_node("", "Start") == "flowchart TD\n  Start[\"Start\"]" : String}

law node_below_is_one_arrow:
  {G.add_node_below("flowchart TD\nA --> B", "B", "Next") == "flowchart TD\nA --> B\n  B --> Next[\"Next\"]" : String}

# REGRESSION: a double quote in a label cannot break the source.
law quotes_in_labels_are_kept_safe:
  {G.add_node("flowchart TD\nA", "say \"hi\"") == "flowchart TD\nA\n  say_hi[\"say 'hi'\"]" : String}

# REGRESSION: renaming writes the node again; the parser keeps its id and takes the new label.
law rename_keeps_the_node:
  {G.parse(G.rename_node("flowchart TD\nA[Idea] --> B", "A", "Plan")) ==
   P.Graph{[P.Node{"A", "Plan"}, P.Node{"B", "B"}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

# ---------- Edits in place (Edit.bend). Every line a change doesn't concern stays exactly as it was. ----------

# REGRESSION: renaming rewrites only the line that gives the node its label, keeping the arrow on it.
law rename_rewrites_its_line:
  {E.rename("flowchart TD\n  %% note\n  A[Idea] --> B\n  C", "A", "Plan") == "flowchart TD\n  %% note\n  A[\"Plan\"] --> B\n  C" : String}

law rename_label_equal_to_id:
  {E.rename("flowchart TD\n  Idea[\"Idea\"]\n  Idea --> B", "Idea", "Plan") == "flowchart TD\n  Idea[\"Plan\"]\n  Idea --> B" : String}

law rename_own_line:
  {E.rename("flowchart TD\n  A[Idea]\n  A --> B", "A", "Plan") == "flowchart TD\n  A[\"Plan\"]\n  A --> B" : String}

# REGRESSION: deleting a node takes its arrows and its layout line; the other nodes stay.
law delete_takes_its_arrows:
  {E.delete_node("flowchart TD\n  A --> B\n  B --> C\n  %% borzoi B 1 2", "B") == "flowchart TD\n  A\n  C" : String}

# REGRESSION: removing an arrow keeps both nodes; a node still on another line isn't repeated.
law remove_arrow_keeps_nodes:
  {E.remove_edge("flowchart TD\n  A --> B\n  B --> C", "A", "B") == "flowchart TD\n  A\n  B --> C" : String}

# REGRESSION: a node between two keeps the arrow's label on the first new arrow.
law insert_between_keeps_the_label:
  {E.insert_between("flowchart TD\n  A -->|yes| B", "A", "B", "Check") == "flowchart TD\n  A -->|yes| Check[\"Check\"]\n  Check --> B" : String}

# REGRESSION: manual layout is %% lines: a flag and one position per node, rewritten in place when it moves.
law move_writes_one_position:
  {E.move_node(E.move_node(E.set_manual("flowchart TD\n  A", True{}), "A", 10n, 20n), "A", 30n, 5n) ==
   "flowchart TD\n  A\n  %% borzoi manual\n  %% borzoi A 30 5" : String}

law positions_are_read_back:
  {E.places("flowchart TD\n  A\n  %% borzoi A 30 5\n  %% note") == [E.Place{"A", 30n, 5n}] : List<&2, E.Place>}

law auto_keeps_positions:
  {E.set_manual("flowchart TD\n  A\n  %% borzoi manual\n  %% borzoi A 30 5", False{}) == "flowchart TD\n  A\n  %% borzoi A 30 5" : String}

# REGRESSION: other tools read the same diagram: the layout lines are comments.
law layout_lines_are_comments:
  {G.parse("flowchart TD\n  A --> B\n  %% borzoi manual\n  %% borzoi A 30 5") == G.parse("flowchart TD\n  A --> B") : P.Graph}

# ---------- Colors: the lib's tones as Mermaid classes ----------

# REGRESSION: `A:::yellow` gives A the lib's warning tone; any other class name is no color.
law class_gives_a_tone:
  {G.tones("flowchart TD\n  A[Idea]:::yellow --> B\n  C:::fancy\n  D:::law") == [G.Tone{"A", "warning"}] : List<&2, G.Tone>}

# REGRESSION: classes and classDef lines don't change the diagram's shape.
law classes_keep_the_shape:
  {G.parse("flowchart TD\n  A:::yellow --> B\n  classDef yellow fill:#fff") == G.parse("flowchart TD\n  A --> B") : P.Graph}

# REGRESSION: coloring a node writes its class and, once, the tone's classDef with the lib's colors.
law color_writes_class_and_definition:
  {E.set_tone("flowchart TD\n  A --> B", "B", "green") == "flowchart TD\n  A --> B\n  B:::green\n  classDef green fill:#ebf6ed,stroke:#2b8a3e" : String}

# REGRESSION: a new color replaces the old one, and the definition nobody uses any more goes.
law color_replaces_color:
  {E.set_tone(E.set_tone("flowchart TD\n  A --> B", "B", "green"), "B", "yellow") == "flowchart TD\n  A --> B\n  B:::yellow\n  classDef yellow fill:#fbf3e4,stroke:#b7791f" : String}

law no_color_removes_it:
  {E.set_tone("flowchart TD\n  A --> B\n  B:::green\n  classDef green fill:#ebf6ed,stroke:#2b8a3e", "B", "") == "flowchart TD\n  A --> B" : String}

# REGRESSION: rewriting a line for another edit keeps the classes on it.
law rename_keeps_the_color:
  {E.rename("flowchart TD\n  A[Idea]:::blue --> B", "A", "Plan") == "flowchart TD\n  A[\"Plan\"] --> B\n  A:::blue" : String}
