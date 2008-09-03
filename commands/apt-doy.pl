#!/usr/bin/perl
use strict;
use warnings;

do 'commands/helper.pl';
#help("Looks up aptitudes for specified race/skill combination.");

my %apts;

# build the skills/races db
# skills {{{
# skill list {{{
my @skills = (
    'fighting', 'short blades', 'long blades', 'axes', 'maces & flails',
    'polearms', 'staves', 'slings', 'bows', 'crossbows', 'darts', 'throwing',
    'armour', 'dodging', 'stealth', 'stabbing', 'shields', 'traps & doors',
    'unarmed combat', 'spellcasting', 'conjurations', 'enchantments',
    'summonings', 'necromancy', 'translocations', 'transmigration',
    'divinations', 'fire magic', 'ice magic', 'air magic', 'earth magic',
    'poison magic', 'invocations', 'evocations',
); # }}}
# skill names used by the code {{{
my %code_skills = map {
    my $s = $_;
    $s =~ s/[ &]+/_/g;
    ($_, "SK_" . uc $s)
} @skills;
# }}}
# short skills {{{
my %short_skills = map { ($_, ucfirst((split(' ', $_))[0])) } @skills;
$short_skills{'throwing'}       = 'Throw';
$short_skills{'dodging'}        = 'Dodge';
$short_skills{'stabbing'}       = 'Stab';
$short_skills{'conjurations'}   = 'Conj';
$short_skills{'enchantments'}   = 'Ench';
$short_skills{'summonings'}     = 'Summ';
$short_skills{'necromancy'}     = 'Nec';
$short_skills{'translocations'} = 'Tloc';
$short_skills{'transmigration'} = 'Tmig';
$short_skills{'divinations'}    = 'Div';
$short_skills{'invocations'}    = 'Inv';
$short_skills{'evocations'}     = 'Evo';
# }}}
# skill normalization {{{
my %normalize_skill = (
    (map { ($_, $_) } @skills),
    (map { lc } (reverse %code_skills)),
    (map { lc } (reverse %short_skills)),
    pois     => 'poison magic',
    flails   => 'maces & flails',
    invo     => 'invocations',
    necro    => 'necromancy',
    transmig => 'transmigrations',
    doors    => 'traps & doors',
); # }}}
sub normalize_skill { # {{{
    my $skill = shift;
    $skill = lc $skill;
    $skill =~ s/(?:^\s*|\s*$)//g;
    return $normalize_skill{$skill}
} # }}}
sub short_skill { # {{{
    my $skill = shift;
    $skill = normalize_skill $skill;
    return $short_skills{$skill};
} # }}}
sub code_skill { # {{{
    my $skill = shift;
    $skill = normalize_skill $skill;
    return $code_skills{$skill};
} # }}}
# }}}
# races {{{
# draconians {{{
my @drac_colors = qw/red white green yellow grey black purple mottled pale/;
# }}}
# race list {{{
my @races = (
    'human', 'high elf', 'grey elf', 'deep elf', 'sludge elf',
    'mountain dwarf', 'halfling', 'hill orc', 'kobold', 'mummy', 'naga',
    'gnome', 'ogre', 'troll', 'ogre mage',
    (map { "$_ draconian" } @drac_colors),
    'base draconian', 'centaur', 'demigod', 'spriggan', 'minotaur',
    'demonspawn', 'ghoul', 'kenku', 'merfolk', 'vampire',
);
# }}}
# race names used by the code {{{
my %code_races = map {
    my $r = $_;
    $r =~ tr/ /_/;
    ($_, "SP_" . uc $r)
} @races;
# }}}
# short race names {{{
my %short_races = map {
    my @r = split;
    ($_, @r == 1 ? ucfirst (substr $_, 0, 2) :
                   uc (substr $r[0], 0, 1) . uc (substr $r[1], 0, 1))
} @races;
$short_races{'demigod'}        = 'DG';
$short_races{'demonspawn'}     = 'DS';
$short_races{'merfolk'}        = 'Mf';
$short_races{'vampire'}        = 'Vp';
$short_races{'base draconian'} = 'Dr';
$short_races{"$_ draconian"}   = "Dr[$_]" for @drac_colors;
# }}}
# race normalization {{{
my %normalize_race = (
    (map { ($_, $_) } @races),
    (map { lc } (reverse %code_races)),
    (map { lc } (reverse %short_races)),
    'ogre-mage' => 'ogre mage',
    'draconian' => 'base draconian',
);
# }}}
sub normalize_race { # {{{
    my $race = shift;
    $race = lc $race;
    $race =~ s/(?:^\s*|\s*$)//g;
    return $normalize_race{$race}
} # }}}
sub short_race { # {{{
    my $race = shift;
    $race = normalize_race $race;
    return $short_races{$race};
} # }}}
sub code_race { # {{{
    my $race = shift;
    $race = normalize_race $race;
    return $code_races{$race};
} # }}}
# }}}

