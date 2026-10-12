package 'Instrument Structure' {
    part def Detector;
    part def Stage;
    part def Microscope {
        part detector : Detector;
        part stage : Stage;
        connection 'detector to stage' connect detector to stage;
    }
    part microscope : Microscope;

    view 'Microscope Interconnection' {
        expose Microscope::**;
        render Views::asInterconnectionDiagram;
    }
}
