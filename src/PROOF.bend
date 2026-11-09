import Base
import ./Domain.bend as D
import ./LAWS.bend as L

def L.edit_preserves_history(d, text):
  match d:
    case D.Document{i, n, s, h}: {==}

def L.edit_keeps_exact_text(d, text):
  match d:
    case D.Document{i, n, s, h}: {==}

def L.rename_preserves_source(d, name):
  match d:
    case D.Document{i, n, s, h}: {==}

def L.rename_preserves_history(d, name):
  match d:
    case D.Document{i, n, s, h}: {==}

def L.unselected_is_unchanged(d, a): {==}

def L.other_project_is_unchanged(p, id, a):
  match p:
    case D.Project{i, n, ds, k, sn}: {==}

def L.missing_restore_is_unchanged(d, stamp): {==}
def L.empty_history_has_no_version(i): {==}
def L.view_preserves_projects(ps, next, p, d, m): {==}
def L.restore_retains_work(): {==}
def L.unchanged_checkpoint_is_not_duplicated(): {==}
def L.arrow_preserves_direction(): {==}
def L.labels_preserve_unicode(): {==}
def L.incomplete_arrow_is_rejected(): {==}
def L.repeated_reference_keeps_label(): {==}

def L.initial_is_empty(): {==}
def L.new_document_is_blank(id, name): {==}
def L.blank_checkpoint_has_no_history(id, name, stamp): {==}
def L.empty_write_has_no_projects(): {==}

def L.write_line_only_appends(source, line): {==}
def L.connect_writes_one_arrow(source, from, to): {==}
def L.connect_adds_a_line(): {==}
def L.connect_after_line_break(): {==}
def L.connected_source_has_the_arrow(): {==}
def L.new_arrow_is_allowed(): {==}
def L.return_loop_is_allowed(): {==}
def L.return_loop_parses(): {==}
def L.self_arrow_parses(): {==}
def L.slanted_shape_is_its_text(): {==}
def L.repeated_arrow_is_refused(): {==}
def L.self_arrow_is_allowed(): {==}
def L.repeated_self_arrow_is_refused(): {==}
def L.invalid_source_is_refused(): {==}
def L.new_node_takes_a_free_id(): {==}
def L.readable_id_drops_accents_and_spaces(): {==}
def L.first_node_starts_a_flowchart(): {==}
def L.node_below_is_one_arrow(): {==}
def L.quotes_in_labels_are_kept_safe(): {==}
def L.entities_in_labels_are_read(): {==}
def L.quotes_round_trip(): {==}
def L.rename_keeps_the_node(): {==}
def L.decision_is_read(): {==}
def L.arrow_text_is_a_label(): {==}
def L.quoted_arrow_label_is_unquoted(): {==}
def L.rename_rewrites_its_line(): {==}
def L.rename_label_equal_to_id(): {==}
def L.rename_own_line(): {==}
def L.rename_keeps_the_decision(): {==}
def L.delete_keeps_other_decisions(): {==}
def L.delete_takes_its_arrows(): {==}
def L.remove_arrow_keeps_nodes(): {==}
def L.insert_between_keeps_the_label(): {==}
def L.move_writes_one_position(): {==}
def L.positions_are_read_back(): {==}
def L.auto_keeps_positions(): {==}
def L.layout_lines_are_comments(): {==}
def L.class_gives_a_tone(): {==}
def L.classes_keep_the_shape(): {==}
def L.color_writes_class_and_definition(): {==}
def L.color_replaces_color(): {==}
def L.no_color_removes_it(): {==}
def L.rename_keeps_the_color(): {==}
def L.delete_diagram_keeps_the_rest(): {==}
def L.delete_open_diagram_opens_another(): {==}
def L.delete_open_project_opens_another(): {==}
def L.delete_last_project_opens_nothing(): {==}
def L.rename_diagram_renames_only_it(): {==}
def L.message_skips_other_projects(p, doc, id):
  match p:
    case D.Project{i, n, ds, k, sn}: {==}

def L.message_keeps_every_diagram(p, doc, id):
  match p:
    case D.Project{i, n, ds, k, sn}: {==}

def L.message_adds_one_diagram(): {==}
def L.wrong_key_changes_nothing(): {==}
def L.normal_project_never_receives(): {==}
def L.same_message_is_added_once(): {==}
def L.sender_is_read(): {==}
def L.connect_agent_gives_a_key(): {==}
def L.connect_agent_keeps_a_key(): {==}
def L.connected_project_receives(): {==}
def L.new_key_replaces_the_old(): {==}
def L.normal_project_gets_no_key(): {==}

def L.update_skips_other_diagrams(d, text, stamp): {==}

def L.update_shows_the_new_text(d, text, stamp):
  match d:
    case D.Document{i, n, s, h}: {==}

def L.same_title_updates_with_history(): {==}
def L.your_diagram_is_never_updated(): {==}
