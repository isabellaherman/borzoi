# Product laws. Universal laws and finite regression laws are labeled separately.
import Base
import ./Domain.bend as D
import ./Parser.bend as P

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
