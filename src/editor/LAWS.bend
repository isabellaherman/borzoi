# Editor laws: the block document, its steps and their inverses, positions, history, commands and Markdown.
# Universal laws and finite regression laws are labeled separately.
import Base
import ./Editor.bend as E
import ./Markdown.bend as M

# A document with a heading, a paragraph, a figure with a caption and a list item.
def sample() -> List<&2, E.Block>:
  [E.Block{E.Head{1}, "Title", 0, 0}, E.Block{E.Para{}, "Hello world", 0, 0},
   E.Block{E.Figure{"mermaid", "flowchart TD\n  A --> B"}, "Flow", 1, 0}, E.Block{E.Bullet{}, "item", 0, 0}]

# A step, then its inverse.
def there_and_back(+d: List<&2, E.Block>, +s: E.Step) -> List<&2, E.Block>:
  E.apply(E.apply(d, s), E.invert(d, s))

# ---------- Steps ----------

# UNIVERSAL: the step that does nothing changes no document, and its inverse does nothing either.
law skip_changes_nothing:
  for d: List<&2, E.Block>
  {E.apply(d, E.Skip{}) == d : List<&2, E.Block>}

law skip_is_undone_by_skip:
  for +d: List<&2, E.Block>
  {E.invert(d, E.Skip{}) == E.Skip{} : E.Step}

# UNIVERSAL: changing what a block is, its alignment or its place moves no position.
law kind_moves_no_position:
  for +d: List<&2, E.Block>
  for at: Nat
  for k: E.Form
  for p: E.Pos
  {E.map_pos(d, E.SetKind{at, k}, p) == p : E.Pos}

law align_moves_no_position:
  for +d: List<&2, E.Block>
  for at: Nat
  for a: U32
  for p: E.Pos
  {E.map_pos(d, E.SetAlign{at, a}, p) == p : E.Pos}

law place_moves_no_position:
  for +d: List<&2, E.Block>
  for at: Nat
  for q: U32
  for p: E.Pos
  {E.map_pos(d, E.SetPlace{at, q}, p) == p : E.Pos}

# REGRESSION: every kind of step, followed by its inverse, gives the document back.
law replace_is_undone:
  {there_and_back(sample(), E.Replace{1n, 5n, 11n, "!"}) == sample() : List<&2, E.Block>}

law split_is_undone:
  {there_and_back(sample(), E.Split{1n, 5n, E.Para{}, 0, 0}) == sample() : List<&2, E.Block>}

law join_is_undone:
  {there_and_back(sample(), E.Join{1n}) == sample() : List<&2, E.Block>}

law insert_is_undone:
  {there_and_back(sample(), E.Insert{2n, E.Block{E.Quote{}, "new", 0, 0}}) == sample() : List<&2, E.Block>}

law remove_is_undone:
  {there_and_back(sample(), E.Remove{2n}) == sample() : List<&2, E.Block>}

law kind_is_undone:
  {there_and_back(sample(), E.SetKind{1n, E.Head{2}}) == sample() : List<&2, E.Block>}

law align_is_undone:
  {there_and_back(sample(), E.SetAlign{2n, 2}) == sample() : List<&2, E.Block>}

law place_is_undone:
  {there_and_back(sample(), E.SetPlace{2n, 1}) == sample() : List<&2, E.Block>}

law move_is_undone:
  {there_and_back(sample(), E.Carry{0n, 3n}) == sample() : List<&2, E.Block>}

# REGRESSION: a step on a block that isn't there changes nothing, and its inverse is the step that does nothing.
law step_past_the_end_changes_nothing:
  {E.apply(sample(), E.Remove{9n}) == sample() : List<&2, E.Block>}

law step_past_the_end_is_undone_by_skip:
  {E.invert(sample(), E.Remove{9n}) == E.Skip{} : E.Step}

# REGRESSION: a replacement changes only its range.
law replace_changes_only_its_range:
  {E.apply([E.Block{E.Para{}, "Hello world", 0, 0}], E.Replace{0n, 0n, 5n, "Bye"}) == [E.Block{E.Para{}, "Bye world", 0, 0}] : List<&2, E.Block>}

