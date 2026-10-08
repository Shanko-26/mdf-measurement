function payload = measurementBackend(command, request)
    if ismac
        payload = measurementPython(command, request);
        return
    end
    payload = measurementNative(command, request);
end
