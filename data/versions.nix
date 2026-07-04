{
  latestByMajor = {
    "5" = "5.5.4";
    "6" = "6.0.1";
  };

  knownVersions = {
    "5.5.4" = {
      srcHash = "sha256-rItbBrwItkfJf8tKImAQsiXDR95sr0LqaM51gDZG/nI=";
      constraintsPath = ./constraints/v5.5.4.txt;
      toolsJsonPath = ./tools/v5.5.4.json;
    };
    "6.0" = {
      srcHash = "sha256-YhON/zUFOVTh8UEvujAXsd9IPaaNmSIP+dSZDE5fyqw=";
      constraintsPath = ./constraints/v6.0.txt;
      toolsJsonPath = ./tools/v6.0.json;
    };
    "6.0.1" = {
      srcHash = "sha256-4KJa686qc+u7XkF/GS2o53l1SpwP2EmdqAn/qmlL1yU=";
      constraintsPath = ./constraints/v6.0.1.txt;
      toolsJsonPath = ./tools/v6.0.1.json;
    };
  };
}
