# The workspace state and every user-visible mutation live in Bend.
import Base

type Version is Data:
  Version{source: String, stamp: String}
type Document is Data:
  Document{id: Nat, name: String, source: String, history: List<&2, Version>}
type Project is Data:
  Project{id: Nat, name: String, documents: List<&2, Document>, inbox: String, seen: String}
type Workspace is Data:
  Workspace{projects: List<&2, Project>, next_id: Nat, project: Nat, document: Nat, mode: U32}
type Action is Data:
  Write{source: String}
  Checkpoint{stamp: String}
  Restore{index: Nat, stamp: String}
  Rename{name: String}

def source(d: Document) -> String:
  match d:
    case Document{i, n, s, h}: s

def history(d: Document) -> List<&2, Version>:
  match d:
    case Document{i, n, s, h}: h

def edit(d: Document, text: String) -> Document:
  match d:
    case Document{i, n, s, h}: Document{i, n, text, h}

def rename(d: Document, name: String) -> Document:
  match d:
    case Document{i, n, s, h}: Document{i, name, s, h}

def checkpoint_history(xs: List<&2, Version>, +text: String, stamp: String) -> List<&2, Version>:
  match xs:
    case Nil{}: Bool.pick(List<&2, Version>, String.is_empty(text), Nil{}, [Version{text, stamp}])
    case Version{+old, +time} <> +tail:
      Bool.pick(List<&2, Version>, String.eq(old, text),
        Version{old, time} <> tail,
        Version{text, stamp} <> Version{old, time} <> tail)

def checkpoint(d: Document, stamp: String) -> Document:
  match d:
    case Document{i, n, +s, h}: Document{i, n, s, checkpoint_history(h, s, stamp)}

def version_at(xs: List<&2, Version>, i: Nat) -> Maybe<&2, Version>:
  match xs i:
    case Nil{} _: None{}
    case h <> t 0n: Some{h}
    case h <> t 1n+k: version_at(t, k)

def restore_version(d: Document, v: Maybe<&2, Version>, +stamp: String) -> Document:
  match v:
    case None{}: d
    case Some{Version{text, time}}: checkpoint(edit(checkpoint(d, stamp), text), stamp)

def restore(+d: Document, index: Nat, stamp: String) -> Document:
  restore_version(d, version_at(history(d), index), stamp)

def apply(d: Document, a: Action) -> Document:
  match a:
    case Write{text}: edit(d, text)
    case Checkpoint{stamp}: checkpoint(d, stamp)
    case Restore{i, stamp}: restore(d, i, stamp)
    case Rename{name}: rename(d, name)

def maybe_apply(+d: Document, a: Action, selected: Bool) -> Document:
  match selected:
    case False{}: d
    case True{}: apply(d, a)

def edit_documents(ds: List<&2, Document>, +id: Nat, +a: Action) -> List<&2, Document>:
  match ds:
    case Nil{}: Nil{}
    case Document{+i, n, s, h} <> t:
      maybe_apply(Document{i, n, s, h}, a, Nat.is_eq(i, id)) <> edit_documents(t, id, a)

def edit_project(p: Project, id: Nat, a: Action, selected: Bool) -> Project:
  match p selected:
    case Project{i, n, ds, k, sn} False{}: Project{i, n, ds, k, sn}
    case Project{i, n, ds, k, sn} True{}: Project{i, n, edit_documents(ds, id, a), k, sn}

def edit_projects(ps: List<&2, Project>, +project: Nat, +document: Nat, +a: Action) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn} <> t:
      edit_project(Project{i, n, ds, k, sn}, document, a, Nat.is_eq(i, project)) <> edit_projects(t, project, document, a)

def update(w: Workspace, a: Action) -> Workspace:
  match w:
    case Workspace{ps, next, +p, +d, mode}: Workspace{edit_projects(ps, p, d, a), next, p, d, mode}

