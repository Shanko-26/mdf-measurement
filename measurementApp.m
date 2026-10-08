function measurementApp(filePath)
%MEASUREMENTAPP  Open, search, slice, and plot an MDF measurement.
%   MEASUREMENTAPP opens the sample drive. MEASUREMENTAPP(FILEPATH) opens
%   that .mf4 or .mdf file. Check Show cursors to measure values. Zoom
%   re-reads the visible window. Statistics stay on the plotted slice.
    arguments
        filePath (1,1) string = fullfile(measurementRoot(), "sample_drive.mf4")
    end

    fig = uifigure(Name="Measurement", Position=[80 60 1120 780], ...
        WindowButtonDownFcn=@onPress, ...
        WindowButtonMotionFcn=@onDrag, ...
        WindowButtonUpFcn=@onRelease, ...
        CloseRequestFcn=@onClose);
    root = uigridlayout(fig, [1 2], ...
        ColumnWidth={340, '1x'}, ...
        Padding=[12 12 12 12], ...
        ColumnSpacing=12);

    left = uigridlayout(root, [8 1], ...
        RowHeight={'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit', 'fit'}, ...
        Padding=[0 0 0 0], ...
        RowSpacing=8);
    fileRow = uigridlayout(left, [1 2], ...
        ColumnWidth={'1x', 88}, ...
        Padding=[0 0 0 0], ...
        ColumnSpacing=8);
    pathField = uieditfield(fileRow, "text");
    uibutton(fileRow, Text="Browse", ButtonPushedFcn=@onBrowse);

    infoLabel = uilabel(left, Text="Open an MDF file.", WordWrap="on");
    uilabel(left, Text="Search channels");
    searchField = uieditfield(left, "text", ...
        Placeholder="Name, unit, or comment", ...
        ValueChangedFcn=@onSearch);
    channelList = uilistbox(left, Multiselect="on");

    timeRow = uigridlayout(left, [2 2], ...
        RowHeight={'fit', 'fit'}, ...
        Padding=[0 0 0 0], ...
        ColumnSpacing=8, ...
        RowSpacing=6);
    uilabel(timeRow, Text="Start (s)");
    startField = uieditfield(timeRow, "numeric", Value=0);
    uilabel(timeRow, Text="End (s)");
    endField = uieditfield(timeRow, "numeric", Value=0);
    actionRow = uigridlayout(left, [1 2], ...
        ColumnWidth={'1x', '1x'}, ...
        Padding=[0 0 0 0], ...
        ColumnSpacing=8);
    uibutton(actionRow, Text="Plot selection", ButtonPushedFcn=@onPlot);
    uibutton(actionRow, Text="Reset view", ButtonPushedFcn=@onResetView);
    cursorCheck = uicheckbox(left, ...
        Text="Show cursors", ...
        Value=false, ...
        ValueChangedFcn=@onToggleCursors);

    right = uigridlayout(root, [4 1], ...
        RowHeight={'1x', 'fit', 124, 150}, ...
        Padding=[0 0 0 0], ...
        RowSpacing=8);
    plotPanel = uipanel(right, BorderType="none");
    viewLabel = uilabel(right, Text="Plot a slice to measure it.", WordWrap="on");
    cursorTable = uitable(right, Visible="off");
    statsTable = uitable(right);

    fig.UserData = struct( ...
        "PathField", pathField, ...
        "InfoLabel", infoLabel, ...
        "SearchField", searchField, ...
        "ChannelList", channelList, ...
        "StartField", startField, ...
        "EndField", endField, ...
        "PlotPanel", plotPanel, ...
        "RightLayout", right, ...
        "ViewLabel", viewLabel, ...
        "CursorCheck", cursorCheck, ...
        "CursorTable", cursorTable, ...
        "StatsTable", statsTable, ...
        "Channels", struct([]), ...
        "OverviewSignals", emptySignals(), ...
        "ViewSignals", emptySignals(), ...
        "Axes", gobjects(0, 1), ...
        "SliceRange", [0, 0], ...
        "ShownRange", [0, 0], ...
        "ShowCursors", false, ...
        "CursorA", NaN, ...
        "CursorB", NaN, ...
        "DragCursor", "", ...
        "SuspendView", false, ...
        "ViewTimer", timer.empty, ...
        "ViewText", "");
    applyCursorVisibility(fig);

    if isfile(filePath)
        pathField.Value = char(filePath);
        loadFile(fig);
    end
