# snapshot.zsh — defines `work`, `snap`, and `restore`

# Requires:
#   export CODING_ROOT_DIR=~/Workshop  # or whereever the root of your project dirs is
#   export CODING_SNAPS_DIR=~/Workshop/__snaps__  # name it anything and put it anywhere

SNAPS_VERSION="1.0"
readonly SNAPS_VERSION

# --- validation ------------------------------------------------------------------

if [[ -z "${CODING_ROOT_DIR:-}" || ! -d "$CODING_ROOT_DIR" ]]; then
  if [[ -t 1 ]]; then
    echo "snapshot.zsh: CODING_ROOT_DIR is not defined or is invalid. Please export it before sourcing." >&2
  fi
  return 1
fi

if [[ -z "${CODING_SNAPS_DIR:-}"  || ! -d "$CODING_SNAPS_DIR" ]]; then
  if [[ -t 1 ]]; then
    echo "snapshot.zsh: CODING_SNAPS_DIR is not defined or is invalid. Please export it before sourcing." >&2
  fi
  return 1
fi

# --- work ------------------------------------------------------------------

work() {
  # Keep redundant validation (intentional safety measure)
  if [[ -z "${CODING_ROOT_DIR:-}" ]]; then
    echo "work: CODING_ROOT_DIR is not set." >&2
    return 1
  fi

  if [[ ! -d "$CODING_ROOT_DIR" ]]; then
    echo "work: CODING_ROOT_DIR is not a valid directory: $CODING_ROOT_DIR" >&2
    return 1
  fi

  local target
  local create_dir=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--create)
        create_dir=true
        shift
        ;;
      -h|--help)
        echo "Usage: work [-c|--create] [project_name]"
        echo "  -c, --create    Create project directory if it doesn't exist"
        echo "  -h, --help      Show this help message"
        echo "  --version       Show the version number"
        echo
        echo "Changes directory to \$CODING_ROOT_DIR/project_name"
        echo "If no project_name is provided, changes to \$CODING_ROOT_DIR"
        return 0
        ;;
      --version)
        echo "snaps.zsh version $SNAPS_VERSION"
        return 0
        ;;        
      -*)
        echo "work: Unknown option: $1" >&2
        echo "Try 'work --help' for more information" >&2
        return 1
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"
        else
          echo "work: Too many arguments. Did you mean to quote a project name with spaces?" >&2
          return 1
        fi
        shift
        ;;
    esac
  done
  
  # Determine target directory
  if [[ -z "$target" ]]; then
    target="$CODING_ROOT_DIR"
  else
    target="$CODING_ROOT_DIR/$target"
  fi
  
  # Check if directory exists or create it
  if [[ ! -d "$target" ]]; then
    if [[ "$create_dir" == true ]]; then
      if ! mkdir -p "$target"; then
        echo "work: Failed to create directory: $target" >&2
        return 1
      fi
    else
      echo "work: No such project: ${target#$CODING_ROOT_DIR/}" >&2
      echo "Use 'work -c ${target#$CODING_ROOT_DIR/}' to create this project directory"
      echo
      (
        cd "$CODING_ROOT_DIR"
        ls -l --color=always | grep -v "^total" | grep -v "__.*__"
      )
      return 1
    fi
  fi
  
  # Change to target directory
  if ! cd "$target"; then
    echo "work: Failed to change directory to: $target" >&2
    return 1
  fi
}

_work_completions_zsh() {
  local -a projects
  projects=(${(f)"$(printf '%s\n' "$CODING_ROOT_DIR"/*(/) | grep -v '/__[^/]*/*$')"})
  projects=(${projects:t})
  _describe 'projects' projects
}

compdef _work_completions_zsh work

# --- snap ------------------------------------------------------------------

