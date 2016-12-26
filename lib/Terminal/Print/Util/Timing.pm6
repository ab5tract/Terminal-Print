# ABSTRACT: White box timing / performance measurement utilities

# XXXX: API still in heavy flux!


unit module Terminal::Print::Util::Timing;


#| Multi-thread timing measurements
my @timings;
my $timings-supplier = Supplier.new;
my $timings-supply = $timings-supplier.Supply;
$timings-supply.act: { @timings.push: $^timing }


#| Keep track of timing measurements
sub record-time($desc, $start, $end = now) is export {
    $timings-supplier.emit: %( :$start, :$end, :delta($end - $start), :$desc,
                               :thread($*THREAD.id) );
}


#| Summarize all timings so far
sub summarize-timings() is export {
    my %by-desc;

    for @timings {
        %by-desc{.<desc>}<count>++;
        %by-desc{.<desc>}<total> += .<delta>;
    }

    %by-desc;
}


#| Show all timings so far
sub show-timings($verbosity) is export {
    return unless $verbosity >= 1;

    # Details of every timing
    if $verbosity >= 2 {
        my $raw-format = "%7.3f %7.3f %6d  %s\n";
        say '  START SECONDS THREAD  DESCRIPTION';
        printf $raw-format, .<start> - $*INITTIME, .<delta>, .<thread>, .<desc> for @timings;
        say '';
    }

    # Summary of timings by description, sorted by total time taken
    my $summary-format = "%6d %7.3f %7.3f  %s\n";
    say " COUNT   TOTAL AVERAGE  DESCRIPTION";
    for summarize-timings().sort(-*.value<total>) -> (:$key, :$value) {
        printf $summary-format, $value<count>, $value<total>,
                                $value<total> / $value<count>, $key;
    }
}