end

function onBrowse(src, ~)
    fig = ancestor(src, "figure");
    [fileName, folder] = uigetfile( ...
        {"*.mf4;*.mdf", "MDF files"}, ...
        "Open measurement");
    if isequal(fileName, 0)
        return
    end
    fig.UserData.PathField.Value = fullfile(folder, fileName);
    loadFile(fig);
end

function onSearch(src, ~)
    fig = ancestor(src, "figure");
    showChannels(fig, string(src.Value));
end

function onPlot(src, ~)
    fig = ancestor(src, "figure");
    state = fig.UserData;
    filePath = string(state.PathField.Value);
    channelNames = selectedNames(state.ChannelList);
    if strlength(filePath) == 0 || ~isfile(filePath)
        uialert(fig, "Choose an existing MDF file.", "Measurement");
        return
    end
    if isempty(channelNames)
        uialert(fig, "Select at least one channel.", "Measurement");
        return
    end

    timeRange = [state.StartField.Value, state.EndField.Value];
    if timeRange(2) < timeRange(1)
        uialert(fig, "The end time must be at or after the start time.", "Measurement");
        return
    end
    try
        signals = readMeasurement(filePath, channelNames, ...
            TimeRange=timeRange, ...
            Verbose=false);
    catch err
        uialert(fig, err.message, "Measurement");
        return
    end
    showSlice(fig, signals, timeRange);
end

function onResetView(src, ~)
    fig = ancestor(src, "figure");
    state = fig.UserData;
    if isempty(state.OverviewSignals)
        return
    end
    state.SuspendView = true;
    fig.UserData = state;
    presentView(fig, state.OverviewSignals, state.SliceRange);
end

function loadFile(fig)
    state = fig.UserData;
    filePath = string(state.PathField.Value);
    try
        info = describeMeasurement(filePath);
        channels = findMeasurementChannels(filePath, "");
    catch err
        uialert(fig, err.message, "Measurement");
        return
    end

    state = fig.UserData;
    state.Channels = channels;
    state.InfoLabel.Text = sprintf( ...
        "%s\nVersion %s, %.3g s, %d groups, %d channels\nReader: %s", ...
        info.FileName, info.Version, info.DurationSeconds, ...
        info.GroupCount, info.ChannelCount, info.Reader);
    state.StartField.Value = 0;
    state.EndField.Value = info.DurationSeconds;
    state.SearchField.Value = "";
    fig.UserData = state;
    showChannels(fig, "");

    picked = selectedNames(state.ChannelList);
    if isempty(picked)
        return
    end
    try
        signals = readMeasurement(filePath, picked, ...
            TimeRange=[0, info.DurationSeconds], ...
            Verbose=false);
        showSlice(fig, signals, [0, info.DurationSeconds]);
    catch err
        uialert(fig, err.message, "Measurement");
    end
end

function showSlice(fig, signals, timeRange)
    state = fig.UserData;
    state.OverviewSignals = signals;
    state.SliceRange = timeRange;
    state.CursorA = timeRange(1) + 0.25 * diff(timeRange);
    state.CursorB = timeRange(1) + 0.75 * diff(timeRange);
    state.StatsTable.Data = summarizeMeasurement(signals);
    fig.UserData = state;
    presentView(fig, signals, timeRange);
end

function presentView(fig, signals, viewRange)
    state = fig.UserData;
    state.SuspendView = true;
    state.ViewSignals = signals;
    state.ShownRange = viewRange;
    fig.UserData = state;

    targetAxes = measurementDraw(state.PlotPanel, signals);
    if ~isempty(targetAxes)
        if numel(targetAxes) > 1
            linkaxes(targetAxes, "x");
        end
        xlim(targetAxes(1), viewRange);
        listenForZoom(fig, targetAxes);
    end

    state = fig.UserData;
    state.Axes = targetAxes;
    state.SuspendView = false;
    fig.UserData = state;
    updateViewLabel(fig, viewRange, signals);
    updateCursors(fig);
end

function listenForZoom(fig, targetAxes)
    for index = 1:numel(targetAxes)
        addlistener(targetAxes(index), "XLim", "PostSet", @(~, ~) onViewChanged(fig));
    end
end

