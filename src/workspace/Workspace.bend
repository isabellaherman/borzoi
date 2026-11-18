# The workspace state and every user-visible mutation live in Bend.
import Base
import ../editor/Markdown.bend as M

type Version is Data:
  Version{source: String, stamp: String}
# Why a diagram looks the way it does: an idea or decision and what it gives up. Kept beside the diagram,
# never in its Mermaid text, so writing one never changes the diagram.
type Why is Data:
  Why{stamp: String, idea: String, tradeoff: String}
type Diagram is Data:
  Diagram{id: Nat, name: String, source: String, history: List<&2, Version>, why: List<&2, Why>}
# A document: text in Markdown that can show the project's diagrams. Its versions work like a diagram's.
type Document is Data:
  Document{id: Nat, name: String, source: String, history: List<&2, Version>}
type Project is Data:
  Project{id: Nat, name: String, diagrams: List<&2, Diagram>, inbox: String, seen: String, documents: List<&2, Document>}
type Workspace is Data:
  Workspace{projects: List<&2, Project>, next_id: Nat, project: Nat, diagram: Nat, mode: U32}
type Action is Data:
  Write{source: String}
  Checkpoint{stamp: String}
  Restore{index: Nat, stamp: String}
  Rename{name: String}
  Explain{why: Why}

def source(d: Diagram) -> String:
  match d:
    case Diagram{i, n, s, h, wy}: s

def history(d: Diagram) -> List<&2, Version>:
  match d:
    case Diagram{i, n, s, h, wy}: h

def why(d: Diagram) -> List<&2, Why>:
  match d:
    case Diagram{i, n, s, h, wy}: wy

def documents(p: Project) -> List<&2, Document>:
  match p:
    case Project{i, n, ds, k, sn, dcs}: dcs

def edit(d: Diagram, text: String) -> Diagram:
  match d:
    case Diagram{i, n, s, h, wy}: Diagram{i, n, text, h, wy}

def rename(d: Diagram, name: String) -> Diagram:
  match d:
    case Diagram{i, n, s, h, wy}: Diagram{i, name, s, h, wy}

def checkpoint_history(xs: List<&2, Version>, +text: String, stamp: String) -> List<&2, Version>:
  match xs:
    case Nil{}: Bool.pick(List<&2, Version>, String.is_empty(text), Nil{}, [Version{text, stamp}])
    case Version{+old, +time} <> +tail:
      Bool.pick(List<&2, Version>, String.eq(old, text),
        Version{old, time} <> tail,
        Version{text, stamp} <> Version{old, time} <> tail)

def checkpoint(d: Diagram, stamp: String) -> Diagram:
  match d:
    case Diagram{i, n, +s, h, wy}: Diagram{i, n, s, checkpoint_history(h, s, stamp), wy}

def version_at(xs: List<&2, Version>, i: Nat) -> Maybe<&2, Version>:
  match xs i:
    case Nil{} _: None{}
    case h <> t 0n: Some{h}
    case h <> t 1n+k: version_at(t, k)

def restore_version(d: Diagram, v: Maybe<&2, Version>, +stamp: String) -> Diagram:
  match v:
    case None{}: d
    case Some{Version{text, time}}: checkpoint(edit(checkpoint(d, stamp), text), stamp)

def restore(+d: Diagram, index: Nat, stamp: String) -> Diagram:
  restore_version(d, version_at(history(d), index), stamp)

# A Why entry goes first, as a version does. The diagram's source and versions stay as they were.
def explain(d: Diagram, y: Why) -> Diagram:
  match d:
    case Diagram{i, n, s, h, wy}: Diagram{i, n, s, h, y <> wy}

def apply(d: Diagram, a: Action) -> Diagram:
  match a:
    case Write{text}: edit(d, text)
    case Checkpoint{stamp}: checkpoint(d, stamp)
    case Restore{i, stamp}: restore(d, i, stamp)
    case Rename{name}: rename(d, name)
    case Explain{y}: explain(d, y)