def find_document(ds: List<&2, Document>, +id: Nat) -> Maybe<&2, Document>:
  match ds:
    case Nil{}: None{}
    case Document{+i, +n, +s, +h} <> t:
      Bool.pick(Maybe<&2, Document>, Nat.is_eq(i, id), Some{Document{i, n, s, h}}, find_document(t, id))

def find_project(ps: List<&2, Project>, +project: Nat, +document: Nat) -> Maybe<&2, Document>:
  match ps:
    case Nil{}: None{}
    case Project{i, n, ds, k, sn} <> t:
      Bool.pick(Maybe<&2, Document>, Nat.is_eq(i, project), find_document(ds, document), find_project(t, project, document))

def current(w: Workspace) -> Maybe<&2, Document>:
  match w:
    case Workspace{ps, next, p, d, mode}: find_project(ps, p, d)

def open_checked(w: Workspace, project: Nat, document: Nat, exists: Maybe<&2, Document>) -> Workspace:
  match w exists:
    case Workspace{ps, next, p, d, mode} None{}: Workspace{ps, next, p, d, mode}
    case Workspace{ps, next, p, d, mode} Some{doc}: Workspace{ps, next, project, document, mode}

def open(+w: Workspace, +project: Nat, +document: Nat) -> Workspace:
  match w:
    case Workspace{+ps, next, p, d, mode}:
      open_checked(Workspace{ps, next, p, d, mode}, project, document, find_project(ps, project, document))

def set_mode(w: Workspace, mode: U32) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, m}: Workspace{ps, next, p, d, Bool.pick(U32, U32.is_eq(mode, 1), 1, 0)}

def new_document(id: Nat, name: String) -> Document:
  Document{id, name, "", Nil{}}

def create_project(w: Workspace, name: String) -> Workspace:
  match w:
    case Workspace{ps, +next, p, d, mode}:
      Workspace{Project{next, name, [new_document(1n+next, "Untitled diagram")], "", ""} <> ps, 2n+next, next, 1n+next, 1}

def add_document(ps: List<&2, Project>, +id: Nat, +doc: Document) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, +ds, k, sn} <> t:
      Project{i, n, Bool.pick(List<&2, Document>, Nat.is_eq(i, id), doc <> ds, ds), k, sn} <> add_document(t, id, doc)

def has_project(ps: List<&2, Project>, +id: Nat) -> Bool:
  match ps:
    case Nil{}: False{}
    case Project{i, n, ds, k, sn} <> t: Nat.is_eq(i, id) || has_project(t, id)

def create_diagram_checked(w: Workspace, +project: Nat, name: String, valid: Bool) -> Workspace:
  match w valid:
    case Workspace{ps, next, p, d, mode} False{}: Workspace{ps, next, p, d, mode}
    case Workspace{ps, +next, p, d, mode} True{}:
      Workspace{add_document(ps, project, new_document(next, name)), 1n+next, project, next, 1}

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

def document_count(ds: List<&2, Document>) -> Nat:
  match ds:
    case Nil{}: 0n
    case h <> t: 1n+document_count(t)

def project_span(ps: List<&2, Project>) -> Nat:
  match ps:
    case Nil{}: 0n
    case Project{i, n, ds, k, sn} <> t: (1n + document_count(ds) + project_span(t) : Nat)

def reindex_documents(ds: List<&2, Document>, +next: Nat) -> List<&2, Document>:
  match ds:
    case Nil{}: Nil{}
    case Document{i, n, s, h} <> t:
      Document{next, n, s, h} <> reindex_documents(t, 1n+next)

