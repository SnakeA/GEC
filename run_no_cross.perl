#!/usr/bin/perl

use strict;
use Getopt::Long;
use Parallel::ForkManager;
use File::Spec;
use File::Basename;
use YAML::XS 'LoadFile';

my $PID = $$;
$SIG{TERM} = $SIG{INT} = $SIG{QUIT} = sub { die; };

###############################################################################
# Load configuration file

my $CONFIG_FILE = undef;
my $DIR         = undef;

GetOptions(
    "f|config=s"   => \$CONFIG_FILE,
    "d|work-dir=s" => \$DIR
);

die "Specify configuration file with -f/--config option.\n"
    unless $CONFIG_FILE;
my $CONFIG = LoadFile($CONFIG_FILE);

###############################################################################
# Set up options

# experiment
$DIR = $CONFIG->{experiment}->{dir} unless $DIR;
my $CROSS = 1;
my $N     = 1;
my $JOBS  = 4;
my $PARTS = 1;

die "Specify the working directory\n" unless $DIR;

# features
my $LM      = $CONFIG->{features}->{lm};
my $WCLM    = $CONFIG->{features}->{wclm};
my $OSM     = $CONFIG->{features}->{osm};
my $ESM     = $CONFIG->{features}->{esm};
my $EDITOPS = $CONFIG->{features}->{editops};
my $SPARSE  = $CONFIG->{features}->{sparse};
my $SPARSEOPT
    = "CorrectionPattern factor=0 context=1 context-factor=1\nCorrectionPattern factor=1";
my $WCINPUT = !!$SPARSE;

# data
my $M2           = $CONFIG->{data}->{train_m2};
my $TEST2013     = $CONFIG->{data}->{test2013_m2};
my $TEST2014     = $CONFIG->{data}->{test2014_m2};
my @MORE         = $CONFIG->{data}->{more_txt};
my @MORE_RELEASE = @MORE;

die "Specify the annotated training data in M2 format\n"
    if ( not $M2 or not -e $M2 );

my $PATH_LM     = $CONFIG->{data}->{lm_path};
my $PATH_WCLM   = $CONFIG->{data}->{wclm_path};
my $PATH_WC     = $CONFIG->{data}->{wc_path};
my $TRUECASE_LM = $CONFIG->{data}->{tc_lm};

# tuning
my $ALGORITHM   = $CONFIG->{tuning}->{algorithm};
my $PRO         = $ALGORITHM eq 'pro';
my $PROSTART    = $ALGORITHM eq 'prostart';
my $KBMIRASTART = $ALGORITHM eq 'kbmirastart';
my $BMIRA       = $ALGORITHM eq 'bmira';
my $REMERT      = $CONFIG->{tuning}->{remert} || 2;
my $MER_ADJUST  = 0.15;
my $MAXIT       = $CONFIG->{tuning}->{max_it} || 5;
my $BLEU        = 0;
my $MERT_JOBS   = $CONFIG->{tuning}->{mert_jobs} || $JOBS;

# constants
my $BETA             = 0.5;
my $FACTOR_DELIMITER = '|';
my $CONTINUE         = 0;
my $CLEAN            = 0;

# paths
my $ROOT         = $CONFIG->{root};
my $SCRIPTS      = "$ROOT/scripts";
my $MOSESDIR     = $CONFIG->{dir}->{moses};
my $MOSESDECODER = "$MOSESDIR/bin/moses";
my $PARALLEL     = "parallel --no-notice --pipe -k -j 4 --block 1M perl";
my $LAZYDIR      = $CONFIG->{dir}->{lazy};
my $TRUECASE
    = "$PARALLEL $SCRIPTS/case_graph.perl --lm $TRUECASE_LM --decode $LAZYDIR/bin/decode";

die "Set up the root directory\n" if ( not $ROOT     or not -e $ROOT );
die "Set up the path to Moses\n"  if ( not $MOSESDIR or not -e $MOSESDIR );
die "Set up the path to Lazy decoder\n"
    if ( not $LAZYDIR or not -e $LAZYDIR );

