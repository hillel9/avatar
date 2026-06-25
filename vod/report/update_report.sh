#!/bin/bash
# Runs all Databricks queries and saves results to data.json
# Usage: ./update_report.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST="https://kaltura-etl-prod-nvp.cloud.databricks.com"
WAREHOUSE_ID="ccae3439c77a865d"
DATABRICKS_CLI=~/bin/databricks
DATA_FILE="$SCRIPT_DIR/data.json"
TMP_DIR=$(mktemp -d)

trap "rm -rf $TMP_DIR" EXIT

# Get OAuth token
TOKEN=$($DATABRICKS_CLI auth token --host "$HOST" 2>&1 | python3 -c "import json,sys;print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "Error: Not authenticated. Run: ~/bin/databricks auth login --host $HOST"
  exit 1
fi

# Validate token with a simple API call
AUTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$HOST/api/2.0/sql/warehouses/$WAREHOUSE_ID" -H "Authorization: Bearer $TOKEN")
if [ "$AUTH_CHECK" != "200" ]; then
  echo "Error: Token is invalid or expired (HTTP $AUTH_CHECK). Run: ~/bin/databricks auth login --host $HOST"
  exit 1
fi
echo "  Auth validated ✓"

QUERY_FAILURES=0

run_query() {
  local query_file="$1"
  local output_file="$2"

  local payload=$(python3 -c "
import json
q = open('$query_file').read()
print(json.dumps({'warehouse_id': '$WAREHOUSE_ID', 'statement': q, 'wait_timeout': '50s'}))
")

  local response=$(curl -s -X POST "$HOST/api/2.0/sql/statements/" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local status=$(echo "$response" | python3 -c "import json,sys;print(json.load(sys.stdin).get('status',{}).get('state','UNKNOWN'))" 2>/dev/null)

  if [ "$status" = "SUCCEEDED" ]; then
    echo "$response" > "$output_file"
  elif [ "$status" = "PENDING" ] || [ "$status" = "RUNNING" ]; then
    local stmt_id=$(echo "$response" | python3 -c "import json,sys;print(json.load(sys.stdin)['statement_id'])")
    echo "    Waiting for warehouse..." >&2
    sleep 15
    response=$(curl -s "$HOST/api/2.0/sql/statements/$stmt_id" -H "Authorization: Bearer $TOKEN")
    local poll_status=$(echo "$response" | python3 -c "import json,sys;print(json.load(sys.stdin).get('status',{}).get('state','UNKNOWN'))" 2>/dev/null)
    if [ "$poll_status" = "SUCCEEDED" ]; then
      echo "$response" > "$output_file"
    else
      echo "    FAILED after wait: $poll_status" >&2
      QUERY_FAILURES=$((QUERY_FAILURES + 1))
    fi
  else
    echo "    FAILED: $status" >&2
    echo "    $(echo "$response" | python3 -c "import json,sys;r=json.load(sys.stdin);print(r.get('status',{}).get('error',{}).get('message','unknown error'))" 2>/dev/null)" >&2
    QUERY_FAILURES=$((QUERY_FAILURES + 1))
  fi
}

echo "Running queries..."
echo "  [1/13] Unique users..."
run_query "$SCRIPT_DIR/queries/unique_users.sql" "$TMP_DIR/unique_users.json"

echo "  [2/13] Total videos..."
run_query "$SCRIPT_DIR/queries/total_videos.sql" "$TMP_DIR/total_videos.json"

echo "  [3/13] Daily users..."
run_query "$SCRIPT_DIR/queries/daily_users.sql" "$TMP_DIR/daily_users.json"

echo "  [4/13] Returning users..."
run_query "$SCRIPT_DIR/queries/returning_users.sql" "$TMP_DIR/returning_users.json"

echo "  [5/13] Video creation methods..."
run_query "$SCRIPT_DIR/queries/video_methods.sql" "$TMP_DIR/video_methods.json"

echo "  [6/13] POC accounts..."
run_query "$SCRIPT_DIR/queries/poc_accounts.sql" "$TMP_DIR/poc_accounts.json"

echo "  [7/13] POC accounts (IRP)..."
run_query "$SCRIPT_DIR/queries/poc_accounts_irp.sql" "$TMP_DIR/poc_accounts_irp.json"

echo "  [8/13] POC returning..."
run_query "$SCRIPT_DIR/queries/poc_returning.sql" "$TMP_DIR/poc_returning.json"

echo "  [9/13] POC returning (IRP)..."
run_query "$SCRIPT_DIR/queries/poc_returning_irp.sql" "$TMP_DIR/poc_returning_irp.json"

echo "  [10/13] Free trial..."
run_query "$SCRIPT_DIR/queries/free_trial.sql" "$TMP_DIR/free_trial.json"

echo "  [11/13] Free trial modal..."
run_query "$SCRIPT_DIR/queries/free_trial_modal.sql" "$TMP_DIR/free_trial_modal.json"

echo "  [12/13] Free trial returning..."
run_query "$SCRIPT_DIR/queries/free_trial_returning.sql" "$TMP_DIR/free_trial_returning.json"

echo "  [13/13] Free trial potential creators..."
run_query "$SCRIPT_DIR/queries/free_trial_potential.sql" "$TMP_DIR/free_trial_potential.json"

if [ "$QUERY_FAILURES" -gt 0 ]; then
  echo ""
  echo "ERROR: $QUERY_FAILURES query(s) failed. data.json NOT updated."
  exit 1
fi

# Parse all results into data.json
python3 << PYTHON
import json
from datetime import datetime

def load_resp(path):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return {}

def single_val(resp):
    try:
        return resp['result']['data_array'][0][0]
    except:
        return None

def all_rows(resp):
    try:
        return resp['result']['data_array']
    except:
        return []

unique = load_resp("$TMP_DIR/unique_users.json")
videos = load_resp("$TMP_DIR/total_videos.json")
daily = load_resp("$TMP_DIR/daily_users.json")
returning = load_resp("$TMP_DIR/returning_users.json")
methods = load_resp("$TMP_DIR/video_methods.json")
poc = load_resp("$TMP_DIR/poc_accounts.json")
poc_irp = load_resp("$TMP_DIR/poc_accounts_irp.json")
poc_ret = load_resp("$TMP_DIR/poc_returning.json")
poc_ret_irp = load_resp("$TMP_DIR/poc_returning_irp.json")
trial = load_resp("$TMP_DIR/free_trial.json")
trial_modal = load_resp("$TMP_DIR/free_trial_modal.json")
trial_returning = load_resp("$TMP_DIR/free_trial_returning.json")
trial_potential = load_resp("$TMP_DIR/free_trial_potential.json")

data = {}
data['unique_users'] = int(single_val(unique)) if single_val(unique) else None
data['total_videos'] = int(single_val(videos)) if single_val(videos) else None

ret_rows = all_rows(returning)
if ret_rows:
    data['returning_users_pct'] = round(float(ret_rows[0][2]))
else:
    data['returning_users_pct'] = None

if data['unique_users'] and data['total_videos']:
    data['avg_videos_per_user'] = round(data['total_videos'] / data['unique_users'], 1)
else:
    data['avg_videos_per_user'] = None

data['daily_users'] = []
for row in all_rows(daily):
    d = row[0][:10] if row[0] else ''
    c = int(row[1]) if row[1] else 0
    data['daily_users'].append({'date': d, 'count': c})

data['video_methods'] = {}
for row in all_rows(methods):
    if row[0]:
        data['video_methods'][row[0]] = int(row[1])

data['poc_accounts'] = []
for row in all_rows(poc):
    data['poc_accounts'].append({
        'name': row[0],
        'domain': row[1],
        'active_users': int(row[2]) if row[2] else 0,
        'videos_created': int(row[3]) if row[3] else 0,
        'last_active': row[4][:10] if row[4] else ''
    })
for row in all_rows(poc_irp):
    data['poc_accounts'].append({
        'name': row[0],
        'domain': row[1],
        'active_users': int(row[2]) if row[2] else 0,
        'videos_created': int(row[3]) if row[3] else 0,
        'last_active': row[4][:10] if row[4] else ''
    })

data['poc_returning'] = {}
for row in all_rows(poc_ret):
    if row[0]:
        data['poc_returning'][row[0]] = round(float(row[1])) if row[1] else 0
for row in all_rows(poc_ret_irp):
    if row[0]:
        data['poc_returning'][row[0]] = round(float(row[1])) if row[1] else 0

data['free_trial'] = []
for row in all_rows(trial):
    data['free_trial'].append({
        'name': row[0],
        'domain': row[1],
        'active_users': int(row[2]) if row[2] else 0,
        'videos_created': int(row[3]) if row[3] else 0
    })

data['free_trial_modal'] = {}
for row in all_rows(trial_modal):
    if row[0]:
        data['free_trial_modal'][row[0]] = int(row[1]) if row[1] else 0

data['free_trial_returning'] = {}
for row in all_rows(trial_returning):
    if row[0]:
        data['free_trial_returning'][row[0]] = round(float(row[1])) if row[1] else 0

data['free_trial_potential'] = {}
for row in all_rows(trial_potential):
    if row[0]:
        data['free_trial_potential'][row[0]] = int(row[2]) if row[2] else 0

data['updated_at'] = datetime.now().strftime('%b %-d, %Y')

with open("$DATA_FILE", 'w') as f:
    json.dump(data, f, indent=2)

print()
print(f"  Unique users:      {data['unique_users']}")
print(f"  Total videos:      {data['total_videos']}")
print(f"  Avg videos/user:   {data['avg_videos_per_user']}")
print(f"  Returning users:   {data['returning_users_pct']}%")
print(f"  Daily data points: {len(data['daily_users'])}")
print(f"  Video methods:     {data['video_methods']}")
print(f"  POC accounts:      {len(data['poc_accounts'])}")
for a in data['poc_accounts']:
    print(f"    {a['name']:30s} users={a['active_users']} videos={a['videos_created']} last={a['last_active']}")
print(f"  Free trial:        {len(data['free_trial'])}")
for a in data['free_trial']:
    modal = data['free_trial_modal'].get(a['name'], 0)
    ret = data['free_trial_returning'].get(a['name'], 0)
    pot = data['free_trial_potential'].get(a['name'], 0)
    print(f"    {a['name']:30s} modal={modal} users={a['active_users']} returning={ret}% videos={a['videos_created']} potential={pot}")
print()
print(f"Saved to $DATA_FILE")
PYTHON

echo ""
echo "Done! Now tell Claude: 'update the report' and it will read data.json"
