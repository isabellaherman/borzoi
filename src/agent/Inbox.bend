# Agents: an inbox key per project, and what happens when an agent sends a diagram.
import Base
import ../workspace/Workspace.bend as W

# ---------- Agent projects ----------
# An agent project has an inbox key (a normal project has none: ""). Agents send that inbox plain text, and each
# message becomes a new diagram in that project only: a message never changes a diagram that exists, nor another
# project. `seen` is the last message received, so the same message is never added twice.
def create_agent_project(w: W.Workspace, name: String, key: String) -> W.Workspace:
  match w:
    case W.Workspace{ps, +next, p, d, mode}:
      W.Workspace{W.Project{next, name, Nil{}, key, "", Nil{}} <> ps, 1n+next, p, d, mode}

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

def received(id: Nat, title: String, text: String) -> W.Diagram:
  W.Diagram{id, received_name(title), String.take(marked(text), 9000n), Nil{}, Nil{}}

# Only the chosen project, only when the key matches and the message is new.
def can_receive(ps: List<&2, W.Project>, +project: Nat, +key: String, +id: String) -> Bool:
  match ps:
    case Nil{}: False{}
    case W.Project{i, n, ds, k, sn, dcs} <> t:
      (Nat.is_eq(i, project) && String.eq(k, key) && Bool.not(String.eq(sn, id)) && Bool.not(String.is_empty(key))) || can_receive(t, project, key, id)

def deliver(p: W.Project, doc: W.Diagram, id: String, selected: Bool) -> W.Project:
  match p selected:
    case W.Project{i, n, ds, k, sn, dcs} False{}: W.Project{i, n, ds, k, sn, dcs}
    case W.Project{i, n, ds, k, sn, dcs} True{}: W.Project{i, n, doc <> ds, k, id, dcs}

def deliver_projects(ps: List<&2, W.Project>, +project: Nat, +id: String, +doc: W.Diagram) -> List<&2, W.Project>:
  match ps:
    case Nil{}: Nil{}
    case W.Project{+i, n, ds, k, sn, dcs} <> t:
      deliver(W.Project{i, n, ds, k, sn, dcs}, doc, id, Nat.is_eq(i, project)) <> deliver_projects(t, project, id, doc)

# ---------- An agent updates its own diagram ----------
# A message whose title names a diagram the agents sent before (it has a sender line) is a newer version of it:
# the current text goes to history first, so nothing is lost. Your own diagrams are never updated this way;
# a message with their name becomes a new diagram.
def is_agent_named(d: W.Diagram, +name: String) -> Bool:
  match d:
    case W.Diagram{i, n, s, h, wy}: String.eq(n, name) && Bool.not(String.is_empty(sender(s)))

def has_agent_named(ds: List<&2, W.Diagram>, +name: String) -> Bool:
  match ds:
    case Nil{}: False{}
    case +d <> t: is_agent_named(d, name) || has_agent_named(t, name)

def refresh(d: W.Diagram, +text: String, +stamp: String, selected: Bool) -> W.Diagram:
  match selected:
    case False{}: d
    case True{}: W.checkpoint(W.edit(W.checkpoint(d, stamp), text), stamp)

def refresh_diagrams(ds: List<&2, W.Diagram>, +name: String, +text: String, +stamp: String) -> List<&2, W.Diagram>:
  match ds:
    case Nil{}: Nil{}
    case +d <> t: refresh(d, text, stamp, is_agent_named(d, name)) <> refresh_diagrams(t, name, text, stamp)

def refresh_project(p: W.Project, +name: String, +text: String, +stamp: String, +id: String, selected: Bool) -> W.Project:
  match p selected:
    case W.Project{i, n, ds, k, sn, dcs} False{}: W.Project{i, n, ds, k, sn, dcs}
    case W.Project{i, n, ds, k, sn, dcs} True{}: W.Project{i, n, refresh_diagrams(ds, name, text, stamp), k, id, dcs}

