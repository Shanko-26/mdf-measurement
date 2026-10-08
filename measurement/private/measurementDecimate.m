function [timeOut, valueOut] = measurementDecimate(timeValue, sampleValue, maxPoints)
    timeValue = double(timeValue(:));
    sampleValue = double(sampleValue(:));
    count = min(numel(timeValue), numel(sampleValue));
    timeValue = timeValue(1:count);
    sampleValue = sampleValue(1:count);
    if count <= maxPoints
        timeOut = timeValue;
        valueOut = sampleValue;
        return
    end

    pairCount = max(1, floor(maxPoints / 2));
    edges = round(linspace(1, count + 1, pairCount + 1));
    picked = zeros(1, pairCount * 2);
    used = 0;
    for index = 1:pairCount
        startIndex = edges(index);
        stopIndex = edges(index + 1) - 1;
        if stopIndex < startIndex
            continue
        end
        segment = sampleValue(startIndex:stopIndex);
        [~, localMin] = min(segment);
        [~, localMax] = max(segment);
        chosen = unique([startIndex + localMin - 1, startIndex + localMax - 1]);
        picked(used + (1:numel(chosen))) = chosen;
        used = used + numel(chosen);
    end
    picked = sort(picked(1:used));
    timeOut = timeValue(picked);
    valueOut = sampleValue(picked);
end
