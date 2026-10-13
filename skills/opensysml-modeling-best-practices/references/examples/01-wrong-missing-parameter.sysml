package 'Missing Actor Parameter' {
    part Operator;
    use case 'Acquire Image' { subject; }
    connection 'Operator to Acquire Image' connect Operator to 'Acquire Image'.operator;
}
