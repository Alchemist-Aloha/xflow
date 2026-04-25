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
                        window_size: int,
                        history: List[Tweet]) -> tuple:
        if not tweets: return [], 0
        res = list(tweets)
        total_swaps = 0
        for _ in range(3):
            swaps = 0
            for i in range(len(res)):
                full_context = list(history) + res[:i]
                start = max(0, len(full_context) - window_size)
                win = full_context[start:]
                u_id, m_key = res[i].user_id, res[i].media_key
                u_count = sum(1 for t in win if t.user_id == u_id)
                m_count = sum(1 for t in win if t.media_key == m_key)
                prev = win[-1] if win else None
                consecutive = prev and (prev.user_id == u_id or prev.media_key == m_key)

                if u_count >= acc_thresh or m_count >= med_thresh or consecutive:
                    swap_idx = -1
                    for j in range(i + 1, min(len(res), i + window_size + 15)):
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
        ui_feed = deque()
        consumed, api_calls, total_fetched, api_waste = 0, 0, 0, 0
        consumed_history = deque(maxlen=30)
        violations = 0

        while consumed < SIM_SCROLL_ITEMS:
            if len(ui_feed) < params['lazy_load_threshold']:
                api_calls += 1
                
                # 1. API Fetch
                raw_fresh = random.sample(self.dataset, params['batch_size'])
                total_fetched += params['batch_size']
                
                # 2. GLOBAL DEDUPLICATION (Consider "Repeated Feed")
                # Filter out any items we've already watched
                fresh = [t for t in raw_fresh if t.media_key not in db.played_media_keys]
                api_waste += (params['batch_size'] - len(fresh))
                
                # Insert the actually unique items into DB
                db.insert(fresh)
                
                # 3. Cache Fetch
                cached = db.get_unplayed(params['batch_size'] * params['db_mult'])
                
                # 4. Interleave
                combined = DiscoveryEngineSimulator.interleave(fresh, cached, params['mix'])
                
                # 5. UI Slicing (App logic: slice then saturate)
                random.shuffle(combined)
                new_slice = combined[:params['ui_slot_size']]
                
                # 6. Saturate
                processed, _ = DiscoveryEngineSimulator.apply_saturation(
                    list(ui_feed) + new_slice, 1, 1, params['engine_window'], list(consumed_history)
                )
                ui_feed = deque(processed)

            if not ui_feed: 
                # If we've watched everything or diversity is impossible
                break
            
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
            "waste_rate": round(api_waste / total_fetched, 3) if total_fetched > 0 else 0,
            "items_per_call": round(consumed / api_calls, 1),
            "violations": violations,
            # Penalty for: API calls, Violations, and WASTED items
            "score": (consumed * 10) - (api_calls * 100) - (violations * 50) - (api_waste * 2)
        }

# --- DATA GENERATION ---
data = []
viral = [f"v_{i}" for i in range(50)]
for u in range(NUM_ACCOUNTS):
    for t in range(TWEETS_PER_ACCOUNT):
        m = random.choice(viral) if random.random() < VIRAL_MEDIA_RATIO else f"m_{u}_{t}"
        data.append(Tweet(f"{u}_{t}", u, m))

bench = Benchmark(data)
results = []

# Sweep configurations
batch_sizes = [50, 100, 200]
mix_ratios = [0.1, 0.3, 0.5]
db_mults = [2, 5, 10]

print(f"ULTIMATE PARAMETER SWEEP WITH WASTE DETECTION")
print("-" * 110)
print(f"{'Batch':<5} | {'Mix':<5} | {'DBX':<5} | {'API':<5} | {'Waste%':<8} | {'Items/Req':<10} | {'Vio':<5} | {'Score'}")
print("-" * 110)

for b in batch_sizes:
    for m in mix_ratios:
        for dbx in db_mults:
            p = {
                "batch_size": b, 
                "mix": m, 
                "db_mult": dbx, 
                "engine_window": 30, 
                "lazy_load_threshold": 10,
                "ui_slot_size": 20
            }
            res = bench.run(p)
            res.update(p)
            results.append(res)
            print(f"{b:<5} | {m:<5} | {dbx:<5} | {res['api']:<5} | {res['waste_rate']*100:<8}% | {res['items_per_call']:<10} | {res['violations']:<5} | {res['score']}")

best = max(results, key=lambda x: x['score'])
print("\n" + "="*110)
print(f"VERIFIED WINNER: Batch {best['batch_size']}, Mix {best['mix']}, DB Multiplier {best['db_mult']}")
print(f"Waste Rate: {best['waste_rate']*100}% of API items were already seen.")
print(f"Performance: {best['items_per_call']} unique items delivered per request.")
print("="*110)
