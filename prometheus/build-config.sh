set -eu

BASE_CONFIG=/etc/prometheus/prometheus.yml
PROJECTS_DIR=/etc/prometheus/projects
RUNTIME_CONFIG=/tmp/prometheus.runtime.yml

cp "$BASE_CONFIG" "$RUNTIME_CONFIG"
printf '\nscrape_configs:\n' >> "$RUNTIME_CONFIG"

FOUND=0
for SCRAPE_FILE in "$PROJECTS_DIR"/*/*/scrape.yml; do
  [ -f "$SCRAPE_FILE" ] || continue
  FOUND=1
  sed 's/^/  /' "$SCRAPE_FILE" >> "$RUNTIME_CONFIG"
  printf '\n' >> "$RUNTIME_CONFIG"
done

if [ "$FOUND" -eq 0 ]; then
  printf '  []\n' >> "$RUNTIME_CONFIG"
fi

exec /bin/prometheus \
  --config.file="$RUNTIME_CONFIG" \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle
