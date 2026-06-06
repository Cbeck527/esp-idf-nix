{
  latestByMajor = {
    "5" = "5.5.4";
    "6" = "6.0.1";
  };

  knownVersions = {
    "5.5.4" = {
      srcHash = "sha256-rItbBrwItkfJf8tKImAQsiXDR95sr0LqaM51gDZG/nI=";
      constraintsHash = "sha256-TqFUnYsDrTTi9M4xVVaDXcumPBWS9vezhqZt4ffujgQ=";
      toolsJsonPath = ./tools/v5.5.4.json;
    };
    "6.0" = {
      srcHash = "sha256-YhON/zUFOVTh8UEvujAXsd9IPaaNmSIP+dSZDE5fyqw=";
      constraintsHash = "sha256-Q9aRPdmUB/qyhV+WMl3E363RSk7qPtNqq/Nh5Z0ZQoo=";
      toolsJsonPath = ./tools/v6.0.json;
    };
    "6.0.1" = {
      srcHash = "sha256-4KJa686qc+u7XkF/GS2o53l1SpwP2EmdqAn/qmlL1yU=";
      constraintsHash = "sha256-tT7QkI0wcxKCsS7QLXDohwCVJKGn+BIdaok1vW8p4Uc=";
      toolsJsonPath = ./tools/v6.0.1.json;
    };
  };
}
