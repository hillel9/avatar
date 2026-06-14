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
TOKEN=$($DATABRICKS_CLI auth token --host "$HOST" 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "Error: Not authenticated. Run: ~/bin/databricks auth login --host $HOST"
  exit 1
fi

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

  local status=$(echo "$response" | python3 -c "import json,sys;print(json.load(sys.stdin).get('status',{}).get('state',''))" 2>/dev/null)

  if [ "$status" = "SUCCEEDED" ]; then
    echo "$response" > "$output_file"
  elif [ "$status" = "PENDING" ] || [ "$status" = "RUNNING" ]; then
    local stmt_id=$(echo "$response" | python3 -c "import json,sys;print(json.load(sys.stdin)['statement_id'])")
    echo "    Waiting for warehouse..." >&2
    sleep 15
    curl -s "$HOST/api/2.0/sql/statements/$stmt_id" -H "Authorization: Bearer $TOKEN" > "$output_file"
  else
    echo "    ERROR: $status" >&2
    echo "$response" > "$output_file"
  fi
}

echo "Running queries..."
echo "  [1/7] Unique users..."
run_query "$SCRIPT_DIR/queries/unique_users.sql" "$TMP_DIR/unique_users.json"

echo "  [2/7] Total videos..."
run_query "$SCRIPT_DIR/queries/total_videos.sql" "$TMP_DIR/total_videos.json"

echo "  [3/7] Daily users..."
run_query "$SCRIPT_DIR/queries/daily_users.sql" "$TMP_DIR/daily_users.json"

echo "  [4/7] Returning users..."
run_query "$SCRIPT_DIR/queries/returning_users.sql" "$TMP_DIR/returning_users.json"

echo "  [5/7] Video creation methods..."
run_query "$SCRIPT_DIR/queries/video_methods.sql" "$TMP_DIR/video_methods.json"

echo "  [6/7] POC accounts..."
run_query "$SCRIPT_DIR/queries/poc_accounts.sql" "$TMP_DIR/poc_accounts.json"

echo "  [7/7] Free trial..."
run_query "$SCRIPT_DIR/queries/free_trial.sql" "$TMP_DIR/free_trial.json"

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
trial = load_resp("$TMP_DIR/free_trial.json")

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

data['free_trial'] = []
for row in all_rows(trial):
    data['free_trial'].append({
        'name': row[0],
        'domain': row[1],
        'active_users': int(row[2]) if row[2] else 0,
        'videos_created': int(row[3]) if row[3] else 0
    })

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
    print(f"    {a['name']:30s} users={a['active_users']} videos={a['videos_created']}")
print()
print(f"Saved to $DATA_FILE")
PYTHON

echo ""
echo "Done! Now tell Claude: 'update the report' and it will read data.json"
