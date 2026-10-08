function plotMeasurement(signals)
%PLOTMEASUREMENT  Plot measurement signals in a MATLAB figure.
    arguments
        signals (1,:) struct
    end

    if isempty(signals)
        error("measurement:noSignal", ...
            "Read at least one channel before plotting it.");
    end

    fig = figure(Name="Measurement");
    measurementDraw(fig, signals);
end
