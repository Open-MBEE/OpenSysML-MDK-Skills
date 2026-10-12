package OperationsPerform {
    private import ScalarValues::Integer;

    part def Counter {
        attribute count : Integer = 0;
        perform action inc {
            in delta : Integer;
            assign count := count + delta;
        }
    }

    part def Controller {
        part c : Counter;
        action run {
            perform action a ::> c.inc { in :>> delta = 2; }
            then perform action b ::> c.inc { in :>> delta = 3; }
        }
    }

    part ctl : Controller;
}