# REGRESSION: the schema. A line break never enters a block's text; a heading's level, the alignment and the
# place take known values only.
law line_breaks_never_enter_a_block:
  {E.apply([E.Block{E.Para{}, "ab", 0, 0}], E.Replace{0n, 1n, 1n, "x\ny"}) == [E.Block{E.Para{}, "ax yb", 0, 0}] : List<&2, E.Block>}

law schema_fits_values:
  {E.fit(E.Block{E.Head{9}, "a\nb", 7, 5}) == E.Block{E.Head{3}, "a b", 0, 0} : E.Block}

# REGRESSION: a moved block lands where the step says.
law move_lands_at_its_place:
  {E.apply(sample(), E.Carry{3n, 0n}) ==
   [E.Block{E.Bullet{}, "item", 0, 0}, E.Block{E.Head{1}, "Title", 0, 0}, E.Block{E.Para{}, "Hello world", 0, 0},
    E.Block{E.Figure{"mermaid", "flowchart TD\n  A --> B"}, "Flow", 1, 0}] : List<&2, E.Block>}

# ---------- Positions ----------

# REGRESSION: a position after typed text moves with it; one before it stays.
law position_moves_with_typed_text:
  {E.map_pos(sample(), E.Replace{1n, 5n, 5n, "abc"}, E.Pos{1n, 5n}) == E.Pos{1n, 8n} : E.Pos}

law position_before_typed_text_stays:
  {E.map_pos(sample(), E.Replace{1n, 5n, 5n, "abc"}, E.Pos{1n, 2n}) == E.Pos{1n, 2n} : E.Pos}

law position_follows_a_split:
  {E.map_pos(sample(), E.Split{1n, 5n, E.Para{}, 0, 0}, E.Pos{1n, 7n}) == E.Pos{2n, 2n} : E.Pos}

law position_follows_a_join:
  {E.map_pos(sample(), E.Join{1n}, E.Pos{1n, 3n}) == E.Pos{0n, 8n} : E.Pos}

law position_follows_a_moved_block:
  {E.map_pos(sample(), E.Carry{0n, 3n}, E.Pos{0n, 2n}) == E.Pos{3n, 2n} : E.Pos}

law position_steps_back_past_a_moved_block:
  {E.map_pos(sample(), E.Carry{0n, 3n}, E.Pos{2n, 1n}) == E.Pos{1n, 1n} : E.Pos}

law position_after_an_inserted_block:
  {E.map_pos(sample(), E.Insert{1n, E.Block{E.Para{}, "", 0, 0}}, E.Pos{1n, 4n}) == E.Pos{2n, 4n} : E.Pos}

law position_after_a_removed_block:
  {E.map_pos(sample(), E.Remove{0n}, E.Pos{3n, 1n}) == E.Pos{2n, 1n} : E.Pos}

# ---------- History ----------

# UNIVERSAL: with nothing to undo or to redo, undo and redo change nothing.
law undo_of_nothing:
  for d: List<&2, E.Block>
  for r: List<&2, E.Entry>
  for c: E.Pos
  {E.undo(E.Editor{d, Nil{}, r, c}) == E.Editor{d, Nil{}, r, c} : E.Editor}

law redo_of_nothing:
  for d: List<&2, E.Block>
  for u: List<&2, E.Entry>
  for c: E.Pos
  {E.redo(E.Editor{d, u, Nil{}, c}) == E.Editor{d, u, Nil{}, c} : E.Editor}

# UNIVERSAL: a command with no steps leaves the editor, and its history, exactly as it was.
law no_steps_no_entry:
  for +e: E.Editor
  for before: E.Pos
  for after: E.Pos
  for typing: Bool
  for time: U32
  {E.commit_some(e, before, E.Plan{Nil{}, after}, typing, time) == e : E.Editor}

