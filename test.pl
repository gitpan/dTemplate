use Test;
BEGIN {
  plan tests => 16;
}

use dTemplate;

ok(1);

$t = text dTemplate '<html>$BODY$</html>';

ok(1);

# Testing a simple compile output

$t->compile;

my $test_compiled =
  # variables:
  pack("L",1)." BODY \0".pack("L",0)."\0".
  # first chunk (text)
  pack("L",6).'<html>'.
  # first chunk (variable)
  '$BODY$'."\0".pack("L",0)."\0\0\0".
  # second chunk (text)
  pack("L",7).'</html>'.
  # template end
  "\0";

ok $t->[dTemplate::Template::compiled], $test_compiled;

#open FILE,">test.out";
#print FILE $t->[dTemplate::Template::compiled];
#close FILE;
#open FILE,">test.out.exp";
#print FILE $test_compiled;
#close FILE;

$a = $t->parse( dummy => "123", BODY => "1111", dummm => "456");

ok($a, "<html>1111</html>");

$dTemplate::parse{BODY} = "Géza";

$b = $t->parse(fff => "333");

ok($b, "<html>Géza</html>");

$c = $t->parse( { BODY => "Abcdef", Bodrog => "Ahhh" });

ok($c, "<html>Abcdef</html>");

$t = text dTemplate '<html>$name******lc$<br>$code*uc$</html>';

$t->compile;

$a = $t->parse( name => "dLux" );

ok($a, '<html>dlux<br>$code*uc$</html>');

$b = $t->parse( name => "dLuxx", code => "dlx" );

ok($b, '<html>dluxx<br>DLX</html>');

$dTemplate::ENCODERS{reverse} = sub {
    join("", reverse split( //,$_[0]));
};

$dTemplate::ENCODERS{check_equal} = sub { my ($variable, $param) = @_;
    return $variable eq $param ? "true" : "false";
};

$t = text dTemplate 'Encodertest: $test*uc*reverse$';

$a = $t->parse( test => "Roxette" );

ok($a, 'Encodertest: ETTEXOR');

$t = text dTemplate 'Sprintftest: $data%05s*uc$';

$a = $t->parse( data => "hu" );

ok($a, 'Sprintftest: 000HU');

$t = text dTemplate 'Printf encoder test: $data*uc*printf/05s$';

$a = $t->parse( data => "uk" );

ok($a, 'Printf encoder test: 000UK');

$t = text dTemplate 'Hash test: $hash.key1*uc$ - $hash.key2.key3$';

$a = $t->parse( hash => { key1 => "bela", key2 => { key3 => "whooa" }});

ok($a, 'Hash test: BELA - whooa');

# test if magical hashes are working

use Tie::Hash;
tie %tied_hash, 'Tie::StdHash';

$tied_hash{key3} = "working!";

$x = bless ({ key1 => "tied hashes are", key2 => \%tied_hash }, "main" );

$b = $t->parse(hash => $x);

ok($b, 'Hash test: TIED HASHES ARE - working!');

$tied_hash{hash} = { key1 => "next test", key2 => { key3 => "ok" } };

$c = $t->parse( \%tied_hash );

ok($c, 'Hash test: NEXT TEST - ok');

# changing template placeholder special character

{
    local $dTemplate::START_DELIMITER     =  '<%\s*';
    local $dTemplate::VAR_PATH_SEP        =  '\/';
    local $dTemplate::ENCODER_PARAM_START = '\(';
    local $dTemplate::ENCODER_PARAM_END   = '\)';
    local $dTemplate::END_DELIMITER       =  '\s*%>';
    local $dTemplate::PRINTF_SEP          =  '\s*%%\s*';
    local $dTemplate::ENCODER_SEP         =  '\s*@\s*';
    $t3 = text dTemplate 'new template vars:<% text1/wow %% 6s @ lc %> Whoa! '.
        '<% text1/test @ check_equal(TEST!) %>';
    $t3->compile;
}

$a = $t3->parse(
    text1 => { wow => "WHO", test => "TEST!" },
);

ok($a,'new template vars:   who Whoa! true');

# recursion in template

$t = text dTemplate 'This is the frame of the internal template BEGIN ( $VAL$ ) END';

$t2 = text dTemplate 'internal data: $number$';

$a = $t->parse(
    VAL => sub {
        $t2->parse( number => 156 );
    }
);

ok($a,'This is the frame of the internal template BEGIN ( internal data: 156 ) END');

