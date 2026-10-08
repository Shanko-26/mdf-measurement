function rootFolder = measurementRoot()
    rootFolder = string(fileparts(fileparts(mfilename("fullpath"))));
end
