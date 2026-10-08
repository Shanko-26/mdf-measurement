function measurementPrintRead(signals, timeRange)
    names = strjoin(string({signals.Name}), ", ");
    if all(isfinite(timeRange))
        fprintf("Read %s from %.6g s to %.6g s.\n", names, timeRange(1), timeRange(2));
        return
    end
    fprintf("Read %s for the full recording.\n", names);
end
