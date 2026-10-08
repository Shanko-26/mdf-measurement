function info = describeMeasurement(filePath)
%DESCRIBEMEASUREMENT  Summarize an MDF measurement file.
%   INFO = DESCRIBEMEASUREMENT(FILEPATH) returns the file version, start
%   time, duration, channel-group count, and channel count.
    arguments
        filePath (1,1) string
    end

    filePath = measurementResolveFile(filePath);
    info = measurementBackend("info", struct("file", filePath));
    measurementPrintInfo(info);
end
