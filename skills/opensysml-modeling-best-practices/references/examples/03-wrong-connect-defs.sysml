package 'Connect Definitions' {
    part def Detector;
    part def 'Scanning Electron Microscope';
    connection def DetectorToMicroscope {
        end detector : Detector;
        end microscope : 'Scanning Electron Microscope';
    }
    connection 'detector to sem' : DetectorToMicroscope connect Detector to 'Scanning Electron Microscope';
}