my $WC_FACT = "";
$WC_FACT = " | perl $SCRIPTS/anottext.pl -f $PATH_WC" if $WCINPUT;

###############################################################################
# Set options for train_smt.pl

my $TRAIN_OPTIONS = " --delimiter '$FACTOR_DELIMITER'";

$TRAIN_OPTIONS .= " --moses-dir $MOSESDIR";
$TRAIN_OPTIONS .= " --bin-dir " . $CONFIG->{dir}->{moses_bin};
$TRAIN_OPTIONS .= " --scripts-dir $SCRIPTS";
$TRAIN_OPTIONS .= " --srilm-dir " . $CONFIG->{dir}->{srilm};

$TRAIN_OPTIONS .= " --editops"         if ($EDITOPS);
$TRAIN_OPTIONS .= " --lm $PATH_LM"     if ($LM);
$TRAIN_OPTIONS .= " --wclm $PATH_WCLM" if ($WCLM);
$TRAIN_OPTIONS .= " --wc $PATH_WC"     if ($WCLM);
$TRAIN_OPTIONS .= " --osm"             if ($OSM);
$TRAIN_OPTIONS .= " --esm"             if ($ESM);

###############################################################################
# Create working directory

$DIR = File::Spec->rel2abs($DIR);
`mkdir -p $DIR`;

# Copy configuration file
`cp $CONFIG_FILE $DIR/config.yml`;

###############################################################################
# Prepare data

message("Converting tokenization in M2 file");
my $M2_MOSESTOK = "$DIR/" . basename($M2) . ".mosestok";
if ( not -s $M2_MOSESTOK ) {
    `$SCRIPTS/m2_tok/convert_m2_tok.py -m $MOSESDIR $M2 > $M2_MOSESTOK`;
}

message('Preparing training data set');
if ($CLEAN) {
    `cat $M2_MOSESTOK | $SCRIPTS/make_parallel.perl > $DIR/full.raw.txt`
        unless ( -s "$DIR/full.raw.txt" );

    unless ( -s "$DIR/full.txt" ) {
        message("Cleaning training data set");
        `cut -f1 $DIR/full.raw.txt > $DIR/full.raw.err`;
        `cut -f2 $DIR/full.raw.txt > $DIR/full.raw.cor`;
        `$MOSESDIR/scripts/training/clean-corpus-n.perl $DIR/full.raw err cor $DIR/full.clean 2 300`;
        `paste $DIR/full.clean.err $DIR/full.clean.cor > $DIR/full.txt`;
    }
}
else {
    `cat $M2_MOSESTOK | $SCRIPTS/make_parallel.perl > $DIR/full.txt`    unless ( -s "$DIR/full.txt" );
    `cat $M2 | $SCRIPTS/make_parallel.perl > $DIR/full.orig.txt`        unless ( -s "$DIR/full.orig.txt" );
}

