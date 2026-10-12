package 'Individual Without Individual Definition' {
    private import ISQ::*;
    private import SI::*;
    part def SEM { attribute mass : MassValue; }
    individual part sem1 : SEM { attribute :>> mass = 10 [kg]; }
}
