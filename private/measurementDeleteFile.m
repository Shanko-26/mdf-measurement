function measurementDeleteFile(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end
