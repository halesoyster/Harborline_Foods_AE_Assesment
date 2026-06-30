"""
Harborline Foods - synthetic data generator.

Produces CSVs that match the structures in the Blue Margin assessment brief, with
the Brand B mapping gap intentionally baked in so the Task 1 fix is provable.

Outputs (to ../data/):
    dim_locations.csv          # NOTE: deliberately has NO qu_store_code column
    toast_transactions.csv     # Brand A POS (already-net sales)
    qu_transactions.csv        # Brand B POS (gross + promo, net must be derived)
    r365_gl_entries.csv        # COGS + labor GL, costs stored negative
    qu_location_crosswalk.csv  # the authoritative Qu store -> location map (Task 1 input)

Run:  python generate_data.py
Reproducible via SEED. Claude Code: validate row counts and the Brand B gap after running.
"""

import csv
import os
import random
from datetime import date, timedelta

SEED = 42
random.seed(SEED)

OUT = os.path.join(os.path.dirname(__file__), "..", "data")
os.makedirs(OUT, exist_ok=True)

# --- calendar: ~13 weeks so a rolling 4-week window has history -----------------
START = date(2024, 4, 1)
END = date(2024, 6, 30)


def daterange(start, end):
    d = start
    while d <= end:
        yield d
        d += timedelta(days=1)


# --- locations ------------------------------------------------------------------
# Brand A = 28 Toast locations; Brand B = 9 Qu locations.
# (The real group is 40+ across three brands; the provided POS samples cover A and B,
#  so Brand C is out of scope for net sales here - noted in context.md.)
REGIONS = ["Mountain West", "Front Range", "High Plains", "Western Slope"]

BRAND_A_NAMES = [
    "Downtown Denver", "Cherry Creek", "Boulder Pearl St", "Fort Collins Old Town",
    "Colorado Springs", "Aurora Southlands", "Lakewood Belmar", "Littleton Aspen Grove",
    "Highlands Ranch", "Westminster", "Arvada Olde Town", "Centennial",
    "Parker Mainstreet", "Castle Rock", "Greeley", "Loveland",
    "Longmont", "Broomfield Flatiron", "Englewood", "Wheat Ridge",
    "Thornton", "Northglenn", "Commerce City", "Golden",
    "Louisville", "Superior", "Erie", "Brighton",
]  # 28
BRAND_B_NAMES = [
    "Cherry Creek Bistro", "LoDo Kitchen", "RiNo Tap", "Wash Park Cafe",
    "Berkeley Table", "Capitol Hill Counter", "Sloans Lake Grill",
    "Stapleton Eatery", "Belmar Social",
]  # 9


def build_locations():
    rows = []
    key = 1
    for i, name in enumerate(BRAND_A_NAMES, start=1):
        rows.append({
            "location_key": key,
            "location_name": name,
            "brand": "Brand A",
            "region": random.choice(REGIONS),
            "toast_loc_id": f"LOC-{i:02d}",   # Brand A has a Toast id
        })
        key += 1
    for j, name in enumerate(BRAND_B_NAMES, start=1):
        rows.append({
            "location_key": key,
            "location_name": name,
            "brand": "Brand B",
            "region": random.choice(REGIONS),
            "toast_loc_id": "",               # Brand B has no Toast id (NULL)
        })
        key += 1
    return rows


def qu_crosswalk(locations):
    """The authoritative Qu store -> location mapping (what was never loaded into the dim).
    Brand B location_key N (the j-th Brand B store) maps to STR-B0j."""
    rows = []
    j = 1
    for loc in locations:
        if loc["brand"] == "Brand B":
            rows.append({
                "location_key": loc["location_key"],
                "location_name": loc["location_name"],
                "qu_store_code": f"STR-B{j:02d}",
            })
            j += 1
    return rows


