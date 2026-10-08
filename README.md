# MDF measurement

A MATLAB app for opening an MF4 or MDF recording, searching its channels, and plotting a time slice. The same functions can be called from an agent connected to MATLAB, such as Cursor through the MATLAB MCP server.

## Open the app

In MATLAB, with this folder on the path:

```matlab
addpath(fullfile(pwd, "measurement"));
measurementApp
```

`measurementApp` opens `measurement/sample_drive.mf4`. Pass another file path to open that recording instead.

Browse to a file, search channels by name, unit, or comment, set a start and end time, and press **Plot selection**. **Show cursors** adds two cursors and a table of values and deltas. Zoom or pan to re-read the visible window. Statistics stay on the slice you plotted. **Reset view** returns to that slice.

## Chat from an agent

Connect an agent to the same MATLAB session with the [MATLAB MCP server](https://github.com/matlab/matlab-mcp-server). The agent can call:

```matlab
describeMeasurement("measurement/sample_drive.mf4")
findMeasurementChannels("measurement/sample_drive.mf4", "temp")
signals = readMeasurement("measurement/sample_drive.mf4", ...
    ["EngineSpeed", "CoolantTemp"], TimeRange=[0 10]);
summarizeMeasurement(signals)
plotMeasurement(signals)
```

Search before reading. A vehicle log can contain thousands of channels, and the plot is meant for a few of them.

## Reading files

On Windows and Linux, reads use MATLAB `mdfInfo`, `mdfChannelInfo`, and `mdfRead`.

On macOS those functions do not run. The app uses the Python helper in `measurement/measurement_io.py` and [asammdf](https://github.com/danielhrisca/asammdf):

```bash
python3 -m venv measurement/.venv
measurement/.venv/bin/pip install -r measurement/requirements.txt
```

The virtual environment is not part of this repository.
