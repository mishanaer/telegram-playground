"""Analyze observer callback cadence, never claim compositor/rendered FPS."""
import argparse
import csv
import json
import math
import statistics


def percentiles(values):
    ordered = sorted(values)

    def percentile(q):
        position = (len(ordered) - 1) * q
        lo = int(position)
        hi = min(lo + 1, len(ordered) - 1)
        return ordered[lo] + (ordered[hi] - ordered[lo]) * (position - lo)

    return {"median_ms": statistics.median(ordered) * 1000,
            "p95_ms": percentile(.95) * 1000,
            "p99_ms": percentile(.99) * 1000,
            "max_ms": max(ordered) * 1000}


def analyze(rows):
    if len(rows) < 2:
        raise ValueError("At least two callbacks are required")
    timestamps, targets, callbacks = zip(*rows)
    if not all(math.isfinite(value) for row in rows for value in row):
        raise ValueError("Non-finite timestamp")
    callback_intervals = [b - a for a, b in zip(callbacks, callbacks[1:])]
    display_intervals = [b - a for a, b in zip(timestamps, timestamps[1:])]
    periods = [target - stamp for stamp, target in zip(timestamps, targets)]
    if min(callback_intervals + display_intervals + periods) <= 0:
        raise ValueError("Timestamps must increase and target must be later than timestamp")
    # Estimate against each previous callback's announced next-display period.
    missed = [max(0, math.floor(delta / period + .5) - 1)
              for delta, period in zip(display_intervals, periods)]
    return {
        "metric": "CADisplayLink callback cadence; not rendered FPS",
        "callbacks": len(rows),
        "window_between_callbacks_seconds": callbacks[-1] - callbacks[0],
        "callbacks_per_second": (len(rows) - 1) / (callbacks[-1] - callbacks[0]),
        "callback_intervals": percentiles(callback_intervals),
        "display_timestamp_intervals": percentiles(display_intervals),
        "announced_periods": percentiles(periods),
        "estimated_missed_expected_slots": sum(missed),
        "intervals_with_estimated_slot_misses": sum(value > 0 for value in missed),
        "limits": "Slot estimates use timestamp delta / previous (target_timestamp - timestamp), rounded to the nearest slot. Dynamic frame-rate policy changes can affect the estimate. Callback cadence does not measure rendered frames or GPU/compositor hitches."
    }


def self_test():
    rows = [(i / 60, (i + 1) / 60, i / 60 + .001) for i in range(61)]
    result = analyze(rows)
    assert abs(result["callbacks_per_second"] - 60) < 1e-8
    assert result["estimated_missed_expected_slots"] == 0
    delayed = rows[:30] + rows[31:]
    assert analyze(delayed)["estimated_missed_expected_slots"] == 1
    assert abs(percentiles([.01, .02, .03])["p95_ms"] - 29) < 1e-8
    print("PASS: regular cadence, one missing expected slot, percentile interpolation")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_path", nargs="?")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif args.csv_path:
        with open(args.csv_path, newline="") as file:
            samples = [(float(row["timestamp"]), float(row["target_timestamp"]),
                        float(row["callback_time"])) for row in csv.DictReader(file)]
        print(json.dumps(analyze(samples), indent=2))
    else:
        parser.error("Provide a CSV path or --self-test")
