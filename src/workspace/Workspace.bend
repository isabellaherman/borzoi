# The workspace state and every user-visible mutation live in Bend.
import Base

type Version is Data:
  Version{source: String, stamp: String}
type Diagram is Data:
  Diagram{id: Nat, name: String, source: String, history: List<&2, Version>}
type Project is Data:
  Project{id: Nat, name: String, diagrams: List<&2, Diagram>, inbox: String, seen: String}
type Workspace is Data:
  Workspace{projects: List<&2, Project>, next_id: Nat, project: Nat, diagram: Nat, mode: U32}
type Action is Data:
  Write{source: String}
  Checkpoint{stamp: String}
  Restore{index: Nat, stamp: String}
  Rename{name: String}

def source(d: Diagram) -> String:
  match d:
    case Diagram{i, n, s, h}: s

def history(d: Diagram) -> List<&2, Version>:
  match d:
    case Diagram{i, n, s, h}: h

def edit(d: Diagram, text: String) -> Diagram:
  match d:
    case Diagram{i, n, s, h}: Diagram{i, n, text, h}

def rename(d: Diagram, name: String) -> Diagram:
  match d:
    case Diagram{i, n, s, h}: Diagram{i, name, s, h}

def checkpoint_history(xs: List<&2, Version>, +text: String, stamp: String) -> List<&2, Version>:
  match xs:
    case Nil{}: Bool.pick(List<&2, Version>, String.is_empty(text), Nil{}, [Version{text, stamp}])
    case Version{+old, +time} <> +tail:
      Bool.pick(List<&2, Version>, String.eq(old, text),
        Version{old, time} <> tail,
        Version{text, stamp} <> Version{old, time} <> tail)

def checkpoint(d: Diagram, stamp: String) -> Diagram:
  match d:
    case Diagram{i, n, +s, h}: Diagram{i, n, s, checkpoint_history(h, s, stamp)}

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

def apply(d: Diagram, a: Action) -> Diagram:
  match a:
    case Write{text}: edit(d, text)
    case Checkpoint{stamp}: checkpoint(d, stamp)
    case Restore{i, stamp}: restore(d, i, stamp)
    case Rename{name}: rename(d, name)

def maybe_apply(+d: Diagram, a: Action, selected: Bool) -> Diagram:
  match selected:
    case False{}: d
    case True{}: apply(d, a)

def edit_diagrams(ds: List<&2, Diagram>, +id: Nat, +a: Action) -> List<&2, Diagram>:
  match ds:
    case Nil{}: Nil{}
    case Diagram{+i, n, s, h} <> t:
      maybe_apply(Diagram{i, n, s, h}, a, Nat.is_eq(i, id)) <> edit_diagrams(t, id, a)

def edit_project(p: Project, id: Nat, a: Action, selected: Bool) -> Project:
  match p selected:
    case Project{i, n, ds, k, sn} False{}: Project{i, n, ds, k, sn}
    case Project{i, n, ds, k, sn} True{}: Project{i, n, edit_diagrams(ds, id, a), k, sn}

def edit_projects(ps: List<&2, Project>, +project: Nat, +diagram: Nat, +a: Action) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn} <> t:
      edit_project(Project{i, n, ds, k, sn}, diagram, a, Nat.is_eq(i, project)) <> edit_projects(t, project, diagram, a)

def update(w: Workspace, a: Action) -> Workspace:
  match w:
    case Workspace{ps, next, +p, +d, mode}: Workspace{edit_projects(ps, p, d, a), next, p, d, mode}

def find_diagram(ds: List<&2, Diagram>, +id: Nat) -> Maybe<&2, Diagram>:
  match ds:
    case Nil{}: None{}
    case Diagram{+i, +n, +s, +h} <> t:
      Bool.pick(Maybe<&2, Diagram>, Nat.is_eq(i, id), Some{Diagram{i, n, s, h}}, find_diagram(t, id))

