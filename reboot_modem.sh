#!/bin/sh
# reboot_modem.sh - Soft reboot Huawei E3372H-153 by toggling network modes
# Usage: sh reboot_modem.sh [192.168.8.1]

HOST="${1:-192.168.8.1}"

# Get initial tokens
curl -s -X GET "http://${HOST}/api/webserver/SesTokInfo" > /tmp/ses_tok.xml
COOKIE=$(grep "SessionID=" /tmp/ses_tok.xml | sed 's/.*<SesInfo>\(SessionID=[^<]*\)<\/SesInfo>.*/\1/' | tr -d ' \n\r')
TOKEN=$(grep "<TokInfo>" /tmp/ses_tok.xml | sed 's/.*<TokInfo>\([^<]*\)<\/TokInfo>.*/\1/' | tr -d ' \n\r')

# Switch to 4G-only mode
curl -s -X POST -H "Cookie: ${COOKIE}" -H "__RequestVerificationToken: ${TOKEN}" -H "Content-Type: application/xml" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><NetworkMode>02</NetworkMode><NetworkBand>3FFFFFFF</NetworkBand><LTEBand>7FFFFFFFFFFFFFFF</LTEBand></request>" "http://${HOST}/api/net/net-mode" >/dev/null 2>&1

sleep 3

# Refresh tokens for the second request
curl -s -X GET "http://${HOST}/api/webserver/SesTokInfo" > /tmp/ses_tok.xml
COOKIE=$(grep "SessionID=" /tmp/ses_tok.xml | sed 's/.*<SesInfo>\(SessionID=[^<]*\)<\/SesInfo>.*/\1/' | tr -d ' \n\r')
TOKEN=$(grep "<TokInfo>" /tmp/ses_tok.xml | sed 's/.*<TokInfo>\([^<]*\)<\/TokInfo>.*/\1/' | tr -d ' \n\r')

# Switch to Auto/4G+3G+2G mode (triggers network re-registration)
curl -s -X POST -H "Cookie: ${COOKIE}" -H "__RequestVerificationToken: ${TOKEN}" -H "Content-Type: application/xml" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><NetworkMode>03</NetworkMode><NetworkBand>3FFFFFFF</NetworkBand><LTEBand>7FFFFFFFFFFFFFFF</LTEBand></request>" "http://${HOST}/api/net/net-mode" >/dev/null 2>&1

echo "Network mode toggle completed. Modem will reconnect shortly."