def maybe_apply(+d: Diagram, a: Action, selected: Bool) -> Diagram:
  match selected:
    case False{}: d
    case True{}: apply(d, a)

def edit_diagrams(ds: List<&2, Diagram>, +id: Nat, +a: Action) -> List<&2, Diagram>:
  match ds:
    case Nil{}: Nil{}
    case Diagram{+i, n, s, h, wy} <> t:
      maybe_apply(Diagram{i, n, s, h, wy}, a, Nat.is_eq(i, id)) <> edit_diagrams(t, id, a)

def edit_project(p: Project, id: Nat, a: Action, selected: Bool) -> Project:
  match p selected:
    case Project{i, n, ds, k, sn, dcs} False{}: Project{i, n, ds, k, sn, dcs}
    case Project{i, n, ds, k, sn, dcs} True{}: Project{i, n, edit_diagrams(ds, id, a), k, sn, dcs}

def edit_projects(ps: List<&2, Project>, +project: Nat, +diagram: Nat, +a: Action) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn, dcs} <> t:
      edit_project(Project{i, n, ds, k, sn, dcs}, diagram, a, Nat.is_eq(i, project)) <> edit_projects(t, project, diagram, a)

def update(w: Workspace, a: Action) -> Workspace:
  match w:
    case Workspace{ps, next, +p, +d, mode}: Workspace{edit_projects(ps, p, d, a), next, p, d, mode}

def find_diagram(ds: List<&2, Diagram>, +id: Nat) -> Maybe<&2, Diagram>:
  match ds:
    case Nil{}: None{}
    case Diagram{+i, +n, +s, +h, +wy} <> t:
      Bool.pick(Maybe<&2, Diagram>, Nat.is_eq(i, id), Some{Diagram{i, n, s, h, wy}}, find_diagram(t, id))

def find_project(ps: List<&2, Project>, +project: Nat, +diagram: Nat) -> Maybe<&2, Diagram>:
  match ps:
    case Nil{}: None{}
    case Project{i, n, ds, k, sn, dcs} <> t:
      Bool.pick(Maybe<&2, Diagram>, Nat.is_eq(i, project), find_diagram(ds, diagram), find_project(t, project, diagram))

def current(w: Workspace) -> Maybe<&2, Diagram>:
  match w:
    case Workspace{ps, next, p, d, mode}: find_project(ps, p, d)

def open_checked(w: Workspace, project: Nat, diagram: Nat, exists: Maybe<&2, Diagram>) -> Workspace:
  match w exists:
    case Workspace{ps, next, p, d, mode} None{}: Workspace{ps, next, p, d, mode}
    case Workspace{ps, next, p, d, mode} Some{doc}: Workspace{ps, next, project, diagram, mode}

def open(+w: Workspace, +project: Nat, +diagram: Nat) -> Workspace:
  match w:
    case Workspace{+ps, next, p, d, mode}:
      open_checked(Workspace{ps, next, p, d, mode}, project, diagram, find_project(ps, project, diagram))

def set_mode(w: Workspace, mode: U32) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, m}: Workspace{ps, next, p, d, Bool.pick(U32, U32.is_eq(mode, 1), 1, 0)}

def new_diagram(id: Nat, name: String) -> Diagram:
  Diagram{id, name, "", Nil{}, Nil{}}

def create_project(w: Workspace, name: String) -> Workspace:
  match w:
    case Workspace{ps, +next, p, d, mode}:
      Workspace{Project{next, name, [new_diagram(1n+next, "Untitled diagram")], "", "", Nil{}} <> ps, 2n+next, next, 1n+next, 1}

def add_diagram(ps: List<&2, Project>, +id: Nat, +doc: Diagram) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, +ds, k, sn, dcs} <> t:
      Project{i, n, Bool.pick(List<&2, Diagram>, Nat.is_eq(i, id), doc <> ds, ds), k, sn, dcs} <> add_diagram(t, id, doc)

def has_project(ps: List<&2, Project>, +id: Nat) -> Bool:
  match ps:
    case Nil{}: False{}
    case Project{i, n, ds, k, sn, dcs} <> t: Nat.is_eq(i, id) || has_project(t, id)

def create_diagram_checked(w: Workspace, +project: Nat, name: String, valid: Bool) -> Workspace:
  match w valid:
    case Workspace{ps, next, p, d, mode} False{}: Workspace{ps, next, p, d, mode}
    case Workspace{ps, +next, p, d, mode} True{}:
      Workspace{add_diagram(ps, project, new_diagram(next, name)), 1n+next, project, next, 1}

def create_diagram(w: Workspace, +project: Nat, name: String) -> Workspace:
  match w:
    case Workspace{+ps, next, p, d, mode}:
      create_diagram_checked(Workspace{ps, next, p, d, mode}, project, name, has_project(ps, project))

def rename_projects(ps: List<&2, Project>, +id: Nat, +name: String) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn, dcs} <> t:
      Project{i, Bool.pick(String, Nat.is_eq(i, id), name, n), ds, k, sn, dcs} <> rename_projects(t, id, name)

def rename_project(w: Workspace, id: Nat, name: String) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{rename_projects(ps, id, name), next, p, d, mode}

def diagram_count(ds: List<&2, Diagram>) -> Nat:
  match ds:
    case Nil{}: 0n
    case h <> t: 1n+diagram_count(t)

def document_count(ds: List<&2, Document>) -> Nat:
  match ds:
    case Nil{}: 0n
    case h <> t: 1n+document_count(t)

# Ids a project takes: its own, one per diagram and one per document.
def project_span(ps: List<&2, Project>) -> Nat:
  match ps:
    case Nil{}: 0n
    case Project{i, n, ds, k, sn, dcs} <> t: (1n + diagram_count(ds) + document_count(dcs) + project_span(t) : Nat)

def reindex_diagrams(ds: List<&2, Diagram>, +next: Nat) -> List<&2, Diagram>:
  match ds:
    case Nil{}: Nil{}
    case Diagram{i, n, s, h, wy} <> t:
      Diagram{next, n, s, h, wy} <> reindex_diagrams(t, 1n+next)

# A figure in a document points to its diagram with a Mermaid comment, the first line of its source:
# `%% borzoi diagram 12`. When an import gives the diagrams new ids, the documents' figures follow them.
def ref_prefix() -> String:
  "%% borzoi diagram "

# The new id of the diagram that had the id `id`: `olds` are the old ids in order, the first one is now `new`.
# A figure of a diagram the project doesn't have points to none (0).
def new_ref(olds: List<&2, Nat>, +id: Nat, +new: Nat) -> Nat:
  match olds:
    case Nil{}: 0n
    case o <> t: Bool.pick(Nat, Nat.is_eq(o, id), new, new_ref(t, id, 1n+new))

def relink_ref(m: Maybe<&2, Nat>, l: String, olds: List<&2, Nat>, first: Nat) -> String:
  match m:
    case None{}: l
    case Some{id}: ref_prefix() ++ Nat.show(new_ref(olds, id, first))

def relink_line(+l: String, olds: List<&2, Nat>, first: Nat) -> String:
  Bool.pick(String, String.starts_with(l, ref_prefix()), relink_ref(Nat.read(String.trim(String.drop(l, 18n))), l, olds, first), l)

def relink.go(ls: List<&2, String>, +olds: List<&2, Nat>, +first: Nat, acc: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}: List.reverse(&2, String, acc)
    case l <> t: relink.go(t, olds, first, relink_line(l, olds, first) <> acc)

def relink(source: String, olds: List<&2, Nat>, first: Nat) -> String:
  M.unlines(relink.go(M.lines(source), olds, first, Nil{}))

def relink_versions(vs: List<&2, Version>, +olds: List<&2, Nat>, +first: Nat) -> List<&2, Version>:
  match vs:
    case Nil{}: Nil{}
    case Version{s, stamp} <> t: Version{relink(s, olds, first), stamp} <> relink_versions(t, olds, first)

