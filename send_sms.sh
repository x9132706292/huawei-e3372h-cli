#!/bin/sh
# send_sms.sh - Send SMS via Huawei E3372H-153 (BusyBox compatible)
# Usage: sh send_sms.sh [192.168.8.1] <phone_number> <message_text>
# Example: ./send_sms.sh 192.168.8.1 79991234567 "Hello, this is a test message!"

HOST="${1:-192.168.8.1}"
PHONE="${2}"
MSG="${3}"

# Check parameters
if [ -z "$PHONE" ] || [ -z "$MSG" ]; then
    printf '{"error":"missing_params","message":"Usage: send_sms.sh [host] <phone> <message>"}\n'
    exit 1
fi

# 1. Authentication (proven mechanism)
curl -s "http://${HOST}/api/webserver/SesTokInfo" > /tmp/ses_tok.xml
COOKIE=$(grep "SessionID=" /tmp/ses_tok.xml | sed 's/.*<SesInfo>\(SessionID=[^<]*\)<\/SesInfo>.*/\1/' | tr -d ' \n\r')
TOKEN=$(grep "<TokInfo>" /tmp/ses_tok.xml | sed 's/.*<TokInfo>\([^<]*\)<\/TokInfo>.*/\1/' | tr -d ' \n\r')

if [ -z "$COOKIE" ] || [ -z "$TOKEN" ]; then
    printf '{"error":"auth_failed","message":"No tokens"}\n'
    exit 1
fi

sleep 1  # workaround for error 100005

# 2. Prepare data
# Remove spaces and + from number (some firmwares reject + at the start)
PHONE_CLEAN=$(echo "$PHONE" | sed 's/[^0-9]//g')

# XML-escape special characters in message (& < > ")
ESCAPED_MSG=$(printf '%s' "$MSG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

# Message length (bytes)
MSG_LEN=$(printf '%s' "$MSG" | wc -c | tr -d ' ')

# Build XML request
XML_DATA="<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><Index>-1</Index><Phones><Phone>${PHONE_CLEAN}</Phone></Phones><Sca></Sca><Content>${ESCAPED_MSG}</Content><Length>${MSG_LEN}</Length><Reserved>1</Reserved><Date>-1</Date></request>"

# 3. Send request
RESP=$(curl -s --max-time 15 \
    -H "Cookie: ${COOKIE}" \
    -H "__RequestVerificationToken: ${TOKEN}" \
    -H "Content-Type: application/xml" \
    -H "Accept: */*" \
    -H "User-Agent: Mozilla/5.0" \
    -X POST -d "${XML_DATA}" \
    "http://${HOST}/api/sms/send-sms")

# 4. Process response
if echo "$RESP" | grep -q "<response>OK</response>"; then
    printf '{"status":"success","phone":"%s","length":%d,"message":"Sent successfully"}\n' "$PHONE" "$MSG_LEN"
else
    CODE=$(echo "$RESP" | sed -n 's/.*<code>\([^<]*\)<\/code>.*/\1/p')
    ERR_MSG="Unknown error"
    case "$CODE" in
        125003) ERR_MSG="Invalid number or network not ready" ;;
        125004) ERR_MSG="Message too long (max ~70 Cyrillic chars)" ;;
        100005) ERR_MSG="Session expired. Retry in 2 sec" ;;
        125001) ERR_MSG="SMS storage full" ;;
        *)      [ -n "$CODE" ] && ERR_MSG="API error $CODE" ;;
    esac
    printf '{"error":"send_failed","code":"%s","message":"%s"}\n' "$CODE" "$ERR_MSG"
    exit 1
fi