# --- transactions ---------------------------------------------------------------
def gen_toast(locations):
    rows = []
    tid = 1
    a_locs = [l for l in locations if l["brand"] == "Brand A"]
    for loc in a_locs:
        for d in daterange(START, END):
            # weekday vs weekend volume
            n = random.randint(3, 6) if d.weekday() < 4 else random.randint(5, 9)
            for _ in range(n):
                gross = round(random.uniform(120, 650), 2)
                discount = round(gross * random.choice([0, 0, 0, 0.05, 0.10]), 2)
                net = round(gross - discount, 2)  # net_sales is ALREADY net
                rows.append({
                    "transaction_id": f"TXN-{tid:06d}",
                    "location_id": loc["toast_loc_id"],
                    "transaction_date": d.isoformat(),
                    "net_sales": net,
                    "discount_amount": discount,
                    "covers": random.randint(2, 14),
                })
                tid += 1
    return rows


def gen_qu(crosswalk):
    rows = []
    oid = 1
    for x in crosswalk:
        code = x["qu_store_code"]
        for d in daterange(START, END):
            n = random.randint(2, 5) if d.weekday() < 4 else random.randint(4, 7)
            for _ in range(n):
                gross = round(random.uniform(90, 520), 2)
                promo = round(gross * random.choice([0, 0, 0, 0.08, 0.12]), 2)
                rows.append({
                    "order_id": f"QU-{oid:06d}",
                    "store_code": code,               # STR-B##
                    "order_date": d.isoformat(),
                    "gross_sales": gross,             # NET must be derived: gross - promo
                    "promo_deductions": promo,
                    "guest_count": random.randint(1, 10),
                })
                oid += 1
    return rows


def gen_r365(locations, toast_rows, qu_rows, crosswalk):
    """One COGS and one Labor GL entry per location per day, scaled off that day's sales
    so Prime Cost % lands in a realistic band. Costs stored NEGATIVE (GL convention)."""
    # daily net sales by location_code (R365 uses LOC-## for Brand A; STR-B## for Brand B here)
    daily = {}
    for t in toast_rows:
        daily.setdefault((t["location_id"], t["transaction_date"]), 0.0)
        daily[(t["location_id"], t["transaction_date"])] += t["net_sales"]
    for q in qu_rows:
        net = round(q["gross_sales"] - q["promo_deductions"], 2)
        daily.setdefault((q["store_code"], q["order_date"]), 0.0)
        daily[(q["store_code"], q["order_date"])] += net

    rows = []
    eid = 1
    for (loc_code, d), sales in daily.items():
        cogs = round(sales * random.uniform(0.28, 0.34), 2)    # ~food cost
        labor = round(sales * random.uniform(0.24, 0.30), 2)   # ~labor cost
        rows.append({"entry_id": f"GL-{eid:06d}", "location_code": loc_code,
                     "account_code": 5100, "account_name": "Food COGS",
                     "posting_date": d, "amount": -cogs})
        eid += 1
        rows.append({"entry_id": f"GL-{eid:06d}", "location_code": loc_code,
                     "account_code": 6000, "account_name": "Labor - Hourly",
                     "posting_date": d, "amount": -labor})
        eid += 1
    return rows


def write_csv(name, rows, fields):
    path = os.path.join(OUT, name)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {name:32s} {len(rows):>7,} rows")


def main():
    locations = build_locations()
    crosswalk = qu_crosswalk(locations)
    toast = gen_toast(locations)
    qu = gen_qu(crosswalk)
    r365 = gen_r365(locations, toast, qu, crosswalk)

    print("Generating Harborline synthetic data...")
    # dim_locations is written WITHOUT qu_store_code on purpose (the gap Task 1 fixes).
    write_csv("dim_locations.csv", locations,
              ["location_key", "location_name", "brand", "region", "toast_loc_id"])
    write_csv("toast_transactions.csv", toast,
              ["transaction_id", "location_id", "transaction_date", "net_sales",
               "discount_amount", "covers"])
    write_csv("qu_transactions.csv", qu,
              ["order_id", "store_code", "order_date", "gross_sales",
               "promo_deductions", "guest_count"])
    write_csv("r365_gl_entries.csv", r365,
              ["entry_id", "location_code", "account_code", "account_name",
               "posting_date", "amount"])
    write_csv("qu_location_crosswalk.csv", crosswalk,
              ["location_key", "location_name", "qu_store_code"])

    print(f"\nBrand B locations (unmapped in dim_locations): "
          f"{sum(1 for l in locations if l['brand']=='Brand B')}")
    print("Done. dim_locations intentionally has NO qu_store_code -> Task 1 fixes it.")


if __name__ == "__main__":
    main()
