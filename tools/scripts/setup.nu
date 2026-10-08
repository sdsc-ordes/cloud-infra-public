# Link tool config files into the repository root (`just setup`).
use ../nu/lib/common.nu *

# Symlink `src` to `dest` with a relative target, so the link survives
# moving or remounting the repo.
def link-config [src: path, dest: path] {
    if not ($src | path exists) {
        error make {msg: $"File to link '($src)' does not exist."}
    }
    ^ln -sfn $src $dest
}

def main [] {
    let root = root-dir
    cd $root
    log info "Link config files."
    link-config "tools/configs/prettier/prettierrc.yaml" ".prettierrc.yaml"
    link-config "tools/configs/prek/pre-commit-config.yaml" ".pre-commit-config.yaml"
    link-config "tools/configs/taplo/taplo.toml" ".taplo.toml"
}
