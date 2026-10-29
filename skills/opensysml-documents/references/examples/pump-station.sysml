package PumpStation {
    private import ScalarValues::*;
    private import DiagramLayout::*;

    port def FluidPort { out rate : Real; }
    port def PowerPort { in watts : Real; }

    part def Tank { port outlet : FluidPort; }
    part def Pump { port inlet : ~FluidPort; port power : PowerPort; }
    part def Supply { port feed : ~PowerPort; }

    part station {
        part tank : Tank;
        part pump : Pump;
        part supply : Supply;
        connection fluid connect tank.outlet to pump.inlet;
        connection mains connect supply.feed to pump.power;
    }

    view def Interconnection {
        render Views::asInterconnectionDiagram;
    }

    view stationView : Interconnection {
        expose PumpStation::station::**;
        metadata Layout about station { x = 40; y = 40; width = 520; height = 360; }
        metadata Layout about station::tank { x = 80; y = 160; width = 120; height = 80; }
        metadata Layout about station::pump { x = 320; y = 160; width = 120; height = 80; }
        metadata Layout about station::supply { x = 80; y = 300; width = 120; height = 60; }
    }
}