function onViewChanged(fig)
    if ~isvalid(fig)
        return
    end
    state = fig.UserData;
    if state.SuspendView || isempty(state.Axes) || ~isvalid(state.Axes(1))
        return
    end
    if isempty(state.ViewTimer) || ~isvalid(state.ViewTimer)
        state.ViewTimer = timer( ...
            StartDelay=0.35, ...
            TimerFcn=@(~, ~) applyView(fig), ...
            ExecutionMode="singleShot", ...
            Tag="measurementView");
        fig.UserData = state;
    end
    stop(state.ViewTimer);
    start(state.ViewTimer);
end

function applyView(fig)
    if ~isvalid(fig)
        return
    end
    state = fig.UserData;
    if state.SuspendView || isempty(state.OverviewSignals) || isempty(state.Axes)
        return
    end
    if ~isvalid(state.Axes(1))
        return
    end

    viewRange = xlim(state.Axes(1));
    if diff(viewRange) <= 0
        return
    end
    if rangesMatch(viewRange, state.ShownRange)
        return
    end
    if rangesMatch(viewRange, state.SliceRange)
        presentView(fig, state.OverviewSignals, state.SliceRange);
        return
    end

    try
        if hasFullResolution(state.OverviewSignals)
            viewSignals = sliceSignals(state.OverviewSignals, viewRange);
        else
            state.ViewLabel.Text = "Reading the visible window...";
            drawnow;
            viewSignals = rereadWindow(state, viewRange);
        end
    catch err
        uialert(fig, err.message, "Measurement");
        return
    end
    keepCursorsInRange(fig, viewRange);
    presentView(fig, viewSignals, viewRange);
end

function viewSignals = rereadWindow(state, viewRange)
    filePath = string(state.PathField.Value);
    channelNames = string({state.OverviewSignals.Name});
    fresh = readMeasurement(filePath, channelNames, ...
        TimeRange=viewRange, ...
        MaxPoints=50000, ...
        Verbose=false);
    viewSignals = state.OverviewSignals;
    for index = 1:numel(viewSignals)
        match = find(string({fresh.Name}) == viewSignals(index).Name, 1);
        viewSignals(index).Time = fresh(match).Time;
        viewSignals(index).Value = fresh(match).Value;
        viewSignals(index).SampleCount = fresh(match).SampleCount;
    end
end

function keepCursorsInRange(fig, viewRange)
    state = fig.UserData;
    if ~isfinite(state.CursorA) || state.CursorA < viewRange(1) || state.CursorA > viewRange(2)
        state.CursorA = viewRange(1) + 0.25 * diff(viewRange);
    end
    if ~isfinite(state.CursorB) || state.CursorB < viewRange(1) || state.CursorB > viewRange(2)
        state.CursorB = viewRange(1) + 0.75 * diff(viewRange);
    end
    fig.UserData = state;
end

function onToggleCursors(src, ~)
    fig = ancestor(src, "figure");
    state = fig.UserData;
    state.ShowCursors = logical(src.Value);
    state.DragCursor = "";
    if state.ShowCursors && ~isempty(state.ViewSignals)
        viewRange = state.ShownRange;
        if ~all(isfinite([state.CursorA, state.CursorB]))
            state.CursorA = viewRange(1) + 0.25 * diff(viewRange);
            state.CursorB = viewRange(1) + 0.75 * diff(viewRange);
        end
    end
    fig.UserData = state;
    applyCursorVisibility(fig);
    updateCursors(fig);
end

function onPress(fig, ~)
    state = fig.UserData;
    if ~state.ShowCursors || isempty(state.Axes) || ~all(isvalid(state.Axes))
        return
    end
    hit = hittest(fig);
    if isempty(hit)
        return
    end
    if isprop(hit, "Tag") && ismember(string(hit.Tag), ["cursorA", "cursorB"])
        state.DragCursor = string(hit.Tag);
        fig.UserData = state;
        return
    end
    targetAxes = ancestor(hit, "axes");
    if isempty(targetAxes)
        return
    end
    timeAtPointer = targetAxes.CurrentPoint(1, 1);
    grabSpan = cursorGrabSpan(targetAxes);
    distanceA = abs(timeAtPointer - state.CursorA);
    distanceB = abs(timeAtPointer - state.CursorB);
    if distanceA > grabSpan && distanceB > grabSpan
        return
    end
    if distanceA <= distanceB
        state.DragCursor = "cursorA";
    else
        state.DragCursor = "cursorB";
    end
    fig.UserData = state;