def refresh_projects(ps: List<&2, W.Project>, +project: Nat, +name: String, +text: String, +stamp: String, +id: String) -> List<&2, W.Project>:
  match ps:
    case Nil{}: Nil{}
    case W.Project{+i, n, ds, k, sn, dcs} <> t:
      refresh_project(W.Project{i, n, ds, k, sn, dcs}, name, text, stamp, id, Nat.is_eq(i, project)) <> refresh_projects(t, project, name, text, stamp, id)

def updates_existing(ps: List<&2, W.Project>, +project: Nat, +name: String) -> Bool:
  match ps:
    case Nil{}: False{}
    case W.Project{i, n, ds, k, sn, dcs} <> t: (Nat.is_eq(i, project) && has_agent_named(ds, name)) || updates_existing(t, project, name)

def receive_checked(w: W.Workspace, +project: Nat, +id: String, +title: String, +text: String, +stamp: String, ok: Bool, update: Bool) -> W.Workspace:
  match w ok update:
    case W.Workspace{ps, next, p, d, mode} False{} False{}: W.Workspace{ps, next, p, d, mode}
    case W.Workspace{ps, next, p, d, mode} False{} True{}: W.Workspace{ps, next, p, d, mode}
    case W.Workspace{ps, +next, p, d, mode} True{} False{}:
      W.Workspace{deliver_projects(ps, project, id, received(next, title, text)), 1n+next, p, d, mode}
    case W.Workspace{ps, next, p, d, mode} True{} True{}:
      W.Workspace{refresh_projects(ps, project, received_name(title), String.take(marked(text), 9000n), stamp, id), next, p, d, mode}

# One message from an agent: a new diagram in its project, or a newer version of a diagram it sent before
# (same title). What is open stays open.
def receive(w: W.Workspace, +project: Nat, +key: String, +id: String, +title: String, +text: String, +stamp: String) -> W.Workspace:
  match w:
    case W.Workspace{+ps, next, p, d, mode}:
      receive_checked(W.Workspace{ps, next, p, d, mode}, project, id, title, text, stamp, can_receive(ps, project, key, id), updates_existing(ps, project, received_name(title)))

# A new key: the old one stops working. Only an agent project has one to change.
def rekey_projects(ps: List<&2, W.Project>, +project: Nat, +key: String) -> List<&2, W.Project>:
  match ps:
    case Nil{}: Nil{}
    case W.Project{+i, +n, +ds, +k, +sn, +dcs} <> t:
      Bool.pick(W.Project, Nat.is_eq(i, project) && Bool.not(String.is_empty(k)) && Bool.not(String.is_empty(key)), W.Project{i, n, ds, key, "", dcs}, W.Project{i, n, ds, k, sn, dcs}) <> rekey_projects(t, project, key)

def new_key(w: W.Workspace, +project: Nat, key: String) -> W.Workspace:
  match w:
    case W.Workspace{ps, next, p, d, mode}: W.Workspace{rekey_projects(ps, project, key), next, p, d, mode}

# A project you made can receive agent diagrams too: it gets an inbox key. Its diagrams stay as they are,
# and agents never change them (a message with one of their names becomes a new diagram).
# A project that already has a key keeps it; New key changes that one.
def connect_projects(ps: List<&2, W.Project>, +project: Nat, +key: String) -> List<&2, W.Project>:
  match ps:
    case Nil{}: Nil{}
    case W.Project{+i, +n, +ds, +k, +sn, +dcs} <> t:
      Bool.pick(W.Project, Nat.is_eq(i, project) && String.is_empty(k) && Bool.not(String.is_empty(key)), W.Project{i, n, ds, key, "", dcs}, W.Project{i, n, ds, k, sn, dcs}) <> connect_projects(t, project, key)

def connect_agent(w: W.Workspace, +project: Nat, key: String) -> W.Workspace:
  match w:
    case W.Workspace{ps, next, p, d, mode}: W.Workspace{connect_projects(ps, project, key), next, p, d, mode}
