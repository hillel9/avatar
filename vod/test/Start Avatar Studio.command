#!/bin/bash
cd "$(dirname "$0")"

# Kill any previously running proxy
pkill -f proxy.js 2>/dev/null
sleep 1

open http://localhost:3000
node proxy.js