end

function onDrag(fig, ~)
    state = fig.UserData;
    if ~state.ShowCursors || strlength(state.DragCursor) == 0 || isempty(state.Axes) || ~isvalid(state.Axes(1))
        return
    end
    hit = hittest(fig);
    targetAxes = ancestor(hit, "axes");
    if isempty(targetAxes)
        targetAxes = state.Axes(1);
    end
    timeAtPointer = targetAxes.CurrentPoint(1, 1);
    limits = xlim(state.Axes(1));
    timeAtPointer = min(max(timeAtPointer, limits(1)), limits(2));
    if state.DragCursor == "cursorA"
        state.CursorA = timeAtPointer;
    else
        state.CursorB = timeAtPointer;
    end
    fig.UserData = state;
    updateCursors(fig);
end

function onRelease(fig, ~)
    if isvalid(fig)
        fig.UserData.DragCursor = "";
    end
end

function applyCursorVisibility(fig)
    state = fig.UserData;
    if state.ShowCursors
        state.RightLayout.RowHeight = {'1x', 'fit', 124, 150};
        state.CursorTable.Visible = "on";
        return
    end
    state.RightLayout.RowHeight = {'1x', 'fit', 0, 150};
    state.CursorTable.Visible = "off";
    state.CursorTable.Data = [];
end

function updateCursors(fig)
    state = fig.UserData;
    signals = state.ViewSignals;
    if isempty(signals) || isempty(state.Axes)
        return
    end
    for index = 1:numel(state.Axes)
        targetAxes = state.Axes(index);
        if isvalid(targetAxes)
            delete(findall(targetAxes, "Type", "constantline"));
        end
    end
    if ~state.ShowCursors
        fig.UserData.ViewLabel.Text = state.ViewText;
        return
    end
    for index = 1:numel(state.Axes)
        targetAxes = state.Axes(index);
        if ~isvalid(targetAxes)
            continue
        end
        delete(findall(targetAxes, "Type", "constantline"));
        lineA = xline(targetAxes, state.CursorA, ...
            Color=[0.00 0.45 0.74], ...
            LineWidth=1.4, ...
            Label=cursorText(index, "A"), ...
            LabelVerticalAlignment="middle", ...
            LabelHorizontalAlignment="left", ...
            FontWeight="bold");
        lineB = xline(targetAxes, state.CursorB, ...
            Color=[0.85 0.33 0.10], ...
            LineWidth=1.4, ...
            Label=cursorText(index, "B"), ...
            LabelVerticalAlignment="middle", ...
            LabelHorizontalAlignment="right", ...
            FontWeight="bold");
        lineA.Tag = "cursorA";
        lineB.Tag = "cursorB";
    end

    cursorA = zeros(numel(signals), 1);
    cursorB = zeros(numel(signals), 1);
    for index = 1:numel(signals)
        cursorA(index) = valueAt(signals(index), state.CursorA);
        cursorB(index) = valueAt(signals(index), state.CursorB);
    end
    state.CursorTable.Data = table( ...
        string({signals.Name})', ...
        cursorA, ...
        cursorB, ...
        shownDelta(cursorA, cursorB), ...
        VariableNames=["Channel", "A", "B", "Delta"]);
    fig.UserData.ViewLabel.Text = state.ViewText + sprintf( ...
        "\nA %.4g s   B %.4g s   dt %.4g s", ...
        state.CursorA, state.CursorB, state.CursorB - state.CursorA);
end

function updateViewLabel(fig, viewRange, signals)
    state = fig.UserData;
    sampleCount = max(arrayfun(@(signal) signal.SampleCount, signals));
    shownCount = max(arrayfun(@(signal) numel(signal.Time), signals));
    if shownCount < sampleCount
        detail = sprintf("%d of %d samples in view", shownCount, sampleCount);
    else
        detail = sprintf("all %d samples in view", shownCount);
    end
    state.ViewText = sprintf( ...
        "Slice %.4g–%.4g s · view %.4g–%.4g s · %s · statistics stay on the slice", ...
        state.SliceRange(1), state.SliceRange(2), viewRange(1), viewRange(2), detail);
    state.ViewLabel.Text = state.ViewText;
    fig.UserData = state;