# helper functions
sub error { # {{{
    print @_, "\n";
    exit;
} # }}}
sub parse_apt_file { # {{{
    my %apts;
    open my $aptfile, '<', shift;
    my $race;
    while (<$aptfile>) {
        if (/{\s*\/\/\s*(\w+)/) {
            $race = normalize_race $1;
            die unless defined $race;
        }
        elsif (/^\s*(.*?),\s*\/\/\s*(\w+)/) {
            next if $2 eq 'undefined' || $2 eq 'SK_UNUSED_1';
            my $apt = eval $1;
            my $skill = normalize_skill $2;
            $apts{$race}{$skill} = $apt;
        }
    }
    return %apts;
} # }}}
sub strip_cmdline { # {{{
    my $cmdline = shift;
    $cmdline =~ s/^!\w+\s+//;
    chomp $cmdline;
    $cmdline = lc $cmdline;
    $cmdline = join(' ', split(' ', $cmdline));
    return $cmdline;
} # }}}
sub is_best_apt { # {{{
    my ($race, $skill) = @_;
    for (@races) {
        return 0 if $apts{$_}{$skill} < $apts{$race}{$skill};
    }
    return 1;
} # }}}
sub apt { # {{{
    my ($race, $skill) = @_;
    return $apts{$race}{$skill} . (is_best_apt($race, $skill) ? "!" : "");
} # }}}
sub check_long_option { # {{{
    my $word = shift;
    $word =~ /-?(.*?)=(.*)/;
    my ($option, $val) = ($1, $2);
    return unless defined $option && defined $val;

    if ((substr $option, 0, 2) eq 'so') {
        return ('sort', $val);
    }
    elsif ((substr $option, 0, 1) eq 's') {
        return ('skill', $val);
    }
    elsif ((substr $option, 0, 1) eq 'r') {
        return ('race', $val);
    }
    elsif ((substr $option, 0, 1) eq 'c') {
        return ('color', $val);
    }
    else {
        return;
    }
} # }}}
sub print_single_apt { # {{{
    my ($race, $skill) = @_;
    print short_race($race),
          " (", code_skill($skill), ")=",
          apt($race, $skill), "\n";
} # }}}
sub print_race_apt { # {{{
    my ($race, $sort) = @_;
    my @list = @skills;
    @list = sort @list if defined $sort && $sort eq 'alpha';
    my @out;
    for (@list) {
        push @out, (short_skill $_) . '=' . (apt $race, $_);
    }
    print short_race($race), ": ", join(', ', @out), "\n";
} # }}}
sub print_skill_apt { # {{{
    my ($skill, $sort) = @_;
    my @list = @races;
    @list = sort @list if defined $sort && $sort eq 'alpha';
    my @out;
    for (@list) {
        push @out, (short_race $_) . '=' . (apt $_, $skill);
    }
    print short_skill($skill), ": ", join(', ', @out), "\n";
} # }}}

# get the aptitudes out of the source file
%apts = parse_apt_file 'db.cc';
# get the request
my @words = split ' ', strip_cmdline $ARGV[2];
my @rest;

# loop over the words, checking for things we understand
my %opts;
while (@words) {
    my ($test, $option);

    ($option, $test) = check_long_option $words[0];
    if (defined $test) {
        error "$option already defined with $opts{$option}, but I got $test"
            if exists $opts{$option};
        $opts{$option} = $test;
        shift @words;
        next;
    }

    $test = normalize_race join ' ', @words;
    if (defined $test) {
        error "race already defined with $opts{race}, but I got $test"
            if exists $opts{race};
        $opts{race} = $test;
        @words = @rest;
        @rest = ();
        next;
    }

    $test = normalize_skill join ' ', @words;
    if (defined $test) {
        error "skill already defined with $opts{skill}, but I got $test"
            if exists $opts{skill};
        $opts{skill} = $test;
        @words = @rest;
        @rest = ();
        next;
    }

    unshift @rest, pop @words;
    if (@words == 0) {
        error "Could not understand \"$rest[0]\"";
    }
}

# check for validity of the color option
if (exists $opts{color}) {
    if (!defined $opts{race} || $opts{race} ne 'base draconian') {
        error "The color option is only valid for draconians";
    }
    $opts{race} = "$opts{color} draconian";
}

# print the result
if (exists $opts{race} && exists $opts{skill}) {
    print_single_apt $opts{race}, $opts{skill}, $opts{sort};
}
elsif (exists $opts{race}) {
    print_race_apt $opts{race}, $opts{sort};
}
elsif (exists $opts{skill}) {
    print_skill_apt $opts{skill}, $opts{sort};
}
else {
    error "You must provide at least a race or a skill";
}
