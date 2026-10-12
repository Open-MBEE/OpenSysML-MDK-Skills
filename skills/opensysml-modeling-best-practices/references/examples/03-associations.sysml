package Associations {
    part def 'Electron Gun';
    part def Detector;
    part def 'Scanning Electron Microscope' {
        part 'electron Gun' : 'Electron Gun';
    }

    connection def DetectorToMicroscope {
        end detector : Detector;
        end microscope : 'Scanning Electron Microscope';
    }

    part detector : Detector;
    part sem : 'Scanning Electron Microscope';
    connection 'detector to sem' : DetectorToMicroscope connect detector to sem;
}
