function signals = measurementAsSignals(payload)
    raw = payload.signals;
    signals = repmat(signalTemplate(), 1, 0);
    if isempty(raw)
        return
    end
    if isstruct(raw)
        raw = num2cell(raw);
    end

    signals = repmat(signalTemplate(), 1, numel(raw));
    for index = 1:numel(raw)
        item = raw{index};
        signals(index).Name = string(item.Name);
        signals(index).Unit = string(item.Unit);
        signals(index).Comment = string(item.Comment);
        signals(index).GroupNumber = double(item.GroupNumber);
        signals(index).SampleCount = double(item.SampleCount);
        signals(index).Mean = double(item.Mean);
        signals(index).Minimum = double(item.Minimum);
        signals(index).Maximum = double(item.Maximum);
        signals(index).StandardDeviation = double(item.StandardDeviation);
        signals(index).Time = double(item.Time(:));
        signals(index).Value = double(item.Value(:));
    end
end

function signal = signalTemplate()
    signal = struct( ...
        "Name", "", ...
        "Unit", "", ...
        "Comment", "", ...
        "GroupNumber", 0, ...
        "SampleCount", 0, ...
        "Mean", NaN, ...
        "Minimum", NaN, ...
        "Maximum", NaN, ...
        "StandardDeviation", NaN, ...
        "Time", [], ...
        "Value", []);
end
