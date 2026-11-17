# Diagram laws: reading Mermaid and every edit Borzoi writes.
# Universal laws and finite regression laws are labeled separately.
import Base
import ./Parser.bend as P
import ./Graph.bend as G
import ./Edit.bend as E

law arrow_preserves_direction:
  {P.parse("flowchart TD\nA --> B") == P.Graph{[P.Node{"A", "A", 0}, P.Node{"B", "B", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

law labels_preserve_unicode:
  {P.parse("flowchart TD\nA[Pesquisa ação] --> B[結果]") == P.Graph{[P.Node{"A", "Pesquisa ação", 0}, P.Node{"B", "結果", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

law incomplete_arrow_is_rejected:
  {P.is_valid(P.parse("flowchart TD\nA -->")) == False{} : Bool}

law repeated_reference_keeps_label:
  {P.parse("flowchart TD\nA[Idea]\nA --> B") == P.Graph{[P.Node{"A", "Idea", 0}, P.Node{"B", "B", 0}], [P.Edge{"A", "B", ""}], "", 0n} : P.Graph}

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

# REGRESSION: a slanted shape is read as its text and its shape (Data input/output).
law slanted_shape_is_its_text:
  {G.parse("flowchart TD\nF[/points login/]") == P.Graph{[P.Node{"F", "points login", 10}], [], "", 0n} : P.Graph}

# REGRESSION: Mermaid's 14 flowchart shapes are read, each with its text, plain or quoted.
law all_shapes_are_read:
  {G.parse("flowchart TD\nA[a] --> B{b} --> C(c) --> D([d]) --> E[[e]] --> F[(f)] --> G((g))\nH(((h))) --> I>i] --> J{{j}} --> K[/k/] --> L[\\l\\] --> M[/m\\] --> N[\\n/]\nO[(\"o) db\")]") ==
   P.Graph{[P.Node{"A", "a", 0}, P.Node{"B", "b", 1}, P.Node{"C", "c", 2}, P.Node{"D", "d", 3}, P.Node{"E", "e", 4}, P.Node{"F", "f", 5}, P.Node{"G", "g", 6},
            P.Node{"H", "h", 7}, P.Node{"I", "i", 8}, P.Node{"J", "j", 9}, P.Node{"K", "k", 10}, P.Node{"L", "l", 11}, P.Node{"M", "m", 12}, P.Node{"N", "n", 13}, P.Node{"O", "o) db", 5}],
           [P.Edge{"A", "B", ""}, P.Edge{"B", "C", ""}, P.Edge{"C", "D", ""}, P.Edge{"D", "E", ""}, P.Edge{"E", "F", ""}, P.Edge{"F", "G", ""},
            P.Edge{"H", "I", ""}, P.Edge{"I", "J", ""}, P.Edge{"J", "K", ""}, P.Edge{"K", "L", ""}, P.Edge{"L", "M", ""}, P.Edge{"M", "N", ""}], "", 0n} : P.Graph}

# REGRESSION: every shape Borzoi writes reads back as the same shape and text.
law shapes_round_trip:
  {G.parse("flowchart TD\n" ++ G.shaped_text("A", "a", 3) ++ "\n" ++ G.shaped_text("B", "b", 7) ++ "\n" ++ G.shaped_text("C", "c", 8) ++ "\n" ++ G.shaped_text("D", "d", 11) ++ "\n" ++ G.shaped_text("E", "e", 13) ++ "\n" ++ G.shaped_text("F", "f", 5)) ==
   P.Graph{[P.Node{"A", "a", 3}, P.Node{"B", "b", 7}, P.Node{"C", "c", 8}, P.Node{"D", "d", 11}, P.Node{"E", "e", 13}, P.Node{"F", "f", 5}], [], "", 0n} : P.Graph}

# REGRESSION: <br/> in a label is a new line, and a new line is written back as <br/>.
law line_breaks_are_read:
  {G.parse("flowchart TD\nA[\"one<br/>two<br>three\"]") == P.Graph{[P.Node{"A", "one\ntwo\nthree", 0}], [], "", 0n} : P.Graph}

law line_breaks_are_written:
  {G.add_node("flowchart TD", "one\ntwo") == "flowchart TD\n  one_two[\"one<br/>two\"]" : String}

# REGRESSION: a node can be added with a shape, below a node or between two.
law add_with_a_shape:
  {G.add_node_below_as("flowchart TD\n  A", "A", "Paid?", 1) == "flowchart TD\n  A\n  A --> Paid{\"Paid?\"}" : String}

law insert_with_a_shape:
  {E.insert_between_as("flowchart TD\n  A --> B", "A", "B", "Orders", 5) == "flowchart TD\n  A --> Orders[(\"Orders\")]\n  Orders --> B" : String}

# REGRESSION: a new shape rewrites only the line that labels the node, and keeps its label.
law set_shape_keeps_the_label:
  {E.set_shape("flowchart TD\n  %% note\n  A[Orders] --> B\n  C", "A", 5) == "flowchart TD\n  %% note\n  A[(\"Orders\")] --> B\n  C" : String}

# REGRESSION: a node written only by its id gets its shape on a line of its own.
law set_shape_of_a_bare_node:
  {E.set_shape("flowchart TD\n  A --> B", "B", 1) == "flowchart TD\n  A --> B\n  B{\"B\"}" : String}

# REGRESSION: renaming a database keeps it a database.
law rename_keeps_the_shape:
  {E.rename("flowchart TD\n  A[(Orders)] --> B", "A", "Sales") == "flowchart TD\n  A[(\"Sales\")] --> B" : String}

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
