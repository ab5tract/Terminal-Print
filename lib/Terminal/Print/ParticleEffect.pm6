use Terminal::Print::Pixelated;


#| Pixelated particle effect base class
class Terminal::Print::ParticleEffect is Terminal::Print::PixelAnimation {
    has Real $.cell-height-ratio = 2e0;   #= Visual height / width ratio of each grid cell, used to correct pfx aspect
    has @.particles;

    #| OVERRIDE: Push new particles onto @.particles based on $dt (seconds since last frame)
    method generate-particles(Num $dt) { }

    #| OVERRIDE: Update all @.particles based on their new .<age> and $dt (seconds since last frame)
    method update-particles(Num $dt) { }

    #| Make existing particles older by $dt seconds
    method age-particles(Num $dt) {
        .<age> += $dt for @!particles;
    }

    #| Remove any particles that have outlasted their .<life>
    method gc-particles() {
        @!particles .= grep: { .<age> < .<life> }
    }

    #| Composite particles into pixels
    method composite-particles() {
        my $ratio = $.cell-height-ratio.Num;

        my @colors;
        for @!particles {
            next if .<x> < 0e0 || .<y> < 0e0;
            @colors[.<y> * 2e0][.<x> * $ratio] = .<color>;
        }

        @colors
    }

    #| Update particle effect and generate a single new frame of pixel data
    method compute-pixels() {
        my $dt = $.delta.time.Num;

        self.age-particles($dt);
        self.gc-particles;
        self.update-particles($dt);
        self.generate-particles($dt);
        self.composite-particles;
    }
}
