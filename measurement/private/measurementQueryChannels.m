function channels = measurementQueryChannels(filePath, query)
    arguments
        filePath (1,1) string
        query (1,1) string = ""
    end

    filePath = measurementResolveFile(filePath);
    request = struct("file", filePath, "query", query);
    payload = measurementBackend("channels", request);
    channels = measurementAsChannelList(payload);
end
