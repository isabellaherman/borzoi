# Workspace laws: projects, diagrams, history, delete and rename.
# Universal laws and finite regression laws are labeled separately.
import Base
import ./Workspace.bend as D
import ./Figures.bend as F
import ../editor/Editor.bend as E

# UNIVERSAL: typing cannot change any saved version.
law edit_preserves_history:
  for +d: D.Diagram
  for text: String
  {D.history(D.edit(d, text)) == D.history(d) : List<&2, D.Version>}

# UNIVERSAL: the editor preserves the exact source, including invalid syntax.
law edit_keeps_exact_text:
  for d: D.Diagram
  for +text: String
  {D.source(D.edit(d, text)) == text : String}

# UNIVERSAL: renaming cannot change the diagram's source or its history.
law rename_preserves_source:
  for +d: D.Diagram
  for name: String
  {D.source(D.rename(d, name)) == D.source(d) : String}

law rename_preserves_history:
  for +d: D.Diagram
  for name: String
  {D.history(D.rename(d, name)) == D.history(d) : List<&2, D.Version>}

# UNIVERSAL: an operation on an unselected diagram is the identity.
law unselected_is_unchanged:
  for +d: D.Diagram
  for a: D.Action
  {D.maybe_apply(d, a, False{}) == d : D.Diagram}

# UNIVERSAL: an unselected project is the identity, for every action.
law other_project_is_unchanged:
  for +p: D.Project
  for id: Nat
  for a: D.Action
  {D.edit_project(p, id, a, False{}) == p : D.Project}

# UNIVERSAL: restoration of a missing version is a no-op.
law missing_restore_is_unchanged:
  for +d: D.Diagram
  for stamp: String
  {D.restore_version(d, None{}, stamp) == d : D.Diagram}

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
  {D.restore(D.Diagram{1n, "D", "working", [D.Version{"old", "then"}], Nil{}}, 0n, "now") ==
   D.Diagram{1n, "D", "old", [D.Version{"old", "now"}, D.Version{"working", "now"}, D.Version{"old", "then"}], Nil{}} : D.Diagram}

law unchanged_checkpoint_is_not_duplicated:
  {D.checkpoint(D.Diagram{1n, "D", "same", [D.Version{"same", "then"}], Nil{}}, "now") ==
   D.Diagram{1n, "D", "same", [D.Version{"same", "then"}], Nil{}} : D.Diagram}

# REGRESSION: production starts in edit mode, with no projects or selection.
law initial_is_empty:
  {D.initial() == D.Workspace{Nil{}, 1n, 0n, 0n, 1} : D.Workspace}

# UNIVERSAL: a newly created diagram has no source or invented versions.
law new_diagram_is_blank:
  for +id: Nat
  for +name: String
  {D.new_diagram(id, name) == D.Diagram{id, name, "", Nil{}, Nil{}} : D.Diagram}

# UNIVERSAL: checkpointing an untouched blank diagram invents no version.
law blank_checkpoint_has_no_history:
  for +id: Nat
  for +name: String
  for stamp: String
  {D.checkpoint(D.new_diagram(id, name), stamp) == D.new_diagram(id, name) : D.Diagram}

# REGRESSION: an empty input event cannot create a project.
law empty_write_has_no_projects:
  {D.write_source(D.initial(), "") == D.initial() : D.Workspace}