end

function showChannels(fig, query)
    state = fig.UserData;
    channels = state.Channels;
    if isempty(channels)
        state.ChannelList.Items = {};
        state.ChannelList.ItemsData = {};
        return
    end

    if strlength(strtrim(query)) > 0
        haystack = lower(string({channels.Name}) + " " + string({channels.Unit}) ...
            + " " + string({channels.Comment}));
        channels = channels(contains(haystack, lower(strtrim(query))));
    end
    if isempty(channels)
        state.ChannelList.Items = {};
        state.ChannelList.ItemsData = {};
        return
    end

    labels = strings(numel(channels), 1);
    values = strings(numel(channels), 1);
    for index = 1:numel(channels)
        labels(index) = channels(index).Name + " (" + channels(index).Unit + ")";
        values(index) = channels(index).Name + "||" + channels(index).GroupNumber;
    end
    state.ChannelList.Items = cellstr(labels);
    state.ChannelList.ItemsData = cellstr(values);
    pickCount = min(3, numel(values));
    state.ChannelList.Value = cellstr(values(1:pickCount));
end

function names = selectedNames(channelList)
    selected = string(channelList.Value);
    selected = selected(:);
    selected = selected(strlength(selected) > 0);
    names = strings(1, numel(selected));
    for index = 1:numel(selected)
        parts = split(selected(index), "||");
        names(index) = parts(1);
    end
end

function signals = sliceSignals(signals, viewRange)
    for index = 1:numel(signals)
        timeValue = signals(index).Time(:);
        sampleValue = signals(index).Value(:);
        inside = find(timeValue >= viewRange(1) & timeValue <= viewRange(2));
        if isempty(inside)
            [~, nearest] = min(abs(timeValue - mean(viewRange)));
            inside = nearest;
        else
            first = max(1, inside(1) - 1);
            last = min(numel(timeValue), inside(end) + 1);
            inside = first:last;
        end
        signals(index).Time = timeValue(inside);
        signals(index).Value = sampleValue(inside);
        signals(index).SampleCount = numel(inside);
    end
end

function full = hasFullResolution(signals)
    full = true;
    for index = 1:numel(signals)
        if signals(index).SampleCount > numel(signals(index).Time)
            full = false;
            return
        end
    end
end

function shown = shownDelta(leftValue, rightValue)
    shown = rightValue - leftValue;
    span = max(1, max(abs(leftValue), abs(rightValue)));
    shown(abs(shown) <= 1e-8 .* span) = 0;
end

function sample = valueAt(signal, cursorTime)
    sampleTimes = signal.Time(:);
    if isempty(sampleTimes)
        sample = NaN;
        return
    end
    [gap, index] = min(abs(sampleTimes - cursorTime));
    step = 0;
    if numel(sampleTimes) > 1
        step = median(abs(diff(sampleTimes)));
    end
    if gap > max(1e-6, 2 * step)
        sample = NaN;
        return
    end
    sample = signal.Value(index);
end

function span = cursorGrabSpan(targetAxes)
    pixelBox = getpixelposition(targetAxes, true);
    width = pixelBox(3);
    if width < 1
        span = 0.01 * diff(xlim(targetAxes));
        return
    end
    span = 8 / width * diff(xlim(targetAxes));
end

function text = cursorText(index, name)
    if index == 1
        text = name;
        return
    end
    text = "";
end

function signals = emptySignals()
    signals = struct( ...
        "Name", {}, ...
        "Unit", {}, ...
        "Comment", {}, ...
        "GroupNumber", {}, ...
        "SampleCount", {}, ...
        "Mean", {}, ...
        "Minimum", {}, ...
        "Maximum", {}, ...
        "StandardDeviation", {}, ...
        "Time", {}, ...
        "Value", {});
end

function matched = rangesMatch(firstRange, secondRange)
    width = max(diff(secondRange), 1e-9);
    matched = all(abs(firstRange - secondRange) <= 0.002 * width);
end

function onClose(fig, ~)
    if isvalid(fig) && isstruct(fig.UserData) && isfield(fig.UserData, "ViewTimer")
        viewTimer = fig.UserData.ViewTimer;
        if ~isempty(viewTimer) && isvalid(viewTimer)
            stop(viewTimer);
            delete(viewTimer);
        end
    end
    delete(fig);
end
