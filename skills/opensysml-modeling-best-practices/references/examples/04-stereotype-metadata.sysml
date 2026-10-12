package Stereotypes {
    private import ScalarValues::String;

    // A profile stereotype with no v2 counterpart becomes a metadata definition
    // and is applied with the user-defined keyword `#Subsystem`.
    metadata def Subsystem;

    // A stereotype whose only payload is its name is recorded as data, not prose.
    metadata def AppliedStereotype {
        attribute stereotype : String;
        attribute profile : String[0..1];
    }

    #Subsystem part def 'Vacuum System';
    part def 'Electron Column';

    part def Controller;
    part def Stage;
    dependency 'Controller traces Stage' from Controller to Stage {
        @AppliedStereotype { stereotype = "Trace"; profile = "SysML"; }
    }

    view 'Subsystems only' {
        expose Stereotypes::*[@Subsystem];
        render Views::asTreeDiagram;
    }
}
