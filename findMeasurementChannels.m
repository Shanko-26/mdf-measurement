function channels = findMeasurementChannels(filePath, query)
%FINDMEASUREMENTCHANNELS  Find channels by name, unit, or comment.
%   CHANNELS = FINDMEASUREMENTCHANNELS(FILEPATH, QUERY) returns a struct
%   array. QUERY is optional and matches case-insensitively.
    arguments
        filePath (1,1) string
        query (1,1) string = ""
    end

    channels = measurementQueryChannels(filePath, query);
    measurementPrintChannels(channels, query);
end
