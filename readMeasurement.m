function signals = readMeasurement(filePath, channelNames, options)
%READMEASUREMENT  Read selected channels over an optional time range.
%   SIGNALS = READMEASUREMENT(FILEPATH, CHANNELNAMES) reads the named
%   channels. TimeRange is [start end] in seconds from the start of the
%   recording. Statistics cover every sample in the slice. Time and Value
%   are decimated for plotting.
    arguments
        filePath (1,1) string
        channelNames (1,:) string
        options.TimeRange (1,2) double = [-inf inf]
        options.MaxPoints (1,1) double {mustBePositive, mustBeInteger} = 2000
        options.Verbose (1,1) logical = true
    end

    if isempty(channelNames)
        error("measurement:noChannel", ...
            "Choose at least one channel to read.");
    end

    filePath = measurementResolveFile(filePath);
    catalog = measurementQueryChannels(filePath, "");
    selected = measurementMatchChannels(catalog, channelNames);
    request = struct( ...
        "file", filePath, ...
        "channels", selected, ...
        "maxPoints", options.MaxPoints);
    if all(isfinite(options.TimeRange))
        request.start = options.TimeRange(1);
        request.stop = options.TimeRange(2);
    end

    payload = measurementBackend("read", request);
    signals = measurementAsSignals(payload);
    if options.Verbose
        measurementPrintRead(signals, options.TimeRange);
    end
end
