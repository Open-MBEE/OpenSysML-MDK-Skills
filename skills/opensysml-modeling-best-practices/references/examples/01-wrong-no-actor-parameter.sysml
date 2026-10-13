package 'Actor-less Use Case' {
    /* «actor» */
    part Operator;

    use case 'Acquire Image' {
        subject;
    }

    connection 'Operator to Acquire Image' connect Operator to 'Acquire Image';

    view 'Actor-less Diagram' {
        expose Operator;
        expose 'Acquire Image';
        expose 'Operator to Acquire Image';
        render Views::asInterconnectionDiagram;
    }
}