snap() {
  local usage error
  local label=""

  usage() {
    echo "Usage: snap [-h|--help] [label...]"
    echo "Creates a timestamped snapshot of the current project."
    echo
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  --version       Show the version number"
    echo
    echo "Any additional arguments are combined to form a label for the snapshot."
    return 0
  }

  error() {
    echo "snap: $1" >&2
    return 1
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      --version)
        echo "snaps.zsh version $SNAPS_VERSION"
        return 0
        ;;
      -*)
        error "Unknown option: $1"
        echo "Try 'snap --help' for more information" >&2
        return 1
        ;;
      *)
        label="$*"
        break
        ;;
    esac
  done

  if [[ -z "${CODING_ROOT_DIR:-}" ]]; then
    error "CODING_ROOT_DIR is not set"
    return 1
  fi

  if [[ -z "${CODING_SNAPS_DIR:-}" ]]; then
    error "CODING_SNAPS_DIR is not set"
    return 1
  fi

  local cwd="$PWD"
  if [[ "$cwd" != "$CODING_ROOT_DIR/"* ]]; then
    error "must be inside a project under $CODING_ROOT_DIR"
    return 1
  fi

  if [[ "$cwd" == "$CODING_SNAPS_DIR"* ]]; then
    error "cannot create snapshot from within $CODING_SNAPS_DIR"
    return 1
  fi

  local project="${cwd#$CODING_ROOT_DIR/}"
  project="${project%%/*}"
  if [[ -z "$project" ]]; then
    error "could not determine project name"
    return 1
  fi

  if [[ "$project" == __*__ ]]; then
    error "cannot create snapshot of special directory: $project"
    return 1
  fi

  if ! mkdir -p "$CODING_SNAPS_DIR"; then
    error "could not create: $CODING_SNAPS_DIR"
    return 1
  fi

  local timestamp
  timestamp=$(date +"%Y-%m-%d-%H.%M")

  local clean_label
  clean_label=$(echo "$label" | sed 's/^[[:space:]]*//' | sed -E 's/[[:space:]]+/-/g' | sed 's/[^a-zA-Z0-9_.\-]//g')

  local filename="${project}-${timestamp}"
  if [[ -n "$clean_label" ]]; then
    filename="${filename}-${clean_label}"
  fi
  filename="${filename}.tgz"

  (
    cd . || error "could not enter project directory"
    tar \
      --exclude="$CODING_SNAPS_DIR" \
      --exclude='.next' \
      --exclude='.DS_Store' \
      --exclude='node_modules' \
      --exclude='__pycache__' \
      --exclude='*.log' \
      -czf - ./ || exit 1
  ) > "$CODING_SNAPS_DIR/$filename" || error "snapshot failed"
}

# --- restore ------------------------------------------------------------------

restore() {
  local usage error snapshot="" extract_dir=""
  local snapshot_path=""
  local basename=""
  local files=()
  local project=""

  usage() {
    echo "Usage: restore [-h|--help] snapshot.tgz"
    echo "       restore -l|--list"
    echo
    echo "Options:"
    echo "  -l, --list      List available snapshots"
    echo "  -h, --help      Show this help message"
    echo "  --version       Show the version number"
    echo
    echo "Extracts a snapshot to a new directory named after the snapshot."
    return 0
  }

  error() {
    echo "restore: $1" >&2
    return 1
  }

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      --version)
        echo "snaps.zsh version $SNAPS_VERSION"
        return 0
        ;;
      -l|--list)
        if [[ "$PWD" == "$CODING_ROOT_DIR/"* ]]; then
          project="${PWD##*/}"
          project="${project// /-}"
          files=("$CODING_SNAPS_DIR"/${project}-*.tgz(N))
        else
          files=("$CODING_SNAPS_DIR"/*.tgz(N))
        fi

        for f in "${files[@]}"; do
          echo "${f##*/}"
        done

        return 0
        ;;
      -*)
        error "Unknown option: $1"
        echo "Try 'restore --help' for more information" >&2
        return 1
        ;;
      *)
        if [[ -z "$snapshot" ]]; then
          snapshot="$1"
        else
          error "Too many arguments"
          echo "Try 'restore --help' for more information" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$snapshot" ]]; then
    error "no snapshot provided"
    return 1
  fi

  # Handle path or just filename
  if [[ "$snapshot" == *"/"* ]]; then
    # Path was provided
    if [[ ! -f "$snapshot" ]]; then
      error "snapshot not found: $snapshot"
      return 1
    fi
    snapshot_path="$snapshot"
    snapshot="${snapshot##*/}"
  else
    # Just filename
    snapshot_path="$CODING_SNAPS_DIR/$snapshot"
    if [[ ! -f "$snapshot_path" ]]; then
      error "snapshot not found: $snapshot"
      return 1
    fi
  fi

  # Parse snapshot name (removing .tgz extension)
  basename="${snapshot%.tgz}"

  # Determine extract directory
  extract_dir="$CODING_ROOT_DIR/$basename"

  if [[ -e "$extract_dir" ]]; then
    error "directory already exists: $extract_dir"
    return 1
  fi

  if ! mkdir -p "$extract_dir"; then
    error "failed to create directory: $extract_dir"
    return 1
  fi

  echo "Extracting to: $extract_dir"
  if ! tar -xzf "$snapshot_path" -C "$extract_dir"; then
    rmdir "$extract_dir" 2>/dev/null
    error "failed to extract snapshot"
    return 1
  fi

  echo "Snapshot restored"
  return 0
}

_restore_zsh_completions() {
  local -a snapshots
  local dir="$CODING_SNAPS_DIR"

  if [[ "$PWD" == "$CODING_ROOT_DIR/"* ]]; then
    local project_name="${PWD##*/}"
    local project_slug="${project_name// /-}"
    snapshots=($dir/${project_slug}-*.tgz(N))
  else
    snapshots=($dir/*.tgz(N))
  fi

  snapshots=(${snapshots:t})
  _describe 'snapshot' snapshots
}

compdef _restore_zsh_completions restore
