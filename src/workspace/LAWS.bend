# Workspace laws: projects, diagrams, history, delete and rename.
# Universal laws and finite regression laws are labeled separately.
import Base
import ./Workspace.bend as D

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
  {D.restore(D.Diagram{1n, "D", "working", [D.Version{"old", "then"}]}, 0n, "now") ==
   D.Diagram{1n, "D", "old", [D.Version{"old", "now"}, D.Version{"working", "now"}, D.Version{"old", "then"}]} : D.Diagram}

law unchanged_checkpoint_is_not_duplicated:
  {D.checkpoint(D.Diagram{1n, "D", "same", [D.Version{"same", "then"}]}, "now") ==
   D.Diagram{1n, "D", "same", [D.Version{"same", "then"}]} : D.Diagram}

# REGRESSION: production starts in edit mode, with no projects or selection.
law initial_is_empty:
  {D.initial() == D.Workspace{Nil{}, 1n, 0n, 0n, 1} : D.Workspace}

# UNIVERSAL: a newly created diagram has no source or invented versions.
law new_diagram_is_blank:
  for +id: Nat
  for +name: String
  {D.new_diagram(id, name) == D.Diagram{id, name, "", Nil{}} : D.Diagram}

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
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}}, D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting the open diagram opens the first diagram left.
law delete_open_diagram_opens_another:
  {D.delete_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}}, D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 3n, 1}, 1n, 3n) ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: deleting the open project opens a diagram of another project, skipping empty ones.
law delete_open_project_opens_another:
  {D.delete_project(D.Workspace{[D.Project{5n, "Q", Nil{}, "", ""}, D.Project{3n, "R", [D.Diagram{4n, "C", "c", Nil{}}], "", ""}, D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 6n, 1n, 2n, 1}, 1n) ==
   D.Workspace{[D.Project{5n, "Q", Nil{}, "", ""}, D.Project{3n, "R", [D.Diagram{4n, "C", "c", Nil{}}], "", ""}], 6n, 3n, 4n, 1} : D.Workspace}

# REGRESSION: deleting the last project leaves nothing open; ids are never reused.
law delete_last_project_opens_nothing:
  {D.delete_project(D.create_project(D.initial(), "P"), 1n) == D.Workspace{Nil{}, 3n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: renaming a diagram that isn't open renames only it and keeps what is open.
law rename_diagram_renames_only_it:
  {D.rename_diagram(D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "B", "b", Nil{}}, D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1}, 1n, 3n, "C") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "C", "b", Nil{}}, D.Diagram{2n, "A", "a", Nil{}}], "", ""}], 4n, 1n, 2n, 1} : D.Workspace}
