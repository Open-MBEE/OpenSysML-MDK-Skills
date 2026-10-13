package Operations {
    private import ScalarValues::Integer;

    part def Counter {
        attribute count : Integer = 0;
        // The v1 operation `inc(delta)`: one performed action owned by the part definition.
        perform action inc {
            in delta : Integer;
            assign count := count + delta;
        }
    }

    part def Controller {
        part c : Counter;
        action run {
            // The caller joins the part's performed action instead of defining its own.
            action a : Counter::inc { in :>> delta = 2; }
            action b : Counter::inc { in :>> delta = 3; }
            first start then a; then b; then done;
        }
    }

    part ctl : Controller;
}
