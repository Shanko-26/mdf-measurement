function payload = measurementNative(command, request)
    switch command
        case "info"
            payload = nativeInfo(request);
        case "channels"
            payload = struct("channels", nativeChannels(request));
        case "read"
            payload = struct("signals", nativeRead(request));
        otherwise
            error("measurement:command", "Unknown measurement command '%s'.", command);
    end
end

function info = nativeInfo(request)
    fileInfo = mdfInfo(request.file);
    groups = mdfChannelGroupInfo(request.file);
    channels = nativeChannels(request);
    info = struct( ...
        "FileName", string(fileInfo.Name), ...
        "Version", string(fileInfo.Version), ...
        "StartTime", string(fileInfo.InitialTimestamp), ...
        "DurationSeconds", nativeDuration(request.file, groups), ...
        "GroupCount", double(fileInfo.ChannelGroupCount), ...
        "ChannelCount", numel(channels), ...
        "Reader", "matlab");
end

function channels = nativeChannels(request)
    channelTable = mdfChannelInfo(request.file);
    query = "";
    if isfield(request, "query")
        query = string(request.query);
    end

    names = string(channelTable.Name);
    units = tableText(channelTable, "Unit", numel(names));
    comments = tableText(channelTable, "Comment", numel(names));
    groups = tableNumber(channelTable, "GroupNumber", numel(names));
    sampleCounts = tableNumber(channelTable, "GroupNumSamples", numel(names));

    keep = true(numel(names), 1);
    needle = lower(strtrim(query));
    if strlength(needle) > 0
        haystack = lower(names + " " + units + " " + comments);
        keep = contains(haystack, needle);
    end

    names = names(keep);
    units = units(keep);
    comments = comments(keep);
    groups = groups(keep);
    sampleCounts = sampleCounts(keep);
    channels = repmat(struct( ...
        "Name", "", "Unit", "", "Comment", "", "GroupNumber", 0, "SampleCount", 0), ...
        1, numel(names));
    for index = 1:numel(names)
        channels(index).Name = names(index);
        channels(index).Unit = units(index);
        channels(index).Comment = comments(index);
        channels(index).GroupNumber = groups(index);
        channels(index).SampleCount = sampleCounts(index);
    end
end

function signals = nativeRead(request)
    channelNames = strings(1, numel(request.channels));
    for index = 1:numel(request.channels)
        channelNames(index) = string(request.channels(index).name);
    end

    if isfield(request, "start") && all(isfinite([request.start, request.stop]))
        groups = mdfRead(request.file, ...
            Channel=channelNames, ...
            TimeRange=seconds([request.start, request.stop]));
    else
        groups = mdfRead(request.file, Channel=channelNames);
    end

    catalog = nativeChannels(struct("file", request.file, "query", ""));
    maxPoints = 2000;
    if isfield(request, "maxPoints")
        maxPoints = double(request.maxPoints);
    end

    signalCount = 0;
    for groupIndex = 1:numel(groups)
        groupData = groups{groupIndex};
        if ~isempty(groupData) && height(groupData) > 0
            signalCount = signalCount + width(groupData);
        end
    end
    signals = repmat(struct( ...
        "Name", "", "Unit", "", "Comment", "", "GroupNumber", 0, ...
        "SampleCount", 0, "Mean", NaN, "Minimum", NaN, "Maximum", NaN, ...
        "StandardDeviation", NaN, "Time", [], "Value", []), 1, signalCount);
    cursor = 0;
    for groupIndex = 1:numel(groups)
        groupData = groups{groupIndex};
        if isempty(groupData) || height(groupData) == 0
            continue
        end
        columnNames = string(groupData.Properties.VariableNames);
        rowTime = seconds(groupData.Properties.RowTimes);
        for columnIndex = 1:numel(columnNames)
            values = double(groupData.(columnNames(columnIndex)));
            [plotTime, plotValues] = measurementDecimate(rowTime, values, maxPoints);
            finiteValues = values(isfinite(values));
            cursor = cursor + 1;
            signals(cursor) = struct( ...
                "Name", columnNames(columnIndex), ...
                "Unit", catalogValue(catalog, columnNames(columnIndex), "Unit"), ...
                "Comment", catalogValue(catalog, columnNames(columnIndex), "Comment"), ...
                "GroupNumber", catalogValue(catalog, columnNames(columnIndex), "GroupNumber"), ...
                "SampleCount", numel(values), ...
                "Mean", mean(finiteValues, "omitnan"), ...
                "Minimum", min(finiteValues), ...
                "Maximum", max(finiteValues), ...
                "StandardDeviation", std(finiteValues), ...
                "Time", plotTime, ...
                "Value", plotValues);
        end
    end

    if isempty(signals)
        error("measurement:noSample", ...
            "The selected channels have no samples in that time range.");
    end
end

function durationSeconds = nativeDuration(filePath, groups)
    durationSeconds = NaN;
    if ~ismember("NumSamples", groups.Properties.VariableNames)
        return
    end
    sampleCounts = double(groups.NumSamples);
    groupNumbers = double(groups.ChannelGroupNumber);
    [~, richest] = max(sampleCounts);
    if sampleCounts(richest) < 1
        durationSeconds = 0;
        return
    end
    lastPoint = mdfRead(filePath, ...
        GroupNumber=groupNumbers(richest), ...
        IndexRange=[sampleCounts(richest), sampleCounts(richest)]);
    rowTime = seconds(lastPoint{1}.Properties.RowTimes);
    durationSeconds = double(rowTime(end));
end

function text = tableText(channelTable, variableName, count)
    text = strings(count, 1);
    if ~ismember(variableName, channelTable.Properties.VariableNames)
        return
    end
    text = string(channelTable.(variableName));
end

function numbers = tableNumber(channelTable, variableName, count)
    numbers = zeros(count, 1);
    if ~ismember(variableName, channelTable.Properties.VariableNames)
        return
    end
    numbers = double(channelTable.(variableName));
end

function value = catalogValue(catalog, channelName, fieldName)
    names = string({catalog.Name});
    hit = find(names == channelName, 1);
    if isempty(hit)
        value = "";
        return
    end
    value = catalog(hit).(fieldName);
end
