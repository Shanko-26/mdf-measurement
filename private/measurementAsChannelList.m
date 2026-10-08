function channels = measurementAsChannelList(payload)
    raw = payload.channels;
    channels = repmat(channelTemplate(), 1, 0);
    if isempty(raw)
        return
    end
    if isstruct(raw)
        raw = num2cell(raw);
    end

    channels = repmat(channelTemplate(), 1, numel(raw));
    for index = 1:numel(raw)
        item = raw{index};
        channels(index).Name = string(item.Name);
        channels(index).Unit = string(item.Unit);
        channels(index).Comment = string(item.Comment);
        channels(index).GroupNumber = double(item.GroupNumber);
        channels(index).SampleCount = double(item.SampleCount);
    end
end

function channel = channelTemplate()
    channel = struct( ...
        "Name", "", ...
        "Unit", "", ...
        "Comment", "", ...
        "GroupNumber", 0, ...
        "SampleCount", 0);
end
