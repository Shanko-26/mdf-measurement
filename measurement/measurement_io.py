"""Read ASAM MDF files for the MATLAB measurement app.

MATLAB mdfRead does not run on macOS. This helper returns JSON summaries and
decimated traces. Statistics are computed on the full time slice.
"""

import json
import sys
import warnings

warnings.filterwarnings("ignore")


def main():
    command = sys.argv[1]
    with open(sys.argv[2], encoding="utf-8") as handle:
        request = json.load(handle)

    if command == "demo":
        create_demo(request["file"])
        print(json.dumps({"file": request["file"]}))
        return

    from asammdf import MDF

    with MDF(request["file"]) as mdf:
        if command == "info":
            payload = file_info(mdf, request["file"])
        elif command == "channels":
            payload = {"channels": list_channels(mdf, request.get("query", ""))}
        elif command == "read":
            payload = {"signals": read_signals(mdf, request)}
        else:
            raise ValueError("Unknown command '" + command + "'.")

    print(json.dumps(payload))


def create_demo(path):
    import numpy as np
    from asammdf import MDF, Signal

    time = np.linspace(0, 30, 301)
    engine_speed = 1500 + 800 * np.sin(2 * np.pi * time / 15)
    vehicle_speed = np.clip(time * 3.2, 0, 80)
    coolant_temp = 70 + 15 * (1 - np.exp(-time / 10))
    throttle = np.where(time < 10, 20, np.where(time < 20, 55, 30)).astype(float)
    signals = [
        Signal(engine_speed, time, name="EngineSpeed", unit="rpm", comment="Engine speed"),
        Signal(vehicle_speed, time, name="VehicleSpeed", unit="km/h", comment="Vehicle speed"),
        Signal(coolant_temp, time, name="CoolantTemp", unit="degC", comment="Engine coolant temperature"),
        Signal(throttle, time, name="Throttle", unit="percent", comment="Throttle pedal"),
    ]
    measurement = MDF()
    measurement.append(signals)
    measurement.save(path, overwrite=True)
    measurement.close()


def file_info(mdf, path):
    import os

    start_time = getattr(mdf.header, "start_time", None)
    start_text = "" if start_time is None else start_time.isoformat()
    channels = list_channels(mdf, "")
    last_times = [channel["EndTime"] for channel in channels]
    duration = max(last_times) if last_times else 0
    return {
        "FileName": os.path.basename(path),
        "Version": str(mdf.version),
        "StartTime": start_text,
        "DurationSeconds": float(duration),
        "GroupCount": len(mdf.groups),
        "ChannelCount": len(channels),
        "Reader": "asammdf",
    }


def list_channels(mdf, query):
    needle = query.casefold().strip()
    channels = []
    seen = set()
    for name, entries in mdf.channels_db.items():
        for group_index, channel_index in entries:
            identity = (group_index, channel_index)
            if channel_index == 0 or identity in seen:
                continue
            seen.add(identity)
            channel = mdf.groups[group_index].channels[channel_index]
            unit = as_text(getattr(channel, "unit", ""))
            comment = as_text(getattr(channel, "comment", ""))
            haystack = " ".join([name, unit, comment]).casefold()
            if needle and needle not in haystack:
                continue
            signal = mdf.get(name, group=group_index)
            timestamps = signal.timestamps
            end_time = float(timestamps[-1]) if len(timestamps) else 0
            channels.append({
                "Name": name,
                "Unit": unit,
                "Comment": comment,
                "GroupNumber": int(group_index) + 1,
                "SampleCount": int(len(signal.samples)),
                "EndTime": end_time,
            })
    channels.sort(key=lambda item: (item["Name"].casefold(), item["GroupNumber"]))
    return channels


def read_signals(mdf, request):
    selected = request.get("channels", [])
    if not selected:
        raise ValueError("Choose at least one channel to read.")

    start = request.get("start")
    stop = request.get("stop")
    max_points = int(request.get("maxPoints", 2000))
    signals = []
    for item in selected:
        name = item["name"]
        group_index = int(item["group"]) - 1
        signal = mdf.get(name, group=group_index)
        time, values = numeric_samples(signal)
        if start is not None and stop is not None:
            keep = (time >= float(start)) & (time <= float(stop))
            time = time[keep]
            values = values[keep]
        if values.size == 0:
            raise ValueError("Channel '" + name + "' has no samples in that time range.")
        finite = values[np_isfinite(values)]
        plot_time, plot_values = decimate_envelope(time, values, max_points)
        signals.append({
            "Name": name,
            "Unit": as_text(signal.unit),
            "Comment": as_text(getattr(signal, "comment", "")),
            "GroupNumber": int(item["group"]),
            "SampleCount": int(values.size),
            "Mean": float(finite.mean()) if finite.size else None,
            "Minimum": float(finite.min()) if finite.size else None,
            "Maximum": float(finite.max()) if finite.size else None,
            "StandardDeviation": float(finite.std()) if finite.size else None,
            "Time": plot_time.tolist(),
            "Value": plot_values.tolist(),
        })
    return signals


def numeric_samples(signal):
    import numpy as np

    values = np.asarray(signal.samples)
    time = np.asarray(signal.timestamps, dtype=float).ravel()
    if values.dtype.kind not in "iufb":
        raise ValueError("Channel '" + signal.name + "' is not numeric.")
    values = values.astype(float).ravel()
    count = min(time.size, values.size)
    return time[:count], values[:count]


def np_isfinite(values):
    import numpy as np

    return np.isfinite(values)


def decimate_envelope(time, values, max_points):
    import numpy as np

    if values.size <= max_points:
        return time, values

    pair_count = max(1, max_points // 2)
    edges = np.linspace(0, values.size, pair_count + 1, dtype=int)
    picked = []
    for index in range(pair_count):
        start = int(edges[index])
        stop = int(edges[index + 1])
        if stop <= start:
            continue
        segment = values[start:stop]
        local_min = start + int(np.argmin(segment))
        local_max = start + int(np.argmax(segment))
        picked.extend(sorted({local_min, local_max}))
    picked = np.array(picked, dtype=int)
    return time[picked], values[picked]


def as_text(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return str(value)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        sys.exit(1)
