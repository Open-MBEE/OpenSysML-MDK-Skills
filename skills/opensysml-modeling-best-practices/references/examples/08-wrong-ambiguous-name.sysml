package Definitions {
    part def Detector;
}
package Usages {
    part Detector : Definitions::Detector;
}
package 'Ambiguous View' {
    private import Definitions::*;
    private import Usages::*;
    view 'Detector View' {
        // Both packages are imported: which `Detector` is meant?
        expose Detector;
        render Views::asTreeDiagram;
    }
}
