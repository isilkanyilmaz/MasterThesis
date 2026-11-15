
import csv
import json
import os
import random
import shutil
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from bs4 import BeautifulSoup

#FILES AND SETTINGS
INPUT = "data_processed/viewing_events.csv"
OUTPUT = "data_processed/video_metadata.csv"
WORKERS = 5                  # Start modestly; increase to 8 only if requests succeed
CHUNK_SIZE = 500             # Save progress after each chunk
MAX_BLOCKED_RUNS = 3
URL = "https://www.tiktokv.com/share/video/{}/"

FIELDS = ["video_id", "status", "category", "diversification_labels"]

#On first run, reusing existing 14-day metadata results without modifying the old file.
OLD_METADATA = "data_processed/video_metadata.csv"
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
if not os.path.exists(OUTPUT) and os.path.exists(OLD_METADATA):
    shutil.copy2(OLD_METADATA, OUTPUT)
    print("Copied existing metadata cache for reuse.")

#REUSING HTTPS CONNECTIONS
session = requests.Session()
session.headers.update({"User-Agent": "Mozilla/5.0", "Accept-Language": "en-US,en;q=0.8"})
adapter = requests.adapters.HTTPAdapter(pool_connections=WORKERS, pool_maxsize=WORKERS)
session.mount("https://", adapter)

#SHARED DELAY: SLOW DOWN WHEN TIKTOK BLOCKS REQUESTS
lock = threading.Lock()
delay = 0.25
pause_until = 0


def fetch(video_id):
    global delay, pause_until
    with lock:
        wait = delay
        pause = pause_until
    time.sleep(max(0, pause - time.time()) + wait + random.uniform(0, 0.05))

    try:
        response = session.get(URL.format(video_id), timeout=20)
        response.raise_for_status()
        tag = BeautifulSoup(response.text, "html.parser").find(
            "script", id="__UNIVERSAL_DATA_FOR_REHYDRATION__"
        )
        page = json.loads(tag.string)
        detail = page.get("__DEFAULT_SCOPE__", {}).get("webapp.video-detail")
        if not isinstance(detail, dict):
            raise ValueError("Video detail missing from page")
    except (requests.RequestException, AttributeError, TypeError, ValueError):
        with lock:
            delay = min(8, max(0.2, delay) * 1.6)
            pause_until = time.time() + 5
        return {"video_id": video_id, "status": "blocked"}

    with lock:
        delay = max(0, delay - 0.02)

    item = detail.get("itemInfo", {}).get("itemStruct") or {}
    if not item.get("id"):
        return {"video_id": video_id, "status": "unavailable"}

    labels = item.get("diversificationLabels")
    return {
        "video_id": video_id,
        "status": "ok",
        "category": item.get("CategoryType"),
        "diversification_labels": json.dumps(labels) if labels is not None else "",
    }


#READING ONLY UNIQUE VIDEO IDS FROM SCRIPT 3
with open(INPUT, newline="", encoding="utf-8-sig") as f:
    viewing_events = list(csv.DictReader(f))
video_ids = {row["video_id"].strip() for row in viewing_events
             if row.get("video_id") and row["video_id"].strip().isdigit()}
             
print("Viewing events:", len(viewing_events))

print("Unique video IDs:", len(video_ids))

print("Duplicate viewing events (no extra requests):", len(viewing_events) - len(video_ids))

#IF AN OLDER OUTPUT HAS EXTRA COLUMNS, KEEP ITS RESULTS BUT DROP THOSE COLUMNS

#DOING THIS ONCE BEFORE APPENDING FOUR-COLUMN RESULTS

if os.path.exists(OUTPUT) and os.path.getsize(OUTPUT) > 0:
    with open(OUTPUT, newline="", encoding="utf-8") as f:
        old_rows = list(csv.DictReader(f))
    if old_rows and list(old_rows[0]) != FIELDS:
        with open(OUTPUT, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=FIELDS)
            writer.writeheader()
            for row in old_rows:
                writer.writerow({name: row.get(name, "") for name in FIELDS})
        print("Existing metadata file converted to four columns.")

#SKIPPING FINISHED VIDEOS AND RETYRING BLOCKED VIDEOS ON LATER RUNS
finished = set()
blocked_counts = {}
if os.path.exists(OUTPUT):
    with open(OUTPUT, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            video_id = row["video_id"]
            if row["status"] == "blocked":
                blocked_counts[video_id] = blocked_counts.get(video_id, 0) + 1
            else:
                finished.add(video_id)

todo = sorted(video_ids - finished - {
    video_id for video_id, count in blocked_counts.items()
    if count >= MAX_BLOCKED_RUNS
})
print("Videos remaining to scrape:", len(todo))

#SCRAPING IN PARALLEL AND APPENDING RESULTS WITHOUT REWRITING THE FILE
new_file = not os.path.exists(OUTPUT) or os.path.getsize(OUTPUT) == 0
with open(OUTPUT, "a", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=FIELDS, extrasaction="ignore")
    if new_file:
        writer.writeheader()

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for start in range(0, len(todo), CHUNK_SIZE):
            chunk = todo[start:start + CHUNK_SIZE]
            futures = [pool.submit(fetch, video_id) for video_id in chunk]
            for future in as_completed(futures):
                writer.writerow(future.result())
            f.flush()
            print("Processed:", start + len(chunk), "/", len(todo),
                  "| current delay:", round(delay, 2), "seconds", flush=True)

print("Finished. Metadata saved to", OUTPUT)