def diagram_ids(ds: List<&2, Diagram>) -> List<&2, Nat>:
  match ds:
    case Nil{}: Nil{}
    case Diagram{i, n, s, h, wy} <> t: i <> diagram_ids(t)

def reindex_documents(ds: List<&2, Document>, +next: Nat, +olds: List<&2, Nat>, +first: Nat) -> List<&2, Document>:
  match ds:
    case Nil{}: Nil{}
    case Document{i, n, s, h} <> t:
      Document{next, n, relink(s, olds, first), relink_versions(h, olds, first)} <> reindex_documents(t, 1n+next, olds, first)

# An imported project gets new ids: the project first, then its diagrams, then its documents.
def reindex_projects(ps: List<&2, Project>, +next: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{i, n, +ds, k, sn, +dcs} <> t:
      Project{next, n, reindex_diagrams(ds, 1n+next), k, sn, reindex_documents(dcs, (next + 1n + diagram_count(ds) : Nat), diagram_ids(ds), 1n+next)} <> reindex_projects(t, (next + 1n + diagram_count(ds) + document_count(dcs) : Nat))

def append_projects(a: List<&2, Project>, b: List<&2, Project>) -> List<&2, Project>:
  match a:
    case Nil{}: b
    case h <> t: h <> append_projects(t, b)

def select_first(w: Workspace) -> Workspace:
  match w:
    case Workspace{Project{+pid, name, Diagram{+did, title, text, h, wy} <> ds, k, sn, dcs} <> ps, next, p, d, mode}:
      Workspace{Project{pid, name, Diagram{did, title, text, h, wy} <> ds, k, sn, dcs} <> ps, next, pid, did, mode}
    case other: other

def import_projects(w: Workspace, +incoming: List<&2, Project>) -> Workspace:
  match w:
    case Workspace{Nil{}, +next, p, d, mode}:
      select_first(Workspace{reindex_projects(incoming, next), (next + project_span(incoming) : Nat), p, d, mode})
    case Workspace{ps, +next, p, d, mode}:
      Workspace{append_projects(ps, reindex_projects(incoming, next)), (next + project_span(incoming) : Nat), p, d, mode}

# Used only to recognize the untouched seed from the first deployment. Never creates data.
def legacy_demo_source() -> String:
  "flowchart TD\n  A[Ask a question] --> B[Gather evidence]\n  B --> C[Compare approaches]\n  C --> D[Test an idea]\n  D --> E[Record what changed]\n"

def initial() -> Workspace:
  Workspace{Nil{}, 1n, 0n, 0n, 1}

# Materialize a diagram only when the user writes their first source.
def write_source_checked(+w: Workspace, +text: String, selected: Maybe<&2, Diagram>) -> Workspace:
  match selected:
    case Some{d}: update(w, Write{text})
    case None{}:
      Bool.pick(Workspace, String.is_empty(text), w,
        update(create_project(w, "Untitled project"), Write{text}))

def write_source(+w: Workspace, text: String) -> Workspace:
  write_source_checked(w, text, current(w))

# Only the exact, unmodified original demo workspace is removable.
def is_legacy_demo(w: Workspace) -> Bool:
  match w:
    case Workspace{[Project{1n, pn, [Diagram{2n, dn, text, [Version{old, time}], Nil{}}], k, sn, Nil{}}], 3n, 1n, 2n, mode}:
      String.eq(pn, "Research notebook") && String.eq(dn, "A research flow") &&
      String.eq(text, legacy_demo_source()) && String.eq(old, legacy_demo_source()) && String.eq(time, "Created")
    case other: False{}

def remove_legacy_demo(+w: Workspace) -> Workspace:
  Bool.pick(Workspace, is_legacy_demo(w), initial(), w)

# ---------- Delete a project or a diagram ----------
# Only the chosen one goes. If it was open, the first diagram left opens; with none left, nothing is open.
type Location is Data:
  Location{project: Nat, diagram: Nat}

def keep_diagram(d: Diagram, drop: Bool, rest: List<&2, Diagram>) -> List<&2, Diagram>:
  match drop:
    case True{}: rest
    case False{}: d <> rest

def keep_project(p: Project, drop: Bool, rest: List<&2, Project>) -> List<&2, Project>:
  match drop:
    case True{}: rest
    case False{}: p <> rest

def drop_diagrams(ds: List<&2, Diagram>, +id: Nat) -> List<&2, Diagram>:
  match ds:
    case Nil{}: Nil{}
    case Diagram{+i, n, s, h, wy} <> t:
      keep_diagram(Diagram{i, n, s, h, wy}, Nat.is_eq(i, id), drop_diagrams(t, id))

def drop_project(ps: List<&2, Project>, +id: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn, dcs} <> t:
      keep_project(Project{i, n, ds, k, sn, dcs}, Nat.is_eq(i, id), drop_project(t, id))

def drop_diagram(ps: List<&2, Project>, +project: Nat, +diagram: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, +ds, k, sn, dcs} <> t:
      Project{i, n, Bool.pick(List<&2, Diagram>, Nat.is_eq(i, project), drop_diagrams(ds, diagram), ds), k, sn, dcs} <> drop_diagram(t, project, diagram)

def first_location(ps: List<&2, Project>) -> Maybe<&2, Location>:
  match ps:
    case Nil{}: None{}
    case Project{i, n, Diagram{did, dn, s, h, wy} <> ds, k, sn, dcs} <> t: Some{Location{i, did}}
    case Project{i, n, Nil{}, k, sn, dcs} <> t: first_location(t)

def reselect(w: Workspace, there: Maybe<&2, Location>) -> Workspace:
  match w there:
    case Workspace{ps, next, p, d, mode} None{}: Workspace{ps, next, 0n, 0n, mode}
    case Workspace{ps, next, p, d, mode} Some{Location{lp, ld}}: Workspace{ps, next, lp, ld, mode}

def settle_checked(w: Workspace, here: Maybe<&2, Diagram>, first: Maybe<&2, Location>) -> Workspace:
  match here:
    case Some{doc}: w
    case None{}: reselect(w, first)

def settle(w: Workspace) -> Workspace:
  match w:
    case Workspace{+ps, next, +p, +d, mode}:
      settle_checked(Workspace{ps, next, p, d, mode}, find_project(ps, p, d), first_location(ps))

def delete_project(w: Workspace, +id: Nat) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: settle(Workspace{drop_project(ps, id), next, p, d, mode})

def delete_diagram(w: Workspace, +project: Nat, +diagram: Nat) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: settle(Workspace{drop_diagram(ps, project, diagram), next, p, d, mode})

# Rename any diagram by its ids, open or not.
def rename_diagram(w: Workspace, +project: Nat, +diagram: Nat, name: String) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{edit_projects(ps, project, diagram, Rename{name}), next, p, d, mode}

def diagrams(p: Project) -> List<&2, Diagram>:
  match p:
    case Project{i, n, ds, k, sn, dcs}: ds

# ---------- Documents ----------
# A document is written, saved in versions, restored and renamed as a diagram is. Nothing here changes a
# diagram, and what is open (a diagram) stays open.

def document_source(x: Document) -> String:
  match x:
    case Document{i, n, s, h}: s

def document_history(x: Document) -> List<&2, Version>:
  match x:
    case Document{i, n, s, h}: h

def write_document(x: Document, text: String) -> Document:
  match x:
    case Document{i, n, s, h}: Document{i, n, text, h}

def name_document(x: Document, name: String) -> Document:
  match x:
    case Document{i, n, s, h}: Document{i, name, s, h}

def checkpoint_document(x: Document, stamp: String) -> Document:
  match x:
    case Document{i, n, +s, h}: Document{i, n, s, checkpoint_history(h, s, stamp)}

def restore_document_version(x: Document, v: Maybe<&2, Version>, +stamp: String) -> Document:
  match v:
    case None{}: x
    case Some{Version{text, time}}: checkpoint_document(write_document(checkpoint_document(x, stamp), text), stamp)

def restore_document(+x: Document, index: Nat, stamp: String) -> Document:
  restore_document_version(x, version_at(document_history(x), index), stamp)

def apply_document(x: Document, a: Action) -> Document:
  match a:
    case Write{text}: write_document(x, text)
    case Checkpoint{stamp}: checkpoint_document(x, stamp)
    case Restore{i, stamp}: restore_document(x, i, stamp)
    case Rename{name}: name_document(x, name)
    case Explain{y}: x

def maybe_apply_document(+x: Document, a: Action, selected: Bool) -> Document:
  match selected:
    case False{}: x
    case True{}: apply_document(x, a)

def edit_documents(xs: List<&2, Document>, +id: Nat, +a: Action) -> List<&2, Document>:
  match xs:
    case Nil{}: Nil{}
    case Document{+i, n, s, h} <> t:
      maybe_apply_document(Document{i, n, s, h}, a, Nat.is_eq(i, id)) <> edit_documents(t, id, a)

def edit_project_documents(p: Project, id: Nat, a: Action, selected: Bool) -> Project:
  match p selected:
    case Project{i, n, ds, k, sn, dcs} False{}: Project{i, n, ds, k, sn, dcs}
    case Project{i, n, ds, k, sn, dcs} True{}: Project{i, n, ds, k, sn, edit_documents(dcs, id, a)}

def edit_projects_documents(ps: List<&2, Project>, +project: Nat, +document: Nat, +a: Action) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn, dcs} <> t:
      edit_project_documents(Project{i, n, ds, k, sn, dcs}, document, a, Nat.is_eq(i, project)) <> edit_projects_documents(t, project, document, a)

