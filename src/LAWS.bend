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
  {P.parse("flowchart TD\nA --> B") == P.Graph{[P.Node{"A", "A", 0}, P.Node{"B", "B", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

law labels_preserve_unicode:
  {P.parse("flowchart TD\nA[Pesquisa ação] --> B[結果]") == P.Graph{[P.Node{"A", "Pesquisa ação", 0}, P.Node{"B", "結果", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

law incomplete_arrow_is_rejected:
  {P.is_valid(P.parse("flowchart TD\nA -->")) == False{} : Bool}

law repeated_reference_keeps_label:
  {P.parse("flowchart TD\nA[Idea]\nA --> B") == P.Graph{[P.Node{"A", "Idea", 0}, P.Node{"B", "B", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

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
   P.Graph{[P.Node{"A", "A", 0}, P.Node{"B", "B", 0}, P.Node{"C", "C", 0}], [P.Edge{"A", "B", ""}, P.Edge{"A", "C", ""}], "", 0n} : P.Graph}

# REGRESSION: allowed and refused connections.
law new_arrow_is_allowed:
  {G.can_connect("flowchart TD\nA --> B\nC", "A", "C") == True{} : Bool}

law return_loop_is_allowed:
  {G.can_connect("flowchart TD\nA --> B", "B", "A") == True{} : Bool}

# REGRESSION: a source with a return loop is valid and keeps every arrow.
law return_loop_parses:
  {G.parse("flowchart TD\nA --> B\nB --> A") ==
   P.Graph{[P.Node{"A", "A", 0}, P.Node{"B", "B", 0}], [P.Edge{"A", "B", ""}, P.Edge{"B", "A", ""}], "", 0n} : P.Graph}

# REGRESSION: a slanted shape is read as its text.
law slanted_shape_is_its_text:
  {G.parse("flowchart TD\nF[/points login/]") == P.Graph{[P.Node{"F", "points login", 0}], [], "", 0n} : P.Graph}

# REGRESSION: an arrow from a node to itself is valid, as in Mermaid, and keeps its arrow.
law self_arrow_parses:
  {G.parse("flowchart TD\nA --> A") == P.Graph{[P.Node{"A", "A", 0}], [P.Edge{"A", "A", ""}], "", 0n} : P.Graph}

law repeated_arrow_is_refused:
  {G.can_connect("flowchart TD\nA --> B", "A", "B") == False{} : Bool}

law self_arrow_is_allowed:
  {G.can_connect("flowchart TD\nA --> B", "A", "A") == True{} : Bool}

law repeated_self_arrow_is_refused:
  {G.can_connect("flowchart TD\nA --> A", "A", "A") == False{} : Bool}

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
  {G.add_node("flowchart TD\nA", "say \"hi\"") == "flowchart TD\nA\n  say_hi[\"say #quot;hi#quot;\"]" : String}

# REGRESSION: Mermaid's entity codes in a label are read as their characters; an unknown # stays.
law entities_in_labels_are_read:
  {G.parse("flowchart TD\nA[\"say #quot;hi#quot; #35;1 #x; #\"]") == P.Graph{[P.Node{"A", "say \"hi\" #1 #x; #", 0}], [], "", 0n} : P.Graph}

# REGRESSION: a quote written by Borzoi reads back as the same quote.
law quotes_round_trip:
  {G.parse(G.add_node("flowchart TD", "say \"hi\"")) == P.Graph{[P.Node{"say_hi", "say \"hi\"", 0}], [], "", 0n} : P.Graph}

# REGRESSION: renaming writes the node again; the parser keeps its id and takes the new label.
law rename_keeps_the_node:
  {G.parse(G.rename_node("flowchart TD\nA[Idea] --> B", "A", "Plan")) ==
   P.Graph{[P.Node{"A", "Plan", 0}, P.Node{"B", "B", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

# ---------- Decisions and arrow text ----------

# REGRESSION: A{text} is a decision node; its label is read like a box's, quoted or not.
law decision_is_read:
  {G.parse("flowchart TD\nA{Ready?} --> B{\"Ship [now]?\"}") ==
   P.Graph{[P.Node{"A", "Ready?", 1}, P.Node{"B", "Ship [now]?", 1}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

# REGRESSION: text in the middle of an arrow, A -- text --> B, is the arrow's label, as with -->|text|.
law arrow_text_is_a_label:
  {G.parse("flowchart TD\nA -- Stay --> B\nA -- \"Don't allow\" --> C") == G.parse("flowchart TD\nA -->|Stay| B\nA -->|Don't allow| C") : P.Graph}

# REGRESSION: an arrow label in quotes is read without them.
law quoted_arrow_label_is_unquoted:
  {G.parse("flowchart TD\nA -->|\"yes\"| B") == G.parse("flowchart TD\nA -->|yes| B") : P.Graph}

# ---------- Edits in place (Edit.bend). Every line a change doesn't concern stays exactly as it was. ----------

# REGRESSION: renaming rewrites only the line that gives the node its label, keeping the arrow on it.
law rename_rewrites_its_line:
  {E.rename("flowchart TD\n  %% note\n  A[Idea] --> B\n  C", "A", "Plan") == "flowchart TD\n  %% note\n  A[\"Plan\"] --> B\n  C" : String}

law rename_label_equal_to_id:
  {E.rename("flowchart TD\n  Idea[\"Idea\"]\n  Idea --> B", "Idea", "Plan") == "flowchart TD\n  Idea[\"Plan\"]\n  Idea --> B" : String}

law rename_own_line:
  {E.rename("flowchart TD\n  A[Idea]\n  A --> B", "A", "Plan") == "flowchart TD\n  A[\"Plan\"]\n  A --> B" : String}

# REGRESSION: renaming a decision keeps it a decision.
law rename_keeps_the_decision:
  {E.rename("flowchart TD\n  A{Ready?} --> B", "A", "Done?") == "flowchart TD\n  A{\"Done?\"} --> B" : String}

# REGRESSION: rewriting a line for another edit keeps its decisions.
law delete_keeps_other_decisions:
  {E.delete_node("flowchart TD\n  A{Ready?} --> B\n  A --> C", "B") == "flowchart TD\n  A{\"Ready?\"}\n  A --> C" : String}

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

# REGRESSION: deleting a diagram that isn't open keeps the open one and every other diagram.
law delete_diagram_keeps_the_rest:
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Document{3n, "B", "b", Nil{}}, D.Document{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Document{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting the open diagram opens the first diagram left.
law delete_open_diagram_opens_another:
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Document{3n, "B", "b", Nil{}}, D.Document{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 3n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Document{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting the open project opens a diagram of another project, skipping empty ones.
law delete_open_project_opens_another:
  {D.delete_project(D.Workspace{[D.Project{5n, "Q", Nil{}, "", ""}, D.Project{3n, "R", [D.Document{4n, "C", "c", Nil{}}], "", ""}, D.Project{1n, "P", [D.Document{2n, "A", "a", Nil{}}], "", ""}], 6n, 1n, 2n, 1}, 1n) ==
   D.Workspace{[D.Project{5n, "Q", Nil{}, "", ""}, D.Project{3n, "R", [D.Document{4n, "C", "c", Nil{}}], "", ""}], 6n, 3n, 4n, 1} : D.Workspace}

# REGRESSION: deleting the last project leaves nothing open; ids are never reused.
law delete_last_project_opens_nothing:
  {D.delete_project(D.create_project(D.initial(), "P"), 1n) == D.Workspace{Nil{}, 3n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: renaming a diagram that isn't open renames only it and keeps what is open.
law rename_diagram_renames_only_it:
  {D.rename_diagram(D.Workspace{[D.Project{1n, "P", [D.Document{3n, "B", "b", Nil{}}, D.Document{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1}, 1n, 3n, "C") ==
   D.Workspace{[D.Project{1n, "P", [D.Document{3n, "C", "b", Nil{}}, D.Document{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1} : D.Workspace}

# ---------- Agent projects: a message only adds a diagram ----------
# UNIVERSAL: a message for another project leaves that project exactly as it was.
law message_skips_other_projects:
  for +p: D.Project
  for doc: D.Document
  for id: String
  {D.deliver(p, doc, id, False{}) == p : D.Project}

# UNIVERSAL: a delivered message adds its diagram and keeps every diagram already there, unchanged.
law message_keeps_every_diagram:
  for +p: D.Project
  for +doc: D.Document
  for id: String
  {D.documents(D.deliver(p, doc, id, True{})) == doc <> D.documents(p) : List<&2, D.Document>}

# REGRESSION: a message becomes one new diagram, marked as sent by an agent; what is open stays open.
law message_adds_one_diagram:
  {D.receive(D.Workspace{[D.Project{1n, "P", [D.Document{2n, "A", "a", Nil{}}], "k", ""}], 3n, 1n, 2n, 1}, 1n, "k", "m1", "Churn", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Document{3n, "Churn", "%% borzoi from agent\nflowchart TD", Nil{}}, D.Document{2n, "A", "a", Nil{}}], "k", "m1"}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: a wrong key changes nothing.
law wrong_key_changes_nothing:
  {D.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "k", ""}], 2n, 0n, 0n, 1}, 1n, "x", "m1", "T", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "k", ""}], 2n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: a normal project (no key) never receives.
law normal_project_never_receives:
  {D.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "", ""}], 2n, 0n, 0n, 1}, 1n, "", "m1", "T", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "", ""}], 2n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: the same message is added once.
law same_message_is_added_once:
  {D.receive(D.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "k", ""}], 2n, 0n, 0n, 1}, 1n, "k", "m1", "T", "flowchart TD", "t"), 1n, "k", "m1", "T", "flowchart TD", "t") ==
   D.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "k", ""}], 2n, 0n, 0n, 1}, 1n, "k", "m1", "T", "flowchart TD", "t") : D.Workspace}

# REGRESSION: the sender's own name is kept and read back.
law sender_is_read:
  {D.sender("%% borzoi from Grok\nflowchart TD\n  A --> B") == "Grok" : String}

# REGRESSION: a new key replaces the old one; a normal project gets none.
law new_key_replaces_the_old:
  {D.new_key(D.Workspace{[D.Project{1n, "P", Nil{}, "k", "m1"}, D.Project{2n, "Q", Nil{}, "", ""}], 3n, 0n, 0n, 1}, 1n, "n") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "n", ""}, D.Project{2n, "Q", Nil{}, "", ""}], 3n, 0n, 0n, 1} : D.Workspace}

law normal_project_gets_no_key:
  {D.new_key(D.Workspace{[D.Project{2n, "Q", Nil{}, "", ""}], 3n, 0n, 0n, 1}, 2n, "n") ==
   D.Workspace{[D.Project{2n, "Q", Nil{}, "", ""}], 3n, 0n, 0n, 1} : D.Workspace}

# UNIVERSAL: an update for another diagram leaves it exactly as it was.
law update_skips_other_diagrams:
  for +d: D.Document
  for text: String
  for stamp: String
  {D.refresh(d, text, stamp, False{}) == d : D.Document}

# UNIVERSAL: an update shows the agent's new text.
law update_shows_the_new_text:
  for d: D.Document
  for +text: String
  for +stamp: String
  {D.source(D.refresh(d, text, stamp, True{})) == text : String}

# REGRESSION: the same title updates the agent's diagram; the old text is kept in its history.
law same_title_updates_with_history:
  {D.receive(D.Workspace{[D.Project{1n, "P", [D.Document{2n, "Churn", "%% borzoi from Grok\nflowchart TD", Nil{}}], "k", "m1"}], 3n, 1n, 2n, 1}, 1n, "k", "m2", "Churn", "%% borzoi from Grok\nflowchart TD\n  A --> B", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Document{2n, "Churn", "%% borzoi from Grok\nflowchart TD\n  A --> B", [D.Version{"%% borzoi from Grok\nflowchart TD\n  A --> B", "t"}, D.Version{"%% borzoi from Grok\nflowchart TD", "t"}]}], "k", "m2"}], 3n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: your own diagram is never updated by an agent; a message with its name becomes a new diagram.
law your_diagram_is_never_updated:
  {D.receive(D.Workspace{[D.Project{1n, "P", [D.Document{2n, "Churn", "flowchart TD", Nil{}}], "k", ""}], 3n, 1n, 2n, 1}, 1n, "k", "m1", "Churn", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Document{3n, "Churn", "%% borzoi from agent\nflowchart TD", Nil{}}, D.Document{2n, "Churn", "flowchart TD", Nil{}}], "k", "m1"}], 4n, 1n, 2n, 1} : D.Workspace}
