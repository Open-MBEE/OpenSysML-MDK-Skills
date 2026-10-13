package Instances {
    private import ISQ::*;
    private import SI::*;

    part def SEM { attribute mass : MassValue; }
    part def Calibrated;

    // One v1 instance specification: a usage typed by the classifier, slot values bound.
    part sem1 : SEM { attribute :>> mass = 10 [kg]; }

    // A multiply classified instance: one usage, several definitions.
    part sem2 : SEM, Calibrated { attribute :>> mass = 12 [kg]; }
}