# REGRESSION: a document with no blocks opens with one empty paragraph to write in.
law empty_opens_with_a_paragraph:
  {E.start(Nil{}) == E.Editor{[E.Block{E.Para{}, "", 0, 0}], Nil{}, Nil{}, E.Pos{0n, 0n}} : E.Editor}

# REGRESSION: undo gives the document back, with the caret where it was; redo makes the change again.
law undo_gives_the_document_back:
  {E.doc(E.undo(E.enter(E.start(sample()), E.Pos{1n, 2n}, E.Pos{3n, 2n}, 0))) == sample() : List<&2, E.Block>}

law undo_puts_the_caret_back:
  {E.caret(E.undo(E.enter(E.start(sample()), E.Pos{1n, 5n}, E.Pos{1n, 5n}, 0))) == E.Pos{1n, 5n} : E.Pos}

law redo_makes_the_change_again:
  {E.doc(E.redo(E.undo(E.enter(E.start(sample()), E.Pos{1n, 5n}, E.Pos{1n, 5n}, 0)))) ==
   E.doc(E.enter(E.start(sample()), E.Pos{1n, 5n}, E.Pos{1n, 5n}, 0)) : List<&2, E.Block>}

# REGRESSION: letters typed one after the other, within a second, are undone together; after a pause, apart.
law a_run_of_typing_is_one_undo:
  {E.doc(E.undo(E.write(E.write(E.start(Nil{}), 0n, "a", 1n, 0), 0n, "ab", 2n, 100))) == [E.Block{E.Para{}, "", 0, 0}] : List<&2, E.Block>}

law typing_after_a_pause_is_its_own_undo:
  {E.doc(E.undo(E.write(E.write(E.start(Nil{}), 0n, "a", 1n, 0), 0n, "ab", 2n, 5000))) == [E.Block{E.Para{}, "a", 0, 0}] : List<&2, E.Block>}

# ---------- Commands ----------

# REGRESSION: typing is the smallest replacement that makes the new text.
law typing_is_the_smallest_replacement:
  {E.diff(0n, "Hello world", "Hello brave world") == E.Replace{0n, 6n, 6n, "brave "} : E.Step}

# REGRESSION: Markdown shortcuts. `# ` at the start of a paragraph makes it a heading and the mark goes away.
law hash_makes_a_heading:
  {E.doc(E.write(E.start(Nil{}), 0n, "# ", 2n, 0)) == [E.Block{E.Head{1}, "", 0, 0}] : List<&2, E.Block>}

law dash_makes_a_list_item:
  {E.doc(E.write(E.start([E.Block{E.Para{}, "milk", 0, 0}]), 0n, "- milk", 2n, 0)) == [E.Block{E.Bullet{}, "milk", 0, 0}] : List<&2, E.Block>}

law shortcut_only_in_a_paragraph:
  {E.doc(E.write(E.start([E.Block{E.Quote{}, "", 0, 0}]), 0n, "# ", 2n, 0)) == [E.Block{E.Quote{}, "# ", 0, 0}] : List<&2, E.Block>}

# REGRESSION: Enter.
law enter_splits_a_paragraph:
  {E.doc(E.enter(E.start([E.Block{E.Para{}, "Hello world", 0, 0}]), E.Pos{0n, 5n}, E.Pos{0n, 5n}, 0)) ==
   [E.Block{E.Para{}, "Hello", 0, 0}, E.Block{E.Para{}, " world", 0, 0}] : List<&2, E.Block>}

law enter_goes_on_with_a_list:
  {E.doc(E.enter(E.start([E.Block{E.Bullet{}, "one", 0, 0}]), E.Pos{0n, 3n}, E.Pos{0n, 3n}, 0)) ==
   [E.Block{E.Bullet{}, "one", 0, 0}, E.Block{E.Bullet{}, "", 0, 0}] : List<&2, E.Block>}

law enter_on_an_empty_item_leaves_the_list:
  {E.doc(E.enter(E.start([E.Block{E.Bullet{}, "one", 0, 0}, E.Block{E.Bullet{}, "", 0, 0}]), E.Pos{1n, 0n}, E.Pos{1n, 0n}, 0)) ==
   [E.Block{E.Bullet{}, "one", 0, 0}, E.Block{E.Para{}, "", 0, 0}] : List<&2, E.Block>}

