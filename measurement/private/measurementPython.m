function payload = measurementPython(command, request)
    rootFolder = measurementRoot();
    pythonExe = fullfile(rootFolder, ".venv", "bin", "python");
    scriptPath = fullfile(rootFolder, "measurement_io.py");
    if ~isfile(pythonExe)
        error("measurement:readerMissing", ...
            "The macOS measurement reader is not installed. Install asammdf into the measurement .venv.");
    end

    requestFile = tempname + ".json";
    cleanup = onCleanup(@() measurementDeleteFile(requestFile)); %#ok<NASGU>
    writer = fopen(requestFile, "w");
    fwrite(writer, jsonencode(request));
    fclose(writer);

    commandLine = measurementQuote(pythonExe) + " " + measurementQuote(scriptPath) ...
        + " " + command + " " + measurementQuote(requestFile) + " 2>&1";
    [status, output] = system(commandLine);
    output = strtrim(string(output));
    if status ~= 0
        message = output;
        try
            parsed = jsondecode(output);
            if isstruct(parsed) && isfield(parsed, "error")
                message = string(parsed.error);
            end
        catch
            % The reader returned plain text, which is already in message.
        end
        error("measurement:readFailed", "Could not read the measurement. %s", message);
    end
    payload = jsondecode(output);
end