def reindex_projects(ps: List<&2, Project>, +next: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{i, n, +ds, k, sn} <> t:
      Project{next, n, reindex_documents(ds, 1n+next), k, sn} <> reindex_projects(t, (next + 1n + document_count(ds) : Nat))

def append_projects(a: List<&2, Project>, b: List<&2, Project>) -> List<&2, Project>:
  match a:
    case Nil{}: b
    case h <> t: h <> append_projects(t, b)

def select_first(w: Workspace) -> Workspace:
  match w:
    case Workspace{Project{+pid, name, Document{+did, title, text, h} <> ds, k, sn} <> ps, next, p, d, mode}:
      Workspace{Project{pid, name, Document{did, title, text, h} <> ds, k, sn} <> ps, next, pid, did, mode}
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

# Materialize a document only when the user writes their first source.
def write_source_checked(+w: Workspace, +text: String, selected: Maybe<&2, Document>) -> Workspace:
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
    case Workspace{[Project{1n, pn, [Document{2n, dn, text, [Version{old, time}]}], k, sn}], 3n, 1n, 2n, mode}:
      String.eq(pn, "Research notebook") && String.eq(dn, "A research flow") &&
      String.eq(text, legacy_demo_source()) && String.eq(old, legacy_demo_source()) && String.eq(time, "Created")
    case other: False{}

def remove_legacy_demo(+w: Workspace) -> Workspace:
  Bool.pick(Workspace, is_legacy_demo(w), initial(), w)

# ---------- Delete a project or a diagram ----------
# Only the chosen one goes. If it was open, the first diagram left opens; with none left, nothing is open.
type Location is Data:
  Location{project: Nat, document: Nat}

def keep_document(d: Document, drop: Bool, rest: List<&2, Document>) -> List<&2, Document>:
  match drop:
    case True{}: rest
    case False{}: d <> rest

def keep_project(p: Project, drop: Bool, rest: List<&2, Project>) -> List<&2, Project>:
  match drop:
    case True{}: rest
    case False{}: p <> rest

def drop_documents(ds: List<&2, Document>, +id: Nat) -> List<&2, Document>:
  match ds:
    case Nil{}: Nil{}
    case Document{+i, n, s, h} <> t:
      keep_document(Document{i, n, s, h}, Nat.is_eq(i, id), drop_documents(t, id))

def drop_project(ps: List<&2, Project>, +id: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn} <> t:
      keep_project(Project{i, n, ds, k, sn}, Nat.is_eq(i, id), drop_project(t, id))

def drop_diagram(ps: List<&2, Project>, +project: Nat, +document: Nat) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, +ds, k, sn} <> t:
      Project{i, n, Bool.pick(List<&2, Document>, Nat.is_eq(i, project), drop_documents(ds, document), ds), k, sn} <> drop_diagram(t, project, document)

def first_location(ps: List<&2, Project>) -> Maybe<&2, Location>:
  match ps:
    case Nil{}: None{}
    case Project{i, n, Document{did, dn, s, h} <> ds, k, sn} <> t: Some{Location{i, did}}
    case Project{i, n, Nil{}, k, sn} <> t: first_location(t)

def reselect(w: Workspace, there: Maybe<&2, Location>) -> Workspace:
  match w there:
    case Workspace{ps, next, p, d, mode} None{}: Workspace{ps, next, 0n, 0n, mode}
    case Workspace{ps, next, p, d, mode} Some{Location{lp, ld}}: Workspace{ps, next, lp, ld, mode}

def settle_checked(w: Workspace, here: Maybe<&2, Document>, first: Maybe<&2, Location>) -> Workspace:
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

def delete_diagram(w: Workspace, +project: Nat, +document: Nat) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: settle(Workspace{drop_diagram(ps, project, document), next, p, d, mode})

# Rename any diagram by its ids, open or not.
def rename_diagram(w: Workspace, +project: Nat, +document: Nat, name: String) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{edit_projects(ps, project, document, Rename{name}), next, p, d, mode}

# ---------- Agent projects ----------
# An agent project has an inbox key (a normal project has none: ""). Agents send that inbox plain text, and each
# message becomes a new diagram in that project only: a message never changes a diagram that exists, nor another
# project. `seen` is the last message received, so the same message is never added twice.
def create_agent_project(w: Workspace, name: String, key: String) -> Workspace:
  match w:
    case Workspace{ps, +next, p, d, mode}:
      Workspace{Project{next, name, Nil{}, key, ""} <> ps, 1n+next, p, d, mode}

