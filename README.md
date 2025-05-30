# snaps.zsh

> Super lightweight snapshot and restore utilities for coding projects — built with AI development workflows in mind.

When working on AI development projects — or any fast-moving coding tasks — sometimes you want a quick way to snapshot your work without the overhead of Git or heavier systems. `snaps.zsh` provides small shell utilities to:

- Switch easily between projects
- Take timestamped, compressed snapshots
- Restore snapshots safely without overwriting your live work

No cloud, no server, no dependencies — just your local machine and a little Zsh.

---

## Setup

Add the following to your `~/.zshrc`:

```sh
# Directory where all your projects live
export CODING_ROOT_DIR=~/Workshop

# Directory where snapshots will be saved
export CODING_SNAPS_DIR=~/Workshop/__snaps__

# Source the snaps.zsh script
source ~/path/to/snaps.zsh
```

Reload your shell:

```sh
source ~/.zshrc
```

---

## Directory Setup

- **`CODING_ROOT_DIR`** should point to a *parent directory* that contains all your project directories underneath it.
  
  Example:
  ```
  ~/Workshop/
    myproject1/
    myproject2/
  ```

- **`CODING_SNAPS_DIR`** can be:
  - Anywhere — including a completely different drive or location.
  - A subdirectory under `CODING_ROOT_DIR` (like `~/Workshop/__snaps__`).
  - The script will make sure snapshots aren’t taken from within `CODING_SNAPS_DIR` itself.

---

## Commands

### `work`

```sh
Usage: work [-c|--create] [project_name]
  -c, --create    Create project directory if it doesn't exist
  -h, --help      Show this help message
```

Changes directory to `$CODING_ROOT_DIR/project_name`.  
If no `project_name` is provided, changes to `$CODING_ROOT_DIR`.

---

### `snap`

```sh
Usage: snap [-h|--help] [label...]
  -h, --help      Show this help message
```

Creates a timestamped `.tgz` snapshot of the current project.

- Snapshots exclude common temporary directories:
  - `node_modules/`
  - `.next/`
  - `.DS_Store`
  - `__pycache__/`
  - `*.log`

---

### `restore`

```sh
Usage: restore [-h|--help] snapshot.tgz
       restore -l|--list
  -l, --list      List available snapshots
  -h, --help      Show this help message
```

Restores the given snapshot into a new directory named after the snapshot. 
Never overwrites existing directories.

---

## Language and Temporary File Support

Currently, `snap` excludes temporary and reproducible files common to **Node.js** projects.

If you use another language (Python, C++, etc.) and want to exclude build artifacts, object files, or other reproducible files, simply edit the exclusion patterns in `snaps.zsh`.

---

## Shell Support

This script is written for **Zsh** (5.0+).  
It uses Zsh-specific features like advanced globbing and tab completion.

> If you need Bash or another shell, changes are required — but AI is your friend if you want to port it.

---

## Example Workflow

```sh
work myproject         # Switch to project (create if needed)
snap "initial commit"  # Take a snapshot with label
restore myproject-2025-05-30-15.30-initial-commit.tgz  # Restore snapshot
```

Snapshots are named like:

```
myproject-2025-05-30-15.30-initial-commit.tgz
```

Restores are always extracted into a fresh new directory — nothing is overwritten automatically.

---
