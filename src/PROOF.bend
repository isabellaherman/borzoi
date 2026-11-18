import Base
import ./workspace/Workspace.bend as D
import ./workspace/LAWS.bend as WL
import ./diagram/LAWS.bend as DL
import ./agent/LAWS.bend as AL
import ./editor/Editor.bend as E
import ./editor/LAWS.bend as EL

def WL.edit_preserves_history(d, text):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.edit_keeps_exact_text(d, text):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.rename_preserves_source(d, name):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.rename_preserves_history(d, name):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.unselected_is_unchanged(d, a): {==}

def WL.other_project_is_unchanged(p, id, a):
  match p:
    case D.Project{i, n, ds, k, sn, dcs}: {==}

def WL.missing_restore_is_unchanged(d, stamp): {==}
def WL.empty_history_has_no_version(i): {==}
def WL.view_preserves_projects(ps, next, p, d, m): {==}
def WL.restore_retains_work(): {==}
def WL.unchanged_checkpoint_is_not_duplicated(): {==}
def DL.arrow_preserves_direction(): {==}
def DL.labels_preserve_unicode(): {==}
def DL.incomplete_arrow_is_rejected(): {==}
def DL.repeated_reference_keeps_label(): {==}

def WL.initial_is_empty(): {==}
def WL.new_diagram_is_blank(id, name): {==}
def WL.blank_checkpoint_has_no_history(id, name, stamp): {==}
def WL.empty_write_has_no_projects(): {==}

def DL.write_line_only_appends(source, line): {==}
def DL.connect_writes_one_arrow(source, from, to): {==}
def DL.connect_adds_a_line(): {==}
def DL.connect_after_line_break(): {==}
def DL.connected_source_has_the_arrow(): {==}
def DL.new_arrow_is_allowed(): {==}
def DL.return_loop_is_allowed(): {==}
def DL.return_loop_parses(): {==}
def DL.self_arrow_parses(): {==}
def DL.slanted_shape_is_its_text(): {==}
def DL.all_shapes_are_read(): {==}
def DL.shapes_round_trip(): {==}
def DL.line_breaks_are_read(): {==}
def DL.line_breaks_are_written(): {==}
def DL.add_with_a_shape(): {==}
def DL.insert_with_a_shape(): {==}
def DL.set_shape_keeps_the_label(): {==}
def DL.set_shape_of_a_bare_node(): {==}
def DL.rename_keeps_the_shape(): {==}
def DL.repeated_arrow_is_refused(): {==}
def DL.self_arrow_is_allowed(): {==}
def DL.repeated_self_arrow_is_refused(): {==}
def DL.invalid_source_is_refused(): {==}
def DL.new_node_takes_a_free_id(): {==}
def DL.readable_id_drops_accents_and_spaces(): {==}
def DL.first_node_starts_a_flowchart(): {==}
def DL.node_below_is_one_arrow(): {==}
def DL.quotes_in_labels_are_kept_safe(): {==}
def DL.entities_in_labels_are_read(): {==}
def DL.quotes_round_trip(): {==}
def DL.rename_keeps_the_node(): {==}
def DL.decision_is_read(): {==}
def DL.arrow_text_is_a_label(): {==}
def DL.quoted_arrow_label_is_unquoted(): {==}
def DL.rename_rewrites_its_line(): {==}
def DL.rename_label_equal_to_id(): {==}
def DL.rename_own_line(): {==}
def DL.rename_keeps_the_decision(): {==}
def DL.delete_keeps_other_decisions(): {==}
def DL.delete_takes_its_arrows(): {==}
def DL.remove_arrow_keeps_nodes(): {==}
def DL.insert_between_keeps_the_label(): {==}
def DL.move_writes_one_position(): {==}
def DL.positions_are_read_back(): {==}
def DL.auto_keeps_positions(): {==}
def DL.layout_lines_are_comments(): {==}
def DL.class_gives_a_tone(): {==}
def DL.classes_keep_the_shape(): {==}
def DL.color_writes_class_and_definition(): {==}
def DL.color_replaces_color(): {==}
def DL.no_color_removes_it(): {==}
def DL.rename_keeps_the_color(): {==}
def WL.delete_diagram_keeps_the_rest(): {==}
def WL.delete_open_diagram_opens_another(): {==}
def WL.delete_open_project_opens_another(): {==}
def WL.delete_last_project_opens_nothing(): {==}
def WL.rename_diagram_renames_only_it(): {==}
def AL.message_skips_other_projects(p, doc, id):
  match p:
    case D.Project{i, n, ds, k, sn, dcs}: {==}

def AL.message_keeps_every_diagram(p, doc, id):
  match p:
    case D.Project{i, n, ds, k, sn, dcs}: {==}

def AL.message_adds_one_diagram(): {==}
def AL.wrong_key_changes_nothing(): {==}
def AL.normal_project_never_receives(): {==}
def AL.same_message_is_added_once(): {==}
def AL.sender_is_read(): {==}
def AL.connect_agent_gives_a_key(): {==}
def AL.connect_agent_keeps_a_key(): {==}
def AL.connected_project_receives(): {==}
def AL.new_key_replaces_the_old(): {==}
def AL.normal_project_gets_no_key(): {==}

def AL.update_skips_other_diagrams(d, text, stamp): {==}

def AL.update_shows_the_new_text(d, text, stamp):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def AL.same_title_updates_with_history(): {==}
def AL.your_diagram_is_never_updated(): {==}

def WL.edit_keeps_why(d, text):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.checkpoint_keeps_why(d, stamp):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.rename_keeps_why(d, name):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.restore_keeps_why(d, v, stamp):
  match d v:
    case D.Diagram{i, n, s, h, wy} None{}: {==}
    case D.Diagram{i, n, s, h, wy} Some{D.Version{t, m}}: {==}

