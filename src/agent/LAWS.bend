# Agent laws: a message only adds or updates an agent's own diagram.
# Universal laws and finite regression laws are labeled separately.
import Base
import ../workspace/Workspace.bend as D
import ./Inbox.bend as A

# ---------- Agent projects: a message only adds a diagram ----------
# UNIVERSAL: a message for another project leaves that project exactly as it was.
law message_skips_other_projects:
  for +p: D.Project
  for doc: D.Diagram
  for id: String
  {A.deliver(p, doc, id, False{}) == p : D.Project}

# UNIVERSAL: a delivered message adds its diagram and keeps every diagram already there, unchanged.
law message_keeps_every_diagram:
  for +p: D.Project
  for +doc: D.Diagram
  for id: String
  {D.diagrams(A.deliver(p, doc, id, True{})) == doc <> D.diagrams(p) : List<&2, D.Diagram>}

# REGRESSION: a message becomes one new diagram, marked as sent by an agent; what is open stays open.
law message_adds_one_diagram:
  {A.receive(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "k", "", Nil{}}], 3n, 1n, 2n, 1}, 1n, "k", "m1", "Churn", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "Churn", "%% borzoi from agent\nflowchart TD", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "k", "m1", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: a wrong key changes nothing.
law wrong_key_changes_nothing:
  {A.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "k", "", Nil{}}], 2n, 0n, 0n, 1}, 1n, "x", "m1", "T", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "k", "", Nil{}}], 2n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: a normal project (no key) never receives.
law normal_project_never_receives:
  {A.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "", "", Nil{}}], 2n, 0n, 0n, 1}, 1n, "", "m1", "T", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "", "", Nil{}}], 2n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: the same message is added once.
law same_message_is_added_once:
  {A.receive(A.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "k", "", Nil{}}], 2n, 0n, 0n, 1}, 1n, "k", "m1", "T", "flowchart TD", "t"), 1n, "k", "m1", "T", "flowchart TD", "t") ==
   A.receive(D.Workspace{[D.Project{1n, "P", Nil{}, "k", "", Nil{}}], 2n, 0n, 0n, 1}, 1n, "k", "m1", "T", "flowchart TD", "t") : D.Workspace}

# REGRESSION: the sender's own name is kept and read back.
law sender_is_read:
  {A.sender("%% borzoi from Grok\nflowchart TD\n  A --> B") == "Grok" : String}

# REGRESSION: a new key replaces the old one; a normal project gets none.
# REGRESSION: a project you made gets an inbox key and keeps its diagrams; other projects don't change.
law connect_agent_gives_a_key:
  {A.connect_agent(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}, D.Project{3n, "Q", Nil{}, "", "", Nil{}}], 4n, 1n, 2n, 1}, 1n, "k") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "k", "", Nil{}}, D.Project{3n, "Q", Nil{}, "", "", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: connecting a project that already has a key keeps that key (agents that have it keep working).
law connect_agent_keeps_a_key:
  {A.connect_agent(D.Workspace{[D.Project{1n, "P", Nil{}, "k", "m1", Nil{}}], 2n, 0n, 0n, 1}, 1n, "n") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "k", "m1", Nil{}}], 2n, 0n, 0n, 1} : D.Workspace}

# REGRESSION: once connected, a message becomes a new diagram beside yours.
law connected_project_receives:
  {A.receive(A.connect_agent(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "", "", Nil{}}], 3n, 1n, 2n, 1}, 1n, "k"), 1n, "k", "m1", "Churn", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "Churn", "%% borzoi from agent\nflowchart TD", Nil{}, Nil{}}, D.Diagram{2n, "A", "a", Nil{}, Nil{}}], "k", "m1", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}

law new_key_replaces_the_old:
  {A.new_key(D.Workspace{[D.Project{1n, "P", Nil{}, "k", "m1", Nil{}}, D.Project{2n, "Q", Nil{}, "", "", Nil{}}], 3n, 0n, 0n, 1}, 1n, "n") ==
   D.Workspace{[D.Project{1n, "P", Nil{}, "n", "", Nil{}}, D.Project{2n, "Q", Nil{}, "", "", Nil{}}], 3n, 0n, 0n, 1} : D.Workspace}

law normal_project_gets_no_key:
  {A.new_key(D.Workspace{[D.Project{2n, "Q", Nil{}, "", "", Nil{}}], 3n, 0n, 0n, 1}, 2n, "n") ==
   D.Workspace{[D.Project{2n, "Q", Nil{}, "", "", Nil{}}], 3n, 0n, 0n, 1} : D.Workspace}

# UNIVERSAL: an update for another diagram leaves it exactly as it was.
law update_skips_other_diagrams:
  for +d: D.Diagram
  for text: String
  for stamp: String
  {A.refresh(d, text, stamp, False{}) == d : D.Diagram}

# UNIVERSAL: an update shows the agent's new text.
law update_shows_the_new_text:
  for d: D.Diagram
  for +text: String
  for +stamp: String
  {D.source(A.refresh(d, text, stamp, True{})) == text : String}

# REGRESSION: the same title updates the agent's diagram; the old text is kept in its history.
law same_title_updates_with_history:
  {A.receive(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "Churn", "%% borzoi from Grok\nflowchart TD", Nil{}, Nil{}}], "k", "m1", Nil{}}], 3n, 1n, 2n, 1}, 1n, "k", "m2", "Churn", "%% borzoi from Grok\nflowchart TD\n  A --> B", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "Churn", "%% borzoi from Grok\nflowchart TD\n  A --> B", [D.Version{"%% borzoi from Grok\nflowchart TD\n  A --> B", "t"}, D.Version{"%% borzoi from Grok\nflowchart TD", "t"}], Nil{}}], "k", "m2", Nil{}}], 3n, 1n, 2n, 1} : D.Workspace}

# REGRESSION: your own diagram is never updated by an agent; a message with its name becomes a new diagram.
law your_diagram_is_never_updated:
  {A.receive(D.Workspace{[D.Project{1n, "P", [D.Diagram{2n, "Churn", "flowchart TD", Nil{}, Nil{}}], "k", "", Nil{}}], 3n, 1n, 2n, 1}, 1n, "k", "m1", "Churn", "flowchart TD", "t") ==
   D.Workspace{[D.Project{1n, "P", [D.Diagram{3n, "Churn", "%% borzoi from agent\nflowchart TD", Nil{}, Nil{}}, D.Diagram{2n, "Churn", "flowchart TD", Nil{}, Nil{}}], "k", "m1", Nil{}}], 4n, 1n, 2n, 1} : D.Workspace}
