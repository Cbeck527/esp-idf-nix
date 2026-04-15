{
  latestByMajor = {
    "5" = "5.5.4";
    "6" = "6.0";
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
  };
}
