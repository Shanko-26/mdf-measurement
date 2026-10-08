function filePath = measurementResolveFile(filePath)
    arguments
        filePath (1,1) string
    end

    if ~isfile(filePath)
        error("measurement:fileNotFound", ...
            "Cannot find '%s'. Choose an existing .mf4 or .mdf file.", filePath);
    end
    listing = dir(filePath);
    filePath = string(fullfile(listing(1).folder, listing(1).name));
end