# REGRESSION: deleting a diagram that isn't open keeps the open one and every other diagram.
law delete_diagram_keeps_the_rest:
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting the open diagram opens the first diagram left.
law delete_open_diagram_opens_another:
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 3n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting the open project opens a diagram of another project, skipping empty ones.
law delete_open_project_opens_another:
  {D.delete_project(D.Workspace{[D.Project{5n, "Q", Nil{}, "", "", Nil{}}, D.Project{3n, "R", [D.Diagram{4n, "C", "c", Nil{}, Nil{}}], "", "", Nil{}}, D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 6n, 1n, 2n, 1}, 1n) ==
   D.Workspace{[D.Project{5n, "Q", Nil{}, "", "", Nil{}}, D.Project{3n, "R", [D.Diagram{4n, "C", "c", Nil{}, Nil{}}], "", "", Nil{}}], 6n, 3n, 4n, 1} : D.Workspace}

# REGRESSION: deleting the last project leaves nothing open; ids are never reused.
law delete_last_project_opens_nothing:
  {D.delete_project(D.create_project(D.initial(), "P"), 1n) == D.Workspace{Nil{}, 3n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: renaming a diagram that isn't open renames only it and keeps what is open.
law rename_diagram_renames_only_it:
  {D.rename_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1}, 1n, 3n, "C") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "C", "b", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

# ---------- Why and documents (save format 2) ----------
# UNIVERSAL: nothing done to a diagram changes its Why: typing, saving a version, renaming, restoring a version.
law edit_keeps_why:
  for +d: D.Diagram
  for text: String
  {D.why(D.edit(d, text)) == D.why(d) : List<&2, D.Why>}

law checkpoint_keeps_why:
  for +d: D.Diagram
  for stamp: String
  {D.why(D.checkpoint(d, stamp)) == D.why(d) : List<&2, D.Why>}

law rename_keeps_why:
  for +d: D.Diagram
  for name: String
  {D.why(D.rename(d, name)) == D.why(d) : List<&2, D.Why>}

law restore_keeps_why:
  for +d: D.Diagram
  for v: Maybe<&2, D.Version>
  for +stamp: String
  {D.why(D.restore_version(d, v, stamp)) == D.why(d) : List<&2, D.Why>}

# UNIVERSAL: an unselected project keeps its documents, for every action.
law other_project_keeps_documents:
  for +p: D.Project
  for id: Nat
  for a: D.Action
  {D.documents(D.edit_project(p, id, a, False{})) == D.documents(p) : List<&2, D.Document>}

# REGRESSION: a new diagram has no Why, and a new project has no documents.
law new_diagram_has_no_why:
  {D.why(D.new_diagram(5n, "A")) == Nil{} : List<&2, D.Why>}

# REGRESSION: an imported project keeps its documents and every diagram's Why; its ids follow the open workspace's,
# the project first, then its diagrams, then its documents.
law import_keeps_documents_and_why:
  {D.import_projects(D.Workspace{[D.Project{1n, "Mine", [D.Diagram{2n, "M", "m", Nil{}, Nil{}}], "", "", Nil{}}], 3n, 1n, 2n, 1},
     [D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, [D.Why{"t", "idea", "cost"}]}], "", "", [D.Document{3n, "Doc", "# Text", Nil{}}]}]) ==
   D.Workspace{[D.Project{1n, "Mine", [D.Diagram{2n, "M", "m", Nil{}, Nil{}}], "", "", Nil{}},
     D.Project{3n, "P", [D.Diagram{4n, "A", "a", Nil{}, [D.Why{"t", "idea", "cost"}]}], "", "", [D.Document{5n, "Doc", "# Text", Nil{}}]}], 6n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting a diagram leaves the project's documents as they were.
law delete_diagram_keeps_documents:
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{4n, "Doc", "x", Nil{}}]}], 5n, 1n, 2n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{4n, "Doc", "x", Nil{}}]}], 5n, 1n, 2n, 1} : D.Workspace}

# ---------- Why entries ----------
# UNIVERSAL: writing a Why never changes the diagram's source or its versions, and the entry goes first.
law why_keeps_the_source:
  for +d: D.Diagram
  for y: D.Why
  {D.source(D.explain(d, y)) == D.source(d) : String}

law why_keeps_the_history:
  for +d: D.Diagram
  for y: D.Why
  {D.history(D.explain(d, y)) == D.history(d) : List<&2, D.Version>}

law why_is_added_first:
  for +d: D.Diagram
  for +y: D.Why
  {D.why(D.explain(d, y)) == y <> D.why(d) : List<&2, D.Why>}