def WL.other_project_keeps_documents(p, id, a):
  match p:
    case D.Project{i, n, ds, k, sn, dcs}: {==}

def WL.new_diagram_has_no_why(): {==}
def WL.import_keeps_documents_and_why(): {==}
def WL.delete_diagram_keeps_documents(): {==}

# ---------- Why, documents and figures ----------
def WL.why_keeps_the_source(d, y):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.why_keeps_the_history(d, y):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.why_is_added_first(d, y):
  match d:
    case D.Diagram{i, n, s, h, wy}: {==}

def WL.why_goes_to_its_diagram(): {==}

def WL.document_write_keeps_history(x, text):
  match x:
    case D.Document{i, n, s, h}: {==}

def WL.document_keeps_exact_text(x, text):
  match x:
    case D.Document{i, n, s, h}: {==}

def WL.documents_never_change_diagrams(p, id, a, selected):
  match p selected:
    case D.Project{i, n, ds, k, sn, dcs} False{}: {==}
    case D.Project{i, n, ds, k, sn, dcs} True{}: {==}

def WL.unselected_document_is_unchanged(x, a): {==}
def WL.why_on_a_document_is_nothing(x, y): {==}
def WL.new_document_keeps_what_is_open(): {==}
def WL.new_document_needs_its_project(): {==}
def WL.document_write_changes_only_it(): {==}
def WL.document_restore_retains_work(): {==}
def WL.delete_document_keeps_the_rest(): {==}
def WL.figure_points_to_its_diagram(): {==}
def WL.figure_keeps_its_own_copy(): {==}
def WL.plain_mermaid_points_to_none(): {==}
def WL.figure_shows_the_diagram_of_now(): {==}
def WL.import_relinks_figures(): {==}
def WL.why_is_written_as_comments(): {==}
def WL.no_why_no_comments(): {==}
def WL.document_is_copied_as_markdown(): {==}
def WL.document_is_copied_for_an_agent(): {==}

# ---------- The editor ----------
def EL.skip_changes_nothing(d): {==}
def EL.skip_is_undone_by_skip(d): {==}
def EL.kind_moves_no_position(d, at, k, p): {==}
def EL.align_moves_no_position(d, at, a, p): {==}
def EL.place_moves_no_position(d, at, q, p): {==}
def EL.replace_is_undone(): {==}
def EL.split_is_undone(): {==}
def EL.join_is_undone(): {==}
def EL.insert_is_undone(): {==}
def EL.remove_is_undone(): {==}
def EL.kind_is_undone(): {==}
def EL.align_is_undone(): {==}
def EL.place_is_undone(): {==}
def EL.move_is_undone(): {==}
def EL.step_past_the_end_changes_nothing(): {==}
def EL.step_past_the_end_is_undone_by_skip(): {==}
def EL.replace_changes_only_its_range(): {==}
def EL.line_breaks_never_enter_a_block(): {==}
def EL.schema_fits_values(): {==}
def EL.move_lands_at_its_place(): {==}
def EL.position_moves_with_typed_text(): {==}
def EL.position_before_typed_text_stays(): {==}
def EL.position_follows_a_split(): {==}
def EL.position_follows_a_join(): {==}
def EL.position_follows_a_moved_block(): {==}
def EL.position_steps_back_past_a_moved_block(): {==}
def EL.position_after_an_inserted_block(): {==}
def EL.position_after_a_removed_block(): {==}
def EL.undo_of_nothing(d, r, c): {==}
def EL.redo_of_nothing(d, u, c): {==}

def EL.no_steps_no_entry(e, before, after, typing, time): {==}
def EL.empty_opens_with_a_paragraph(): {==}
def EL.undo_gives_the_document_back(): {==}
def EL.undo_puts_the_caret_back(): {==}
def EL.redo_makes_the_change_again(): {==}
def EL.a_run_of_typing_is_one_undo(): {==}
def EL.typing_after_a_pause_is_its_own_undo(): {==}
def EL.typing_is_the_smallest_replacement(): {==}
def EL.hash_makes_a_heading(): {==}
def EL.dash_makes_a_list_item(): {==}
def EL.shortcut_only_in_a_paragraph(): {==}
def EL.enter_splits_a_paragraph(): {==}
def EL.enter_goes_on_with_a_list(): {==}
def EL.enter_on_an_empty_item_leaves_the_list(): {==}
def EL.enter_after_a_heading_is_a_paragraph(): {==}
def EL.enter_in_a_caption_writes_under_the_figure(): {==}
def EL.backspace_joins_the_block_before(): {==}
def EL.backspace_makes_a_heading_a_paragraph(): {==}
def EL.backspace_never_joins_a_figure(): {==}
def EL.selection_across_blocks_is_taken_out(): {==}
def EL.a_letter_typed_over_a_selection(): {==}
def EL.figure_takes_an_empty_paragraph(): {==}
def EL.figure_goes_under_text(): {==}
def EL.caret_goes_after_the_figure(): {==}
def EL.last_block_out_leaves_a_paragraph(): {==}
def EL.pasted_blocks_go_under(): {==}
def EL.pasted_line_goes_into_the_text(): {==}
def EL.markdown_of_a_document(): {==}
def EL.markdown_is_read_back(): {==}
def EL.lists_are_read_back(): {==}
def EL.lists_are_written_back(): {==}
def EL.alignment_is_a_fenced_div(): {==}
def EL.fenced_div_is_read_back(): {==}
def EL.paragraph_that_looks_like_a_heading(): {==}
def EL.escaped_paragraph_is_read_back(): {==}
def EL.empty_blocks_are_not_written(): {==}
def EL.open_fence_is_still_a_figure(): {==}

