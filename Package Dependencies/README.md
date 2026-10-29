# Package Dependencies Report Generator

This script inspects all manually installed packages on your system (`apt-mark showmanual`) and exports a complete dependency report with forward and reverse dependency trees using `apt-rdepends`.

## Prerequisites

Install `apt-rdepends`:

```bash
sudo apt update && sudo apt install -y apt-rdepends
```

## Usage

Run the script:

```bash
./export_dependencies.sh
```

The script will generate `all_packages_dependencies.txt` containing:
- **TREE DOWN:** What each package depends on (forward dependencies).
- **TREE UP:** What requires each package (reverse dependencies).