if ($CROSS) {
    message("Splitting training data set into N-chunks");
    unless ( -s "$DIR/part.00" and -s "DIR/part." . sprintf( "%02d", $N ) ) {
        my $lines = int( `wc -l $DIR/full.txt` / $N ) ;
        print $lines, "\n";
        `split -a 2 -d -l $lines $DIR/full.txt $DIR/part.`;
        `split -a 2 -d -l $lines $DIR/full.orig.txt $DIR/part.orig.`;
    }

    my $pm = new Parallel::ForkManager($JOBS);

    foreach my $i ( 0 .. $N - 1 ) {
        $pm->start() and next;

        message("Preparing data for chunk $i");
        my $i0 = sprintf( "%02d", $i );
        my $curr = "$DIR/cross.$i0";

        exit(0) if ( -s "$curr/work.err-cor/binmodel.err-cor/moses.ini" );

        `mkdir -p $curr`;
        `> $curr/train.txt`;    # Clear once;

        foreach my $j ( 0 .. $N - 1 ) {
            my $j0 = sprintf( "%02d", $j );
            if ( $j != $i ) {
                `cat $DIR/part.$j0 >> $curr/train.txt`;
            }
            else {
                `cp $DIR/part.$j0 $curr/test.txt`           unless ( -e "$curr/test.txt" );
                `cp $DIR/part.orig.$j0 $curr/test.orig.txt` unless ( -e "$curr/test.orig.txt" );

                my $lines = int( `wc -l $curr/test.txt` / $PARTS ) + 1;
                message("Lines in part.$j0: $lines\n");
                `split -a 1 -d -l $lines $curr/test.txt $curr/test.`;
                `split -a 1 -d -l $lines $curr/test.orig.txt $curr/test.orig.`;

                foreach my $k ( 0 .. $PARTS - 1 ) {
                    `cat $curr/test.$k | cut -f 1 | tee $curr/test.$k.err | $TRUECASE > $curr/test.lc.$k.err`
                        unless ( -e "$curr/test.lc.$k.err" );
                    `cat $curr/test.$k | cut -f 2 | tee $curr/test.$k.cor | $TRUECASE > $curr/test.lc.$k.cor`
                        unless ( -e "$curr/test.lc.$k.cor" );
                    `cat $curr/test.orig.$k | cut -f 1 > $curr/test.orig.$k.err`
                        unless ( -e "$curr/test.orig.$k.err" );

                    `cat $curr/test.lc.$k.err | $SCRIPTS/ann_from_txt.perl $M2_MOSESTOK > $curr/test.lc.$k.m2`
                        unless ( -e "$curr/test.lc.$k.m2" );
                    `cat $curr/test.orig.$k.err | $SCRIPTS/ann_from_txt.perl $M2 > $curr/test.$k.m2`
                        unless ( -e "$curr/test.$k.m2" );
                }
            }
        }

        `cat $curr/test.?.err > $curr/test.err`;
        `cat $curr/test.lc.?.err > $curr/test.lc.err`;

        # foreach my $MORE (@MORE) {
        #     message("Adding more training data: $MORE");
        #     die if not( -s $MORE );
        #     `cat $MORE >> $curr/train.txt`;
        # }
        execute("cat $curr/train.txt | cut -f 1 | perl -pe 's/^\\s+|\\s+\$//g; \$_ = \"\$_\\n\"' | tee $curr/train.err | $TRUECASE > $curr/train.lc.err")
            unless ( -e "$curr/train.lc.err" );
        execute("cat $curr/train.txt | cut -f 2 | perl -pe 's/^\\s+|\\s+\$//g; \$_ = \"\$_\\n\"' | tee $curr/train.cor | $TRUECASE > $curr/train.lc.cor")
            unless ( -e "$curr/train.lc.cor" );
        execute("cp $curr/train.lc.cor $curr/train.lc.cor.lm");

        if ( not -s "$curr/work.err-cor/binmodel.err-cor/moses.ini" ) {
            message("Running translation model training for chunk $i");

            my $train_model
                = "$ROOT/train_smt.perl $TRAIN_OPTIONS"
                . " --filter $curr/test.lc.err"
                . " --lm-data $curr/train.lc.cor.lm"
                . " -w $curr/work.err-cor"
                . " -c $curr/train.lc"
                . " --log $curr/log.txt";
            execute($train_model);

            if ($SPARSE) {
                my $abscurr = File::Spec->rel2abs($curr);
                add_sparse("$abscurr/work.err-cor/binmodel.err-cor/moses.ini");
            }
        }

        $pm->finish();
    }
    $pm->wait_all_children();
}
###############################################################################
# Helper functions

sub prepare_test_set {
    my $name = shift;
    my $data = shift;
    my $dir  = shift;

    # create the filtered test file with original tokenization for evaluation
    `cat $data | $SCRIPTS/make_parallel.perl > $dir/$name.txt`;
    `cat $dir/$name.txt | cut -f 1 | $SCRIPTS/ann_from_txt.perl $data > $dir/$name.m2`;
    `cat $dir/$name.txt | cut -f 1 > $dir/$name.orig.err`;

    # create the .err and .lc.err files for translation
    `$SCRIPTS/m2_tok/convert_m2_tok.py -m $MOSESDIR $data > $dir/$name.m2.mosestok`
        if not -s "$dir/$name.m2.mosestok";
    `cat $dir/$name.m2.mosestok | $SCRIPTS/make_parallel.perl > $dir/$name.txt.mosestok`
        if not -s "$dir/$name.txt.mosestok";
    `cat $dir/$name.txt.mosestok | cut -f 1 | tee $dir/$name.err | $TRUECASE > $dir/$name.lc.err`
        if not -s "$dir/$name.lc.err";
    `cat $dir/$name.txt.mosestok | cut -f 2 | tee $dir/$name.cor | $TRUECASE > $dir/$name.lc.cor`
        if not -s "$dir/$name.lc.cor";
}

