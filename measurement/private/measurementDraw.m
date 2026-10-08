function targetAxes = measurementDraw(parent, signals)
    delete(findall(parent, "-depth", 1, "Type", "tiledlayout"));
    delete(findall(parent, "-depth", 1, "Type", "axes"));
    targetAxes = gobjects(0, 1);
    if isempty(signals)
        return
    end

    layout = tiledlayout(parent, numel(signals), 1, ...
        Padding="compact", ...
        TileSpacing="compact");
    targetAxes = gobjects(numel(signals), 1);
    for index = 1:numel(signals)
        targetAxes(index) = nexttile(layout);
        plot(targetAxes(index), signals(index).Time(:), signals(index).Value(:), ...
            LineWidth=1.25);
        grid(targetAxes(index), "on");
        title(targetAxes(index), signals(index).Name);
        ylabel(targetAxes(index), signals(index).Unit);
        if index == numel(signals)
            xlabel(targetAxes(index), "Time (s)");
        end
    end
    if numel(targetAxes) > 1
        linkaxes(targetAxes, "x");
    end
end
