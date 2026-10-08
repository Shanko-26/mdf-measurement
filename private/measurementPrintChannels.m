function measurementPrintChannels(channels, query)
    if isempty(channels)
        if strlength(strtrim(query)) == 0
            disp("No channels in this file.");
        else
            fprintf("No channels matched '%s'.\n", query);
        end
        return
    end

    shownCount = min(30, numel(channels));
    disp(struct2table(channels(1:shownCount)));
    if numel(channels) > shownCount
        fprintf("Showing %d of %d channels.\n", shownCount, numel(channels));
    end
end
