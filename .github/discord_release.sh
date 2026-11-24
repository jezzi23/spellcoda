#!/usr/bin/env bash
set -eu

tag=$1 repo=$2 mode=$3 # new or edited
api="https://api.github.com/repos/$repo"
marker_re='<!-- discord-message: [0-9]+ -->'

gh_api() { # <method> <path> [json]
    curl -fsS -X "$1" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        ${3:+-H "Content-Type: application/json" --data "$3"} \
        "$api$2"
}

release=$(gh_api GET "/releases/tags/$tag")
release_id=$(jq -r .id <<< "$release")
body=$(jq -r '.body // ""' <<< "$release" | tr -d '\r')
published=$(jq -r '.published_at // .created_at' <<< "$release")

message_id=$(grep -oE "$marker_re" <<< "$body" | head -n 1 | grep -oE '[0-9]+' || true)
text=$(sed -E "s/$marker_re//" <<< "$body" | sed -e '/./,$!d')

url="https://github.com/$repo/releases/tag/$tag"
if [ "$mode" = new ]; then
    content="A new release has been published!"
else
    content="Release notes for $tag"
fi

discord_text=$(sed 's/^---$/────────────────────/' <<< "$text")
payload=$(jq -n --arg content "$content" --arg title "Release $tag" --arg url "$url" --arg text "$discord_text" \
    --arg ts "$published" '
    ($text | if length > 4096 then .[0:4000] + "\n\n… [continued on GitHub](" + $url + ")" else . end) as $desc |
    {
        content: $content,
        embeds: [{
            title: $title,
            url: $url,
            description: (if $desc == "" then "Check out the latest release" else $desc end),
            color: 2105893,
            footer: {
                text: "Release Notification",
                icon_url: "https://cdn.discordapp.com/avatars/487431320314576937/bd64361e4ba6313d561d54e78c9e7171.png"
            },
            timestamp: $ts
        }]
    }')
webhook=${WEBHOOK_URL%%\?*}

if [ -n "$message_id" ]; then
    edit=$(jq 'del(.content)' <<< "$payload")
    status=$(curl -sS -o /dev/null -w '%{http_code}' -X PATCH -H "Content-Type: application/json" \
        --data "$edit" "$webhook/messages/$message_id")
    if [ "$status" = 200 ]; then
        echo "Edited Discord message $message_id"
        exit 0
    fi
    echo "Editing Discord message $message_id failed ($status), posting a new one"
fi

message_id=$(curl -fsS -X POST -H "Content-Type: application/json" --data "$payload" "$webhook?wait=true" | jq -r .id)
echo "Posted Discord message $message_id"

# runs on the workflow token do not trigger the edited workflow again
new_body=$(printf '<!-- discord-message: %s -->\n%s\n' "$message_id" "$text")
gh_api PATCH "/releases/$release_id" "$(jq -n --arg body "$new_body" '{body: $body}')" > /dev/null
