import random
import time
import json
from collections import Counter, deque
from typing import List, Set, Dict

# --- SIMULATION CONFIG ---
NUM_ACCOUNTS = 500
TWEETS_PER_ACCOUNT = 100
SIM_SCROLL_ITEMS = 1000
VIRAL_MEDIA_RATIO = 0.1

class Tweet:
    def __init__(self, id: str, user_id: int, media_key: str):
        self.id = id
        self.user_id = user_id
        self.media_key = media_key

class MockSQLite:
    def __init__(self):
        self.cache: List[Tweet] = []
        self.played_ids: Set[str] = set()
        self.played_media_keys: Set[str] = set()
        self.user_play_counts = Counter()

    def insert(self, tweets: List[Tweet]):
        existing_ids = {t.id for t in self.cache}
        for t in tweets:
            if t.id not in existing_ids:
                self.cache.append(t)

    def get_unplayed(self, limit: int) -> List[Tweet]:
        candidates = [
            t for t in self.cache 
            if t.id not in self.played_ids and t.media_key not in self.played_media_keys
        ]
        random.shuffle(candidates)
        return candidates[:limit]

    def mark_played(self, tweet: Tweet):
        self.played_ids.add(tweet.id)
        self.played_media_keys.add(tweet.media_key)
        self.user_play_counts[tweet.user_id] += 1

class DiscoveryEngineSimulator:
    @staticmethod
    def interleave(fresh: List[Tweet], cached: List[Tweet], ratio: float) -> List[Tweet]:
        result = []
        f_idx, c_idx = 0, 0
        current_fresh_count = 0
        while f_idx < len(fresh) or c_idx < len(cached):
            next_count = len(result) + 1
            target_fresh = int(next_count * ratio)
            if f_idx < len(fresh) and (current_fresh_count < target_fresh or c_idx >= len(cached)):
                result.append(fresh[f_idx]); f_idx += 1; current_fresh_count += 1
            elif c_idx < len(cached):
                result.append(cached[c_idx]); c_idx += 1
            else:
                if f_idx < len(fresh): result.append(fresh[f_idx]); f_idx += 1
                else: break
        return result

    @staticmethod
    def apply_saturation(tweets: List[Tweet], 
                        acc_thresh: int, 
                        med_thresh: int, 
                        window_size: int) -> tuple:
        """
        In the real app, saturation is applied to the WHOLE combined list.
        """
        if not tweets: return [], 0
        res = list(tweets)
        total_swaps = 0
        for _ in range(3):
            swaps = 0
            for i in range(len(res)):
                start = max(0, i - window_size)
                win = res[start:i]
                u_id, m_key = res[i].user_id, res[i].media_key
                u_count = sum(1 for t in win if t.user_id == u_id)
                m_count = sum(1 for t in win if t.media_key == m_key)
                prev = win[-1] if win else None
                consecutive = prev and (prev.user_id == u_id or prev.media_key == m_key)

                if u_count >= acc_thresh or m_count >= med_thresh or consecutive:
                    swap_idx = -1
                    for j in range(i + 1, len(res)):
                        cand = res[j]
                        c_u_count = sum(1 for t in win if t.user_id == cand.user_id)
                        c_m_count = sum(1 for t in win if t.media_key == cand.media_key)
                        c_consecutive = prev and (prev.user_id == cand.user_id or prev.media_key == cand.media_key)
                        if c_u_count < acc_thresh and c_m_count < med_thresh and not c_consecutive:
                            swap_idx = j; break
                    if swap_idx != -1:
                        res[i], res[swap_idx] = res[swap_idx], res[i]
                        swaps += 1; total_swaps += 1
            if swaps == 0: break
        return res, total_swaps

