function selected = measurementMatchChannels(catalog, channelNames)
    if isempty(catalog)
        error("measurement:noChannel", "This measurement has no channels.");
    end

    knownNames = string({catalog.Name});
    selected = repmat(struct("name", "", "group", 0), 1, numel(channelNames));
    for index = 1:numel(channelNames)
        hit = find(knownNames == channelNames(index), 1);
        if isempty(hit)
            error("measurement:unknownChannel", ...
                "Cannot find channel '%s'. Search the channel list and use the exact name.", ...
                channelNames(index));
        end
        selected(index).name = char(catalog(hit).Name);
        selected(index).group = catalog(hit).GroupNumber;
    end
end
