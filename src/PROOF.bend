import Base
import ./workspace/Workspace.bend as D
import ./workspace/LAWS.bend as WL
import ./diagram/LAWS.bend as DL
import ./agent/LAWS.bend as AL

def WL.edit_preserves_history(d, text):
  match d:
    case D.Diagram{i, n, s, h}: {==}

def WL.edit_keeps_exact_text(d, text):
  match d:
    case D.Diagram{i, n, s, h}: {==}

def WL.rename_preserves_source(d, name):
  match d:
    case D.Diagram{i, n, s, h}: {==}

def WL.rename_preserves_history(d, name):
  match d:
    case D.Diagram{i, n, s, h}: {==}

def WL.unselected_is_unchanged(d, a): {==}

def WL.other_project_is_unchanged(p, id, a):
  match p:
    case D.Project{i, n, ds, k, sn}: {==}

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
    case D.Project{i, n, ds, k, sn}: {==}

def AL.message_keeps_every_diagram(p, doc, id):
  match p:
    case D.Project{i, n, ds, k, sn}: {==}

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
    case D.Diagram{i, n, s, h}: {==}

def AL.same_title_updates_with_history(): {==}
def AL.your_diagram_is_never_updated(): {==}