# REGRESSION: a Why goes to the diagram named by its ids, open or not, and to no other.
law why_goes_to_its_diagram:
  {D.add_why(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1}, 1n, 3n, D.Why{"t", "idea", "cost"}) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}, [D.Why{"t", "idea", "cost"}]}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

# ---------- Documents ----------
# UNIVERSAL: writing in a document cannot change any of its saved versions, and keeps the exact text.
law document_write_keeps_history:
  for +x: D.Document
  for text: String
  {D.document_history(D.write_document(x, text)) == D.document_history(x) : List<&2, D.Version>}

law document_keeps_exact_text:
  for x: D.Document
  for +text: String
  {D.document_source(D.write_document(x, text)) == text : String}

# UNIVERSAL: nothing done to a project's documents changes its diagrams, whatever the action.
law documents_never_change_diagrams:
  for +p: D.Project
  for id: Nat
  for a: D.Action
  for selected: Bool
  {D.diagrams(D.edit_project_documents(p, id, a, selected)) == D.diagrams(p) : List<&2, D.Diagram>}

# UNIVERSAL: an action on a document that is not the chosen one is the identity.
law unselected_document_is_unchanged:
  for +x: D.Document
  for a: D.Action
  {D.maybe_apply_document(x, a, False{}) == x : D.Document}

# UNIVERSAL: a Why is for diagrams; on a document it changes nothing.
law why_on_a_document_is_nothing:
  for +x: D.Document
  for y: D.Why
  {D.apply_document(x, D.Explain{y}) == x : D.Document}

# REGRESSION: a new document takes the next id and goes first in its project; what is open stays open.
law new_document_keeps_what_is_open:
  {D.create_document(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 3n, 1n, 2n, 1}, 1n, "Doc") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{3n, "Doc", "", Nil{}}]}], 4n, 1n, 2n, 1} : D.Workspace}

law new_document_needs_its_project:
  {D.create_document(D.create_project(D.initial(), "P"), 9n, "Doc") == D.create_project(D.initial(), "P") : D.Workspace}

# REGRESSION: writing changes only the document named by its ids.
law document_write_changes_only_it:
  {D.update_document(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{4n, "Two", "two", Nil{}}, D.Document{3n, "One", "one", Nil{}}]}], 5n, 1n, 2n, 1}, 1n, 4n, D.Write{"new"}) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{4n, "Two", "new", Nil{}}, D.Document{3n, "One", "one", Nil{}}]}], 5n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: restoring a document keeps both the working text and the old version.
law document_restore_retains_work:
  {D.restore_document(D.Document{1n, "D", "working", [D.Version{"old", "then"}]}, 0n, "now") ==
   D.Document{1n, "D", "old", [D.Version{"old", "now"}, D.Version{"working", "now"}, D.Version{"old", "then"}]} : D.Document}

# REGRESSION: deleting a document keeps the project's other documents and its diagrams.
law delete_document_keeps_the_rest:
  {D.delete_document(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{4n, "Two", "two", Nil{}}, D.Document{3n, "One", "one", Nil{}}]}], 5n, 1n, 2n, 1}, 1n, 4n) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", [D.Document{3n, "One", "one", Nil{}}]}], 5n, 1n, 2n, 1} : D.Workspace}

# ---------- Figures: diagrams inside documents ----------
# REGRESSION: a figure points to its diagram in the first line of its source, a Mermaid comment.
law figure_points_to_its_diagram:
  {F.ref_of(F.with_ref(12n, "flowchart TD\n  A --> B")) == 12n : Nat}

law figure_keeps_its_own_copy:
  {F.body_of(F.with_ref(12n, "flowchart TD\n  A --> B")) == "flowchart TD\n  A --> B" : String}

law plain_mermaid_points_to_none:
  {F.ref_of("flowchart TD\n  A --> B") == 0n : Nat}