def update_document(w: Workspace, project: Nat, document: Nat, a: Action) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{edit_projects_documents(ps, project, document, a), next, p, d, mode}

def new_document(id: Nat, name: String) -> Document:
  Document{id, name, "", Nil{}}

def add_document(ps: List<&2, Project>, +id: Nat, +doc: Document) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn, +dcs} <> t:
      Project{i, n, ds, k, sn, Bool.pick(List<&2, Document>, Nat.is_eq(i, id), doc <> dcs, dcs)} <> add_document(t, id, doc)

def create_document_checked(w: Workspace, +project: Nat, name: String, valid: Bool) -> Workspace:
  match w valid:
    case Workspace{ps, next, p, d, mode} False{}: Workspace{ps, next, p, d, mode}
    case Workspace{ps, +next, p, d, mode} True{}:
      Workspace{add_document(ps, project, new_document(next, name)), 1n+next, p, d, mode}

# The new document takes the next id (what next_id was before the call).
def create_document(w: Workspace, +project: Nat, name: String) -> Workspace:
  match w:
    case Workspace{+ps, next, p, d, mode}:
      create_document_checked(Workspace{ps, next, p, d, mode}, project, name, has_project(ps, project))

def keep_document(x: Document, drop: Bool, rest: List<&2, Document>) -> List<&2, Document>:
  match drop:
    case True{}: rest
    case False{}: x <> rest

def drop_documents(xs: List<&2, Document>, +id: Nat) -> List<&2, Document>:
  match xs:
    case Nil{}: Nil{}
    case Document{+i, n, s, h} <> t:
      keep_document(Document{i, n, s, h}, Nat.is_eq(i, id), drop_documents(t, id))

def drop_document(ps: List<&2, Project>, +project: Nat, +document: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn, +dcs} <> t:
      Project{i, n, ds, k, sn, Bool.pick(List<&2, Document>, Nat.is_eq(i, project), drop_documents(dcs, document), dcs)} <> drop_document(t, project, document)

def delete_document(w: Workspace, project: Nat, document: Nat) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{drop_document(ps, project, document), next, p, d, mode}

# A Why entry on any diagram, by its ids.
def add_why(w: Workspace, project: Nat, diagram: Nat, y: Why) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{edit_projects(ps, project, diagram, Explain{y}), next, p, d, mode}

