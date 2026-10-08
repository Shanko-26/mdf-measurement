function measurementPrintInfo(info)
    fprintf("File: %s\n", info.FileName);
    fprintf("Version: %s\n", info.Version);
    fprintf("Start: %s\n", info.StartTime);
    fprintf("Duration: %.6g s\n", info.DurationSeconds);
    fprintf("Groups: %d\n", info.GroupCount);
    fprintf("Channels: %d\n", info.ChannelCount);
    fprintf("Reader: %s\n", info.Reader);
end
