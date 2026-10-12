package 'Lab Use Cases' {
    // One element per actor. These are the only actor declarations in the model.
    part Operator;
    part Administrator;
    part 'Service Technician';

    // Each use case declares one actor parameter per participating actor.
    // The parameter subsets the actor part: it names who plays the role here,
    // it does not declare a second actor.
    use case 'Acquire Image' {
        subject;
        actor operator :> Operator;
    }
    use case 'Configure Instrument' {
        subject;
        actor operator :> Operator;
        actor administrator :> Administrator;
    }
    use case 'Calibrate Instrument' {
        subject;
        actor operator :> Operator;
        actor technician :> 'Service Technician';
    }
    use case 'Manage Users' {
        subject;
        actor administrator :> Administrator;
    }
    use case 'Replace Filament' {
        subject;
        actor technician :> 'Service Technician';
        actor administrator :> Administrator;
    }

    // One connection per (actor, use case) pair, from the single actor part
    // to that use case's parameter. Operator: 3 use cases, Administrator: 3,
    // Service Technician: 2; three use cases have two actors each.
    connection 'Operator to Acquire Image'
        connect Operator to 'Acquire Image'.operator;
    connection 'Operator to Configure Instrument'
        connect Operator to 'Configure Instrument'.operator;
    connection 'Administrator to Configure Instrument'
        connect Administrator to 'Configure Instrument'.administrator;
    connection 'Operator to Calibrate Instrument'
        connect Operator to 'Calibrate Instrument'.operator;
    connection 'Service Technician to Calibrate Instrument'
        connect 'Service Technician' to 'Calibrate Instrument'.technician;
    connection 'Administrator to Manage Users'
        connect Administrator to 'Manage Users'.administrator;
    connection 'Service Technician to Replace Filament'
        connect 'Service Technician' to 'Replace Filament'.technician;
    connection 'Administrator to Replace Filament'
        connect Administrator to 'Replace Filament'.administrator;

    view 'Lab Use Cases' {
        expose Operator;
        expose Administrator;
        expose 'Service Technician';
        expose 'Acquire Image';
        expose 'Configure Instrument';
        expose 'Calibrate Instrument';
        expose 'Manage Users';
        expose 'Replace Filament';
        expose 'Operator to Acquire Image';
        expose 'Operator to Configure Instrument';
        expose 'Administrator to Configure Instrument';
        expose 'Operator to Calibrate Instrument';
        expose 'Service Technician to Calibrate Instrument';
        expose 'Administrator to Manage Users';
        expose 'Service Technician to Replace Filament';
        expose 'Administrator to Replace Filament';
        render Views::asInterconnectionDiagram;

    }
}
