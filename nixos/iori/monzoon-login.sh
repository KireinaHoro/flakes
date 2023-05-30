#!/usr/bin/env bash

set -eu

CHECK_204_URL="http://google.com/generate_204"
MONZOON_URL='https://zrh1-as25.monzoon.net/login'

# FIXME: do we need this cookie?
# -H "Cookie: lang=de; airportloginmulti=vouchercode=%7Cmobileno=%7Cmobilepassword=%7Cvoucherusername=${MONZOON_USER}%7Cvoucherpassword=${MONZOON_PASS}" \

if [[ "$($CURL -s "${CHECK_204_URL}" -w "%{http_code}")" != "204" ]]; then
    $CURL "$MONZOON_URL" \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
        -H 'Accept-Language: de,de-DE;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6,ja;q=0.5' \
        -H 'Cache-Control: max-age=0' \
        -H 'Connection: keep-alive' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -H "Origin: ${MONZOON_URL}" \
        -H "Referer: ${MONZOON_URL}/ponsoredloginng/vou/?originalUrl=http%3A%2F%2Fgoogle.com%2F" \
        -H 'Sec-Fetch-Dest: document' \
        -H 'Sec-Fetch-Mode: navigate' \
        -H 'Sec-Fetch-Site: same-origin' \
        -H 'Sec-Fetch-User: ?1' \
        -H 'Upgrade-Insecure-Requests: 1' \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36 Edg/113.0.1774.57' \
        -H 'sec-ch-ua: "Microsoft Edge";v="113", "Chromium";v="113", "Not-A.Brand";v="24"' \
        -H 'sec-ch-ua-mobile: ?0' \
        -H 'sec-ch-ua-platform: "Windows"' \
        --data-raw "errorUrl=%2Fsponsoredloginng%2Fvou%2Findex.php&realmSuffix=%40monzoon.net&lang=de&handlesessionwindow=0&jsTargetSuccess=top&username=${MONZOON_USER}&password=${MONZOON_PASS}&gtc_accept=1&button_connect=1" \
        --compressed
    echo "Sent login request"
else
    echo "Already logged in"
fi
