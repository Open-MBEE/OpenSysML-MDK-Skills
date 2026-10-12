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
        // Optional geometry: OpenSysML's DiagramLayout library, not standard SysML v2.
        @DiagramLayout::Canvas { unit = "px"; width = 320; height = 120; }
        metadata DiagramLayout::Layout about Microscope::detector { x = 20; y = 40; width = 120; height = 40; }
        metadata DiagramLayout::Layout about Microscope::stage { x = 180; y = 40; width = 120; height = 40; }
        metadata DiagramLayout::Route about Microscope::'detector to stage' { points = (140, 60, 180, 60); }
        render Views::asInterconnectionDiagram;
    }
}