def find_project(ps: List<&2, Project>, +project: Nat, +diagram: Nat) -> Maybe<&2, Diagram>:
  match ps:
    case Nil{}: None{}
    case Project{i, n, ds, k, sn} <> t:
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
  Diagram{id, name, "", Nil{}}

def create_project(w: Workspace, name: String) -> Workspace:
  match w:
    case Workspace{ps, +next, p, d, mode}:
      Workspace{Project{next, name, [new_diagram(1n+next, "Untitled diagram")], "", ""} <> ps, 2n+next, next, 1n+next, 1}

def add_diagram(ps: List<&2, Project>, +id: Nat, +doc: Diagram) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, +ds, k, sn} <> t:
      Project{i, n, Bool.pick(List<&2, Diagram>, Nat.is_eq(i, id), doc <> ds, ds), k, sn} <> add_diagram(t, id, doc)

def has_project(ps: List<&2, Project>, +id: Nat) -> Bool:
  match ps:
    case Nil{}: False{}
    case Project{i, n, ds, k, sn} <> t: Nat.is_eq(i, id) || has_project(t, id)

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
    case Project{+i, n, ds, k, sn} <> t:
      Project{i, Bool.pick(String, Nat.is_eq(i, id), name, n), ds, k, sn} <> rename_projects(t, id, name)

def rename_project(w: Workspace, id: Nat, name: String) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{rename_projects(ps, id, name), next, p, d, mode}

def diagram_count(ds: List<&2, Diagram>) -> Nat:
  match ds:
    case Nil{}: 0n
    case h <> t: 1n+diagram_count(t)

def project_span(ps: List<&2, Project>) -> Nat:
  match ps:
    case Nil{}: 0n
    case Project{i, n, ds, k, sn} <> t: (1n + diagram_count(ds) + project_span(t) : Nat)

def reindex_diagrams(ds: List<&2, Diagram>, +next: Nat) -> List<&2, Diagram>:
  match ds:
    case Nil{}: Nil{}
    case Diagram{i, n, s, h} <> t:
      Diagram{next, n, s, h} <> reindex_diagrams(t, 1n+next)

def reindex_projects(ps: List<&2, Project>, +next: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{i, n, +ds, k, sn} <> t:
      Project{next, n, reindex_diagrams(ds, 1n+next), k, sn} <> reindex_projects(t, (next + 1n + diagram_count(ds) : Nat))

def append_projects(a: List<&2, Project>, b: List<&2, Project>) -> List<&2, Project>:
  match a:
    case Nil{}: b
    case h <> t: h <> append_projects(t, b)

def select_first(w: Workspace) -> Workspace:
  match w:
    case Workspace{Project{+pid, name, Diagram{+did, title, text, h} <> ds, k, sn} <> ps, next, p, d, mode}:
      Workspace{Project{pid, name, Diagram{did, title, text, h} <> ds, k, sn} <> ps, next, pid, did, mode}
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
    case Workspace{[Project{1n, pn, [Diagram{2n, dn, text, [Version{old, time}]}], k, sn}], 3n, 1n, 2n, mode}:
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
    case Diagram{+i, n, s, h} <> t:
      keep_diagram(Diagram{i, n, s, h}, Nat.is_eq(i, id), drop_diagrams(t, id))

def drop_project(ps: List<&2, Project>, +id: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn} <> t:
      keep_project(Project{i, n, ds, k, sn}, Nat.is_eq(i, id), drop_project(t, id))

def drop_diagram(ps: List<&2, Project>, +project: Nat, +diagram: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, +ds, k, sn} <> t:
      Project{i, n, Bool.pick(List<&2, Diagram>, Nat.is_eq(i, project), drop_diagrams(ds, diagram), ds), k, sn} <> drop_diagram(t, project, diagram)

def first_location(ps: List<&2, Project>) -> Maybe<&2, Location>:
  match ps:
    case Nil{}: None{}
    case Project{i, n, Diagram{did, dn, s, h} <> ds, k, sn} <> t: Some{Location{i, did}}
    case Project{i, n, Nil{}, k, sn} <> t: first_location(t)

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
    case Project{i, n, ds, k, sn}: ds
