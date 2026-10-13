package 'Stereotype as Comment' {
    /* «Subsystem» */
    part def 'Vacuum System';
    part def 'Electron Column';

    view 'Subsystems only' {
        // Nothing is annotated, so the filter keeps nothing.
        expose 'Stereotype as Comment'::*[@Stereotypes::Subsystem];
        render Views::asTreeDiagram;
    }
}