# A received diagram says who sent it in a Mermaid comment, `%% borzoi from <name>`; other tools ignore it.
def from_prefix() -> String:
  "%% borzoi from "

def is_from_line(+line: String) -> Bool:
  String.starts_with(String.trim(line), from_prefix())

def sender.go(ls: List<&2, String>) -> String:
  match ls:
    case Nil{}: ""
    case +l <> t:
      Bool.pick(String, is_from_line(l), String.trim(String.drop(String.trim(l), String.length(from_prefix()))), sender.go(t))

# Who sent this diagram; "" when nobody did (you made it).
def sender(source: String) -> String:
  sender.go(String.lines(source))

# Text with no sender line gets one, so it always shows it came from an agent.
def marked(+text: String) -> String:
  Bool.pick(String, String.is_empty(sender(text)), String.append(String.append(from_prefix(), "agent\n"), text), text)

# Names and sources are capped well under the backup's limits (120 and 20,000 characters).
def received_name(+title: String) -> String:
  Bool.pick(String, String.is_empty(String.trim(title)), "Agent diagram", String.take(String.trim(title), 60n))

def received(id: Nat, title: String, text: String) -> Document:
  Document{id, received_name(title), String.take(marked(text), 9000n), Nil{}}

# Only the chosen project, only when the key matches and the message is new.
def can_receive(ps: List<&2, Project>, +project: Nat, +key: String, +id: String) -> Bool:
  match ps:
    case Nil{}: False{}
    case Project{i, n, ds, k, sn} <> t:
      (Nat.is_eq(i, project) && String.eq(k, key) && Bool.not(String.eq(sn, id)) && Bool.not(String.is_empty(key))) || can_receive(t, project, key, id)

def deliver(p: Project, doc: Document, id: String, selected: Bool) -> Project:
  match p selected:
    case Project{i, n, ds, k, sn} False{}: Project{i, n, ds, k, sn}
    case Project{i, n, ds, k, sn} True{}: Project{i, n, doc <> ds, k, id}

def deliver_projects(ps: List<&2, Project>, +project: Nat, +id: String, +doc: Document) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, n, ds, k, sn} <> t:
      deliver(Project{i, n, ds, k, sn}, doc, id, Nat.is_eq(i, project)) <> deliver_projects(t, project, id, doc)

def receive_checked(w: Workspace, +project: Nat, +id: String, +title: String, +text: String, ok: Bool) -> Workspace:
  match w ok:
    case Workspace{ps, next, p, d, mode} False{}: Workspace{ps, next, p, d, mode}
    case Workspace{ps, +next, p, d, mode} True{}:
      Workspace{deliver_projects(ps, project, id, received(next, title, text)), 1n+next, p, d, mode}

# One message from an agent: a new diagram in its project. What is open stays open.
def receive(w: Workspace, +project: Nat, +key: String, +id: String, +title: String, +text: String) -> Workspace:
  match w:
    case Workspace{+ps, next, p, d, mode}:
      receive_checked(Workspace{ps, next, p, d, mode}, project, id, title, text, can_receive(ps, project, key, id))

# A new key: the old one stops working. Only an agent project has one to change.
def rekey_projects(ps: List<&2, Project>, +project: Nat, +key: String) -> List<&2, Project>:
  match ps:
    case Nil{}: Nil{}
    case Project{+i, +n, +ds, +k, +sn} <> t:
      Bool.pick(Project, Nat.is_eq(i, project) && Bool.not(String.is_empty(k)) && Bool.not(String.is_empty(key)), Project{i, n, ds, key, ""}, Project{i, n, ds, k, sn}) <> rekey_projects(t, project, key)

def new_key(w: Workspace, +project: Nat, key: String) -> Workspace:
  match w:
    case Workspace{ps, next, p, d, mode}: Workspace{rekey_projects(ps, project, key), next, p, d, mode}

def documents(p: Project) -> List<&2, Document>:
  match p:
    case Project{i, n, ds, k, sn}: ds