class Benchmark:
    def __init__(self, dataset):
        self.dataset = dataset

    def run(self, params: Dict):
        db = MockSQLite()
        ui_feed = deque() # Items currently in the ScrollView
        consumed, api_calls = 0, 0
        consumed_history = deque(maxlen=30)
        violations = 0

        while consumed < SIM_SCROLL_ITEMS:
            # Mimic App: Fetch more when UI buffer < lazy_load_threshold
            if len(ui_feed) < params['lazy_load_threshold']:
                api_calls += 1
                
                # 1. API Fetch (Using api_batch_size / timelineBatchSize)
                fresh = random.sample(self.dataset, params['api_batch_size'])
                db.insert(fresh)
                
                # 2. Local Pool Gathering (Mimics fetchMore loop)
                # In app, we collect unique candidates until minNewTweetsThreshold
                # For simulation, we'll fetch a batch from DB and interleave
                cached = db.get_unplayed(params['api_batch_size'] * params['db_mult'])
                combined = DiscoveryEngineSimulator.interleave(fresh, cached, params['mix'])
                
                # 3. Take UI Slot Size (loadBatchSize)
                # App shuffles and takes loadBatchSize
                random.shuffle(combined)
                new_slice = combined[:params['ui_slot_size']]
                
                # 4. Appends and runs saturation on WHOLE list
                current_list = list(ui_feed) + new_slice
                processed, _ = DiscoveryEngineSimulator.apply_saturation(
                    current_list, 1, 1, params['engine_window']
                )
                
                # Update ui_feed with the newly sorted list
                ui_feed = deque(processed)

            if not ui_feed: break
            
            # User consumes the first item
            item = ui_feed.popleft()
            
            # --- EVALUATOR ---
            u_win_10 = [t.user_id for t in list(consumed_history)[-10:]]
            m_win_20 = [t.media_key for t in list(consumed_history)[-20:]]
            
            if item.user_id in u_win_10 or item.media_key in m_win_20:
                violations += 1
            
            db.mark_played(item)
            consumed_history.append(item)
            consumed += 1

        return {
            "api": api_calls,
            "items_per_call": round(consumed / api_calls, 1),
            "violations": violations,
            "score": (consumed * 10) - (api_calls * 100) - (violations * 50)
        }

# Generate Data
data = []
viral = [f"v_{i}" for i in range(50)]
for u in range(NUM_ACCOUNTS):
    for t in range(TWEETS_PER_ACCOUNT):
        m = random.choice(viral) if random.random() < VIRAL_MEDIA_RATIO else f"m_{u}_{t}"
        data.append(Tweet(f"{u}_{t}", u, m))

bench = Benchmark(data)
results = []

# --- ULTIMATE PARAMETER SWEEP ---
api_batch_sizes = [50, 100, 200]    # timelineBatchSize
ui_slot_sizes = [10, 20, 50]        # loadBatchSize
lazy_thresholds = [5, 10, 15]       # lazyLoadThreshold
mix_ratios = [0.1, 0.3]
db_mults = [2, 5]

print(f"BEYOND ULTIMATE PARAMETER SWEEP (Slot Size & Lazy Load)")
print("-" * 110)
print(f"{'API-B':<5} | {'UI-S':<5} | {'Lazy':<5} | {'Mix':<5} | {'DBX':<5} | {'API':<5} | {'Vio':<5} | {'Score'}")
print("-" * 110)

count = 0
for b_api in api_batch_sizes:
    for s_ui in ui_slot_sizes:
        for lazy in lazy_thresholds:
            for m in mix_ratios:
                for dbx in db_mults:
                    p = {
                        "api_batch_size": b_api, 
                        "ui_slot_size": s_ui, 
                        "lazy_load_threshold": lazy,
                        "mix": m, 
                        "db_mult": dbx, 
                        "engine_window": 30
                    }
                    res = bench.run(p)
                    res.update(p)
                    results.append(res)
                    count += 1
                    if count % 20 == 0:
                        print(f"{b_api:<5} | {s_ui:<5} | {lazy:<5} | {m:<5} | {dbx:<5} | {res['api']:<5} | {res['violations']:<5} | {res['score']}")

best = max(results, key=lambda x: x['score'])
print("\n" + "="*110)
print(f"VERIFIED WINNER AFTER {len(results)} SCENARIOS")
print(f"Timeline Batch (Server): {best['api_batch_size']}")
print(f"UI Slot Size (Load):     {best['ui_slot_size']}")
print(f"Lazy Load Threshold:     {best['lazy_load_threshold']}")
print(f"Fresh Mix Ratio:         {best['mix']}")
print(f"DB Multiplier:           {best['db_mult']}")
print("-" * 110)
print(f"Performance: {best['items_per_call']} items/req | {best['violations']} violations.")
print("="*110)