law enter_after_a_heading_is_a_paragraph:
  {E.doc(E.enter(E.start([E.Block{E.Head{2}, "Plan", 0, 0}]), E.Pos{0n, 4n}, E.Pos{0n, 4n}, 0)) ==
   [E.Block{E.Head{2}, "Plan", 0, 0}, E.Block{E.Para{}, "", 0, 0}] : List<&2, E.Block>}

law enter_in_a_caption_writes_under_the_figure:
  {E.doc(E.enter(E.start([E.Block{E.Figure{"mermaid", "x"}, "Cap", 0, 0}]), E.Pos{0n, 1n}, E.Pos{0n, 1n}, 0)) ==
   [E.Block{E.Figure{"mermaid", "x"}, "Cap", 0, 0}, E.Block{E.Para{}, "", 0, 0}] : List<&2, E.Block>}

# REGRESSION: Backspace at the start of a block.
law backspace_joins_the_block_before:
  {E.doc(E.backspace(E.start([E.Block{E.Para{}, "Hello", 0, 0}, E.Block{E.Para{}, " world", 0, 0}]), E.Pos{1n, 0n}, E.Pos{1n, 0n}, 0)) ==
   [E.Block{E.Para{}, "Hello world", 0, 0}] : List<&2, E.Block>}

law backspace_makes_a_heading_a_paragraph:
  {E.doc(E.backspace(E.start(sample()), E.Pos{0n, 0n}, E.Pos{0n, 0n}, 0)) ==
   E.apply(sample(), E.SetKind{0n, E.Para{}}) : List<&2, E.Block>}

law backspace_never_joins_a_figure:
  {E.doc(E.backspace(E.start(sample()), E.Pos{3n, 0n}, E.Pos{3n, 0n}, 0)) ==
   E.apply(sample(), E.SetKind{3n, E.Para{}}) : List<&2, E.Block>}

# REGRESSION: a selection across blocks goes away as one, the figure in the middle included, and the ends join.
law selection_across_blocks_is_taken_out:
  {E.doc(E.cut(E.start(sample()), E.Pos{0n, 2n}, E.Pos{3n, 2n}, 0)) == [E.Block{E.Head{1}, "Tiem", 0, 0}] : List<&2, E.Block>}

law a_letter_typed_over_a_selection:
  {E.doc(E.put(E.start(sample()), E.Pos{1n, 0n}, E.Pos{1n, 5n}, "Bye", 0)) ==
   E.apply(sample(), E.Replace{1n, 0n, 5n, "Bye"}) : List<&2, E.Block>}

# REGRESSION: a figure takes the place of an empty paragraph, goes under a block with text, and always has
# a paragraph after it.
law figure_takes_an_empty_paragraph:
  {E.doc(E.insert_figure(E.start(Nil{}), E.Pos{0n, 0n}, "mermaid", "x", 0)) ==
   [E.Block{E.Figure{"mermaid", "x"}, "", 0, 0}, E.Block{E.Para{}, "", 0, 0}] : List<&2, E.Block>}

law figure_goes_under_text:
  {E.doc(E.insert_figure(E.start([E.Block{E.Para{}, "a", 0, 0}, E.Block{E.Para{}, "b", 0, 0}]), E.Pos{0n, 1n}, "mermaid", "x", 0)) ==
   [E.Block{E.Para{}, "a", 0, 0}, E.Block{E.Figure{"mermaid", "x"}, "", 0, 0}, E.Block{E.Para{}, "b", 0, 0}] : List<&2, E.Block>}

law caret_goes_after_the_figure:
  {E.caret(E.insert_figure(E.start(Nil{}), E.Pos{0n, 0n}, "mermaid", "x", 0)) == E.Pos{1n, 0n} : E.Pos}

