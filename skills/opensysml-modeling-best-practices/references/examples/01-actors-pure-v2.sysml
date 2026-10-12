package 'Pure v2 Use Cases' {
    part def Operator;
    part def Instrument;

    use case def 'Acquire Image' {
        subject instrument : Instrument;
        actor operator : Operator;
        actor attendant [0..1] : Operator;
    }

    use case def 'Run Session' {
        subject instrument : Instrument;
        actor operator : Operator;
        include use case acquire : 'Acquire Image' {
            subject :>> instrument = 'Run Session'::instrument;
            actor :>> operator = 'Run Session'::operator;
        }
    }
}
