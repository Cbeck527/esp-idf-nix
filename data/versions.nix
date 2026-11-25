{
  latestByMajor = {
    "5" = "5.5.6";
    "6" = "6.1.1";
  };

  knownVersions = {
    "5.5.6" = {
      srcHash = "sha256-BmwOonYVbRkqqG8LmgxG52xlyAC3NWfBC9fNtbIDcec=";
      constraintsPath = ./constraints/v5.5.6.txt;
      toolsJsonPath = ./tools/v5.5.6.json;
    };
    "6.0.3" = {
      srcHash = "sha256-EPfmoivXCiEs3acc8ClJujCDtlePoG7kIj/mXmZtN24=";
      constraintsPath = ./constraints/v6.0.3.txt;
      toolsJsonPath = ./tools/v6.0.3.json;
    };
    "6.1.1" = {
      srcHash = "sha256-TpTA8UIAo3aWSkRosozrOepQF6lka2x5/z8NfnHF8Rc=";
      constraintsPath = ./constraints/v6.1.1.txt;
      toolsJsonPath = ./tools/v6.1.1.json;
    };
  };
}
