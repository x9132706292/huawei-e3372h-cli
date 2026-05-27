#!/bin/sh
# read_sms_json_final.sh - Read SMS from Huawei E3372H-153, valid JSON output
# Usage: sh read_sms_json_final.sh [folder] [192.168.8.1]
# Folders: inbox (default), sent, draft, all

FOLDER="${1:-inbox}"
HOST="${2:-192.168.8.1}"

# Map folder names to API box types
case "$FOLDER" in
    inbox) BOX=1 ;; sent) BOX=2 ;; draft) BOX=3 ;; all) BOX=4 ;; *) BOX=1 ;;
esac

# 1. Get session tokens
curl -s "http://${HOST}/api/webserver/SesTokInfo" > /tmp/ses_tok.xml
COOKIE=$(grep "SessionID=" /tmp/ses_tok.xml | sed 's/.*<SesInfo>\(SessionID=[^<]*\)<\/SesInfo>.*/\1/' | tr -d ' \n\r')
TOKEN=$(grep "<TokInfo>" /tmp/ses_tok.xml | sed 's/.*<TokInfo>\([^<]*\)<\/TokInfo>.*/\1/' | tr -d ' \n\r')

if [ -z "$COOKIE" ] || [ -z "$TOKEN" ]; then
    printf '{"error":"auth_failed"}\n'; exit 1
fi

sleep 1  # workaround for error 100005

# 2. Send request
XML_DATA="<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><PageIndex>1</PageIndex><ReadCount>50</ReadCount><BoxType>${BOX}</BoxType><SortType>0</SortType><Ascending>0</Ascending><UnreadPreferred>0</UnreadPreferred></request>"

RESP=$(curl -s --max-time 10 \
    -H "Cookie: ${COOKIE}" \
    -H "__RequestVerificationToken: ${TOKEN}" \
    -H "Content-Type: application/xml" \
    -H "Accept: */*" \
    -H "User-Agent: Mozilla/5.0" \
    -X POST -d "${XML_DATA}" \
    "http://${HOST}/api/sms/sms-list")

# 3. Handle API errors
if echo "$RESP" | grep -q "<error>"; then
    CODE=$(echo "$RESP" | sed -n 's/.*<code>\([^<]*\)<\/code>.*/\1/p')
    printf '{"error":"api_error","code":"%s"}\n' "$CODE"; exit 1
fi

# 4. Output JSON
COUNT=$(echo "$RESP" | sed -n 's/.*<Count>\([^<]*\)<\/Count>.*/\1/p')

printf '{\n  "count": %s,\n  "folder": "%s",\n  "messages": [\n' "${COUNT:-0}" "$FOLDER"

echo "$RESP" | tr '\n\r' '  ' | awk '
# Safe tag extraction function (avoids off-by-one errors)
function get_tag(xml, tag,    tmp) {
    if (match(xml, "<" tag ">[^<]*</" tag ">")) {
        tmp = substr(xml, RSTART, RLENGTH)
        gsub("<\/?" tag ">", "", tmp)
        return tmp
    }
    return ""
}

function json_escape(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    gsub(/\t/, "\\t", s)
    return s
}

BEGIN { first=1 }
{
    n = split($0, m, /<Message>/)
    for (i=2; i<=n; i++) {
        msg = m[i]
        sub(/<\/Message>.*/, "", msg)
        
        phone   = get_tag(msg, "Phone")
        content = get_tag(msg, "Content")
        date    = get_tag(msg, "Date")
        smstat  = get_tag(msg, "Smstat")
        idx     = get_tag(msg, "Index")
        
        if (content == "" && phone == "") continue
        
        status = (smstat == "0") ? "unread" : "read"
        
        if (!first) printf ",\n"
        first = 0
        
        printf "    {\n"
        printf "      \"id\": %s,\n", (idx != "" ? idx+0 : "null")
        printf "      \"phone\": \"%s\",\n", json_escape(phone)
        printf "      \"date\": \"%s\",\n", json_escape(date)
        printf "      \"status\": \"%s\",\n", status
        printf "      \"content\": \"%s\"\n", json_escape(content)
        printf "    }"
    }
}
END { if (!first) printf "\n" }'

printf '  ]\n}\n'
