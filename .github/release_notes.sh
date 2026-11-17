#!/usr/bin/env bash
set -eu

tag=$1 addon=$2 gen=$3 addon_repo=$4 gen_repo=$5

for repo in "$addon" "$gen"; do
    if ! git -C "$repo" rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
        echo "ERROR: no tag $tag in $repo" >&2
        exit 1
    fi
done

prev=$(git -C "$addon" tag --list 'v*' --sort=-v:refname | awk -v t="$tag" 'found { print; exit } $0 == t { found = 1 }')
if [ -z "$prev" ]; then
    echo "First release."
    exit 0
fi

# build id
data_changed() { # <path>...
    local status diff
    status=$(git -C "$gen" diff --no-renames --name-status "$prev" "$tag" -- "$@")
    if [ -n "$status" ] && grep -qv '^M' <<< "$status"; then
        return 0
    fi
    diff=$(git -C "$gen" diff --unified=0 "$prev" "$tag" -- "$@")
    awk '
        /^diff --git / { in_header = 1; next }
        /^@@/          { in_header = 0; next }
        !in_header && /^[+-]/ && !/addon_build_id/ { found = 1; exit }
        END { exit !found }' <<< "$diff"
}

client_version() { # <rev> <client dir>
    git -C "$gen" show "$1:$2/defs.lua" 2> /dev/null | sed -n 's/^sc\.client_version_src = "\(.*\)";$/\1/p'
}

addon_changed=false
if [ "$(git -C "$addon" rev-parse "$prev^{commit}")" != "$(git -C "$addon" rev-parse "$tag^{commit}")" ]; then
    addon_changed=true
fi

prev_in_gen=false
if git -C "$gen" rev-parse -q --verify "refs/tags/$prev" > /dev/null; then
    prev_in_gen=true
fi

dirs=$( (git -C "$gen" ls-tree -d --name-only "$tag"
         if [ "$prev_in_gen" = true ]; then git -C "$gen" ls-tree -d --name-only "$prev"; fi) | sort -u)
clients=()
for c in Vanilla TBC Camelot; do
    if grep -qx "$c" <<< "$dirs"; then clients+=("$c"); fi
done
while IFS= read -r c; do
    case " ${clients[*]} " in *" $c "*) ;; *) [ -n "$c" ] && clients+=("$c") ;; esac
done <<< "$dirs"

data_any=false
lines=()
for c in "${clients[@]}"; do
    new=$(client_version "$tag" "$c")
    if [ "$prev_in_gen" = false ]; then
        lines+=("- $c: ${new:-unknown version}")
        continue
    fi
    old=$(client_version "$prev" "$c")
    if [ -z "$(git -C "$gen" ls-tree -d --name-only "$tag" -- "$c")" ]; then
        lines+=("- $c: removed")
        data_any=true
        continue
    fi
    if [ -z "$(git -C "$gen" ls-tree -d --name-only "$prev" -- "$c")" ]; then
        lines+=("- $c: ${new:-unknown version}, new")
        data_any=true
        continue
    fi
    if [ "$old" != "$new" ]; then
        version="$old → $new"
    else
        version="$new"
    fi
    if data_changed "$c"; then
        lines+=("- $c: $version, data changed")
        data_any=true
    else
        lines+=("- $c: $version, no data changes")
    fi
done

if [ "$prev_in_gen" = true ]; then
    # Files outside the client folders (locale strings, ...)
    shared=()
    for c in "${clients[@]}"; do shared+=(":(exclude)$c"); done
    if data_changed . "${shared[@]}"; then
        lines+=("- Shared files: changed")
        data_any=true
    fi
fi

if [ "$prev_in_gen" = true ] && [ "$data_any" = false ] && [ "$addon_changed" = false ]; then
    exit 0
fi

if [ "$prev_in_gen" = false ]; then
    echo "**Data:** $prev has no tag in spellcoda-generated, no comparison"
elif [ "$data_any" = true ]; then
    echo "**Data changes:** [$prev...$tag](https://github.com/$gen_repo/compare/$prev...$tag)"
else
    echo "**Data:** no changes since $prev"
fi
printf '%s\n' "${lines[@]}"
echo

if [ "$addon_changed" = true ]; then
    echo "**Addon changes:** [$prev...$tag](https://github.com/$addon_repo/compare/$prev...$tag)"
else
    echo "**Addon:** no changes since $prev"
fi
