use Terminal::Print;

class Coord {
    has Int $.x is rw where * <= T.columns = 0;
    has Int $.y is rw where * <= T.rows = 0 ;
}

class Snowflake {
    has $.flake = <❆ ❅ ❄>.roll;
    has $.pos = Coord.new;
}

sub create-flake {
    state @cols = ^T.columns .pick(*); # shuffled
    if +@cols > 0 {
        my $rand-x = @cols.pop;
        my $start-pos = Coord.new: x => $rand-x;
        return Snowflake.new: pos => $start-pos;
    } else {
        @cols = ^T.columns .pick(*);
        return create-flake;
    }
}

draw( -> $promise {

start {
    my @flakes = create-flake() xx T.columns;
    my @falling;

    Promise.at(now + 33).then: { $promise.keep };
    loop {
        # how fast is the snowfall?
        sleep 0.1;

        if (+@flakes) {
            # how heavy is the snowfall?
            my $limit = @flakes > 2 ?? 2
                                    !! +@flakes;
            # can include 0, but then *cannot* exclude $limit!
            @falling.push: |(@flakes.pop xx (0..$limit).roll);
        } else {
            @flakes = create-flake() xx T.columns;
        }

        for @falling.kv -> $idx, $flake {
            with $flake.pos.y -> $y {
                if $y > 0 {
                    T.print-cell: $flake.pos.x, ($flake.pos.y - 1), ' ';
                }

                if $y < T.rows {
                    T.print-cell: $flake.pos.x, $flake.pos.y, $flake.flake;
                }

                try {
                    $flake.pos.y += 1;
                    CATCH {
                        # the flake has fallen all the way
                        # remove it and carry on!
                        @falling.splice($idx,1,());
                        .resume;
                    }
                }
            }
        }
    }
}

});
