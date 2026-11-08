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
    case D.Project{i, n, ds}: {==}

def L.missing_restore_is_unchanged(d, stamp): {==}
def L.empty_history_has_no_version(i): {==}
def L.view_preserves_projects(ps, next, p, d, m): {==}
def L.restore_retains_work(): {==}
def L.unchanged_checkpoint_is_not_duplicated(): {==}
def L.arrow_preserves_direction(): {==}
def L.labels_preserve_unicode(): {==}
def L.incomplete_arrow_is_rejected(): {==}
def L.repeated_reference_keeps_label(): {==}
