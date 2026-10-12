package 'Mass Constraints' {
    private import ISQ::*;
    private import SI::*;

    constraint def 'Positive Mass' {
        in m : MassValue;
        m > 0 [kg]
    }

    part def Vehicle {
        attribute mass : MassValue;
        assert constraint positiveMass : 'Positive Mass' {
            in :>> m = mass;
        }
    }

    part car : Vehicle { attribute :>> mass = 1350.5 [kg]; }
    part brokenCar : Vehicle { attribute :>> mass = -1 [kg]; }
}