# REGRESSION: taking out the only block leaves an empty paragraph.
law last_block_out_leaves_a_paragraph:
  {E.doc(E.remove_block(E.start([E.Block{E.Figure{"mermaid", "x"}, "", 0, 0}]), 0n, 0)) == [E.Block{E.Para{}, "", 0, 0}] : List<&2, E.Block>}

# REGRESSION: pasted blocks go under the block with the caret; one pasted paragraph goes into the text.
law pasted_blocks_go_under:
  {E.doc(E.paste(E.start([E.Block{E.Para{}, "a", 0, 0}]), E.Pos{0n, 1n}, E.Pos{0n, 1n}, [E.Block{E.Head{1}, "T", 0, 0}, E.Block{E.Para{}, "x", 0, 0}], 0)) ==
   [E.Block{E.Para{}, "a", 0, 0}, E.Block{E.Head{1}, "T", 0, 0}, E.Block{E.Para{}, "x", 0, 0}] : List<&2, E.Block>}

law pasted_line_goes_into_the_text:
  {E.doc(E.paste(E.start([E.Block{E.Para{}, "ab", 0, 0}]), E.Pos{0n, 1n}, E.Pos{0n, 1n}, [E.Block{E.Para{}, "X", 0, 0}], 0)) ==
   [E.Block{E.Para{}, "aXb", 0, 0}] : List<&2, E.Block>}

# ---------- Markdown ----------

# REGRESSION: the document is written in standard Markdown.
law markdown_of_a_document:
  {M.write(sample()) == "# Title\n\nHello world\n\n::: {.figure .center}\n```mermaid\nflowchart TD\n  A --> B\n```\nFlow\n:::\n\n- item" : String}

# REGRESSION: what is written is read back as the same document.
law markdown_is_read_back:
  {M.read(M.write(sample())) == sample() : List<&2, E.Block>}

law lists_are_read_back:
  {M.read("- a\n- b\n\n1. one\n2. two\n\n> said") ==
   [E.Block{E.Bullet{}, "a", 0, 0}, E.Block{E.Bullet{}, "b", 0, 0}, E.Block{E.Number{}, "one", 0, 0}, E.Block{E.Number{}, "two", 0, 0}, E.Block{E.Quote{}, "said", 0, 0}] : List<&2, E.Block>}

law lists_are_written_back:
  {M.write(M.read("- a\n- b\n\n1. one\n2. two\n\n> said")) == "- a\n- b\n\n1. one\n2. two\n\n> said" : String}

# REGRESSION: alignment and the top of the page are Pandoc fenced divs.
law alignment_is_a_fenced_div:
  {M.write([E.Block{E.Para{}, "Centered", 1, 1}]) == "::: {.center .top}\nCentered\n:::" : String}

law fenced_div_is_read_back:
  {M.read("::: {.right}\n## Sub\n:::\n\nAfter") == [E.Block{E.Head{2}, "Sub", 2, 0}, E.Block{E.Para{}, "After", 0, 0}] : List<&2, E.Block>}

# REGRESSION: a paragraph that starts like other syntax keeps its text.
law paragraph_that_looks_like_a_heading:
  {M.write([E.Block{E.Para{}, "# not a heading", 0, 0}]) == "\\# not a heading" : String}

law escaped_paragraph_is_read_back:
  {M.read("\\# not a heading") == [E.Block{E.Para{}, "# not a heading", 0, 0}] : List<&2, E.Block>}

# REGRESSION: a block with no text is not written; a figure always is.
law empty_blocks_are_not_written:
  {M.write([E.Block{E.Para{}, "a", 0, 0}, E.Block{E.Para{}, "", 0, 0}, E.Block{E.Figure{"mermaid", "x"}, "", 0, 0}]) == "a\n\n```mermaid\nx\n```" : String}

# REGRESSION: a fence left open at the end of the text is still a figure, with all its lines.
law open_fence_is_still_a_figure:
  {M.read("```mermaid\nflowchart TD\n  A") == [E.Block{E.Figure{"mermaid", "flowchart TD\n  A"}, "", 0, 0}] : List<&2, E.Block>}
