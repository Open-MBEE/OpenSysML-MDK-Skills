package OperationsActionDef {
    private import ScalarValues::Integer;

    part def Counter {
        attribute count : Integer = 0;
    }
    action def Inc {
        in target : Counter;
        in delta : Integer;
        assign target.count := target.count + delta;
    }

    part def Controller {
        part c : Counter;
        action run {
            action a : Inc { in :>> target = c; in :>> delta = 2; }
            then action b : Inc { in :>> target = c; in :>> delta = 3; }
        }
    }

    part ctl : Controller;
}