sub add_sparse {
    my $ini        = shift;
    my $weightFile = shift;

    message("Adding sparse features to $ini");

    open( INI, "<", $ini ) or die "Could not open $ini\n";
    my @lines = <INI>;
    close(INI);

    open( INI, ">", $ini ) or die "Could not open $ini\n";
    my $c = 0;
    foreach my $line (@lines) {
        print INI $line;
        if ( $WCINPUT and $line =~ /\[input-factors\]/ ) {
            $lines[ $c + 1 ] = "0\n1\n";
        }

        if ( $line =~ /\[feature\]/ ) {
            if ($SPARSE) {
                print INI join( "\n", split( /\\n/, $SPARSEOPT ) ), "\n";
            }
        }
        $c++;
    }

    if ($weightFile) {
        print INI "\n[weight-file]\n";
        print INI "$weightFile\n\n";
    }

    close(INI);
}

sub evaluate {
    my $description  = shift;
    my $text_file    = shift;
    my $reference_m2 = shift;
    my $eval_file    = shift;
    my $base_tok     = shift;

    if ($base_tok) {
        `cat $text_file | $MOSESDIR/scripts/tokenizer/deescape-special-chars.perl | $SCRIPTS/impose_tok.perl $base_tok > $text_file.nltk`
            unless ( -e "$text_file.nltk" );
        $text_file = "$text_file.nltk";
    }

    my $cmd
        = "python $SCRIPTS/m2scorer_fork"
        . " --beta $BETA"
        . " --max_unchanged_words 2"
        . " $text_file"
        . " $reference_m2";

    message("Evaluating '$description':\t$cmd");

    my $txt_lines = 0 + `wc -l $text_file`;
    my $m2_lines  = 0 + `grep -c "^S " $reference_m2`;

    if ( $txt_lines != $m2_lines ) {
        die("Evaluation stopped! Different number of lines: $txt_lines != $m2_lines");
    }

    `echo "$description" > $eval_file`;
    `$cmd >> $eval_file`;
}

sub translate_test_set {
    my $name        = shift;
    my $ini         = shift;
    my $infix       = shift;
    my $description = shift;

    if ( not -s "$RDIR/$name.trans.$infix" ) {
        my $cmd_translate
            = "cat $RDIR/$name.lc.err $WC_FACT | "
            . "$MOSESDECODER"
            . " -f $RDIR/work.err-cor/binmodel.err-cor/$ini -fd '$FACTOR_DELIMITER' -threads 16"
            . " -alignment-output-file $RDIR/$name.trans.$infix.aln"
            . " > $RDIR/$name.trans.$infix";
        execute($cmd_translate);
    }
    execute("cat $RDIR/$name.trans.$infix | $SCRIPTS/impose_case.perl $RDIR/$name.err $RDIR/$name.trans.$infix.aln > $RDIR/$name.trans.$infix.cased");
    evaluate(
        "# Evaluation of $name: $description ($ini)",
        "$RDIR/$name.trans.$infix.cased",
        "$RDIR/$name.m2",
        "$RDIR/eval.$name.$infix.txt",
        "$RDIR/$name.orig.err"
    );

}

sub execute {
    my $command = shift;

    message("Running command: $command");
    my $status = system($command);

    if ( $status != 0 ) {
        message("Command: $command\n\tfinished with non-zero status $status");
        kill( 2, $PID );
        die;
    }
}

sub message {
    my $message     = shift;
    my $time        = POSIX::strftime( "%m/%d/%Y %H:%M:%S", localtime() );
    my $log_message = $time . "\t$message\n";
    print STDERR $log_message;
}
