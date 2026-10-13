package 'Constraint Without Result' {
    private import ISQ::*;
    private import SI::*;

    // The expression is in a nested calc nobody evaluates; the constraint itself
    // has no result expression, so asserting it asserts nothing.
    constraint def 'Positive Mass' {
        in m : MassValue;
        calc check { m > 0 [kg] }
    }

    part def Vehicle {
        attribute mass : MassValue;
        assert constraint positiveMass : 'Positive Mass' { in :>> m = mass; }
    }
    part brokenCar : Vehicle { attribute :>> mass = -1 [kg]; }
}