# REGRESSION: a figure shows its diagram as it is now; a figure whose diagram is gone keeps its copy.
law figure_shows_the_diagram_of_now:
  {F.sync([E.Block{E.Figure{"mermaid", "%% borzoi diagram 2\nold"}, "Cap", 0, 0}, E.Block{E.Figure{"mermaid", "%% borzoi diagram 9\ngone"}, "", 0, 0}, E.Block{E.Para{}, "text", 0, 0}],
     [D.Diagram{2n, "A", "new", Nil{}, Nil{}}]) ==
   [E.Block{E.Figure{"mermaid", "%% borzoi diagram 2\nnew"}, "Cap", 0, 0}, E.Block{E.Figure{"mermaid", "%% borzoi diagram 9\ngone"}, "", 0, 0}, E.Block{E.Para{}, "text", 0, 0}] : List<&2, E.Block>}

# REGRESSION: an imported project's figures follow their diagrams to the new ids, in the document and in its
# versions; a figure of a diagram that did not come points to none.
law import_relinks_figures:
  {D.import_projects(D.Workspace{[D.Project{1n, "Mine", [D.Diagram{2n, "M", "m", Nil{}, Nil{}}], "", "", Nil{}}], 3n, 1n, 2n, 1},
     [D.Project{1n, "P", [D.Diagram{7n, "A", "a", Nil{}, Nil{}}, D.Diagram{8n, "B", "b", Nil{}, Nil{}}], "", "",
       [D.Document{9n, "Doc", "```mermaid\n%% borzoi diagram 8\nb\n```\n\n```mermaid\n%% borzoi diagram 99\nx\n```", [D.Version{"%% borzoi diagram 7", "t"}]}]}]) ==
   D.Workspace{[D.Project{1n, "Mine", [D.Diagram{2n, "M", "m", Nil{}, Nil{}}], "", "", Nil{}},
     D.Project{3n, "P", [D.Diagram{4n, "A", "a", Nil{}, Nil{}}, D.Diagram{5n, "B", "b", Nil{}, Nil{}}], "", "",
       [D.Document{6n, "Doc", "```mermaid\n%% borzoi diagram 5\nb\n```\n\n```mermaid\n%% borzoi diagram 0\nx\n```", [D.Version{"%% borzoi diagram 4", "t"}]}]}], 7n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: Why entries are Mermaid comments, the oldest first, so the diagram's Mermaid is unchanged for
# every tool that reads it.
law why_is_written_as_comments:
  {F.for_agent(D.Diagram{2n, "A", "flowchart TD", Nil{}, [D.Why{"2026-11-18T10:00:00Z", "Split the queue", "More to run"}, D.Why{"2026-11-17T09:00:00Z", "One tree", "Less detail"}]}) ==
   "%% why\n%% 2026-11-17 One tree. Trade-off: Less detail\n%% 2026-11-18 Split the queue. Trade-off: More to run\nflowchart TD" : String}

law no_why_no_comments:
  {F.for_agent(D.Diagram{2n, "A", "flowchart TD", Nil{}, Nil{}}) == "flowchart TD" : String}

# REGRESSION: a document copied for other tools has its name as the title and each diagram as it is now,
# without the line that points to it; for an agent, with the diagram's Why.
law document_is_copied_as_markdown:
  {F.export("Plan", [E.Block{E.Para{}, "Intro", 0, 0}, E.Block{E.Figure{"mermaid", "%% borzoi diagram 2\nold"}, "", 0, 0}], [D.Diagram{2n, "A", "new", Nil{}, [D.Why{"2026-11-17T09:00:00Z", "One tree", "Less detail"}]}], False{}) ==
   "# Plan\n\nIntro\n\n```mermaid\nnew\n```" : String}

law document_is_copied_for_an_agent:
  {F.export("Plan", [E.Block{E.Para{}, "Intro", 0, 0}, E.Block{E.Figure{"mermaid", "%% borzoi diagram 2\nold"}, "", 0, 0}], [D.Diagram{2n, "A", "new", Nil{}, [D.Why{"2026-11-17T09:00:00Z", "One tree", "Less detail"}]}], True{}) ==
   "# Plan\n\nIntro\n\n```mermaid\n%% why\n%% 2026-11-17 One tree. Trade-off: Less detail\nnew\n```" : String}

