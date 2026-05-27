#!/bin/sh
# delete_sms.sh - Delete SMS from Huawei E3372H-153 by ID(s)
# Usage: sh delete_sms.sh [192.168.8.1] <ID1> [ID2] ...
# Example: ./delete_sms.sh 192.168.8.1 40001 40002

HOST="${1:-192.168.8.1}"
shift
IDS="$@"

# Check input parameters
if [ -z "$IDS" ]; then
    printf '{"error":"missing_ids","message":"Usage: delete_sms.sh [host] <ID1> [ID2] ..."}\n'
    exit 1
fi

# 1. Get session tokens
curl -s "http://${HOST}/api/webserver/SesTokInfo" > /tmp/ses_tok.xml
COOKIE=$(grep "SessionID=" /tmp/ses_tok.xml | sed 's/.*<SesInfo>\(SessionID=[^<]*\)<\/SesInfo>.*/\1/' | tr -d ' \n\r')
TOKEN=$(grep "<TokInfo>" /tmp/ses_tok.xml | sed 's/.*<TokInfo>\([^<]*\)<\/TokInfo>.*/\1/' | tr -d ' \n\r')

if [ -z "$COOKIE" ] || [ -z "$TOKEN" ]; then
    printf '{"error":"auth_failed","message":"Failed to obtain tokens"}\n'
    exit 1
fi

# Workaround for 100005
sleep 1

# Variables for collecting results
SUCC=""
FAIL=""
TOTAL=0

# 2. Delete messages one by one (safer for tracking individual status)
for id in $IDS; do
    # Skip non-numeric values
    case "$id" in
        ''|*[!0-9]*) continue ;;
    esac
    
    TOTAL=$((TOTAL + 1))
    
    # Build XML delete request
    DEL_XML="<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><Index>${id}</Index></request>"
    
    RESP=$(curl -s --max-time 5 \
        -H "Cookie: ${COOKIE}" \
        -H "__RequestVerificationToken: ${TOKEN}" \
        -H "Content-Type: application/xml" \
        -H "Accept: */*" \
        -X POST -d "${DEL_XML}" \
        "http://${HOST}/api/sms/delete-sms")
    
    # Parse response
    if echo "$RESP" | grep -q "<response>OK</response>"; then
        [ -n "$SUCC" ] && SUCC="${SUCC},"
        SUCC="${SUCC}\"${id}\""
    else
        CODE=$(echo "$RESP" | sed -n 's/.*<code>\([^<]*\)<\/code>.*/\1/p')
        MSG="unknown_error"
        case "$CODE" in
            125001) MSG="message_not_found" ;;
            125002) MSG="no_rights" ;;
            100005) MSG="session_expired" ;;
            *)      [ -n "$CODE" ] && MSG="code_${CODE}" ;;
        esac
        [ -n "$FAIL" ] && FAIL="${FAIL},"
        FAIL="${FAIL}{\"id\":\"${id}\",\"reason\":\"${MSG}\"}"
    fi
    
    # Small delay to avoid overwhelming the modem during batch deletion
    [ "$TOTAL" -lt 10 ] && sleep 0.3
done

# 3. Output JSON result
printf '{\n'
printf '  "host": "%s",\n' "$HOST"
printf '  "total_requested": %d,\n' "$TOTAL"
printf '  "deleted": [%s],\n' "$SUCC"
printf '  "failed": [%s]\n' "$FAIL"
printf '}\n'
