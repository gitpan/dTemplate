=head1 NAME

dTemplate - A powerful template handling logic with advanced features.

=head1 SYNOPSIS

  use dTemplate;

  $mail_template = define dTemplate "mail_tmpl.txt";# definition

  $mail = $mail_template->parse(                    # The parsing
    TO      => "foo@bar.com",
    SUBJECT => $subject,
    BODY    => 
      sub { $email_type==3 ? $body_for_type_3 : $body_for_others },
    SIGNATURE=> $signature_template->parse( KEY => "value" )
  );

  print "Please send this mail: $mail";

  # Advanced feature: Styling

  $style={lang =>'hungarian',color=>'white'};     # Style definition

  $html_template = select dTemplate( $style,      # Selector definition
    'hungarian+white' => define dTemplate("hun_white_template.html"),
    'spanish'         => define dTemplate("spanish.html"),
    'black+hungarian' => define dTemplate("hun_black_template.html"),
    'english'         => define dTemplate("english_template.html"),
    'empty'           => 
      "<html>This is a simple text $BODY$ is NOT substituted!!!!"</html>",
    ''                => scalar dTemplate "<html>$BODY$</html>",
  );

  $body_template= select dTemplate( $style,       # Selector definition
    'hungarian'       => define dTemplate("sziasztok_emberek.html"),
    'spanish'         => define dTemplate("adios_amigos.html"),
    ''                => define dTemplate("bye_bye.html"),
  );

  print $html_template->parse(BODY => $body_template->parse());
    # will print "sziasztok_emberek.html" in the
    #"hun_white_template.html"

  %$style=();
  print $html_template->parse(BODY => $body_template->parse());
    # will print "bye_bye.html" surrounded by "<html>" and "</html>" tags.

  %$style=( lang => 'english' );
  print $html_template->parse(BODY => $body_template->parse());
    # will print the "bye_bye.html" in of the "english_template.html"

=head1 DESCRIPTION

This module wants to be the most powerful general purpose templating system. It has a very clear and easy to learn syntax with the styling capabilities.

All you need to use this: put $TEMPLATE_VARIABLE$ into your dTemplates, define them, and parse them. (You can write $ signs as $$).

=head1 FEATURES

=over 4

=item *

General purpose templating. It can be used for texts or htmls, xmls, etc.

=item *

Straightforward logic. You can do all the templating in a logical order. Your program code will be very clear and easy to understand.

=item *

Special formatting of the variables before variable-substitution: printf-style formatting and encoding.

The format of the variable is $Variable_NAME%printf_format*encoding$

=over 4

=item Printf-Style formatting

You can use a printf formatting string in the Template variable name after the % sign, e.g: $ZIP_CODE%8s$

=item Encoding

You can use URI ('u') or HTML ('h') encoding of the data: <HREF="link.cgi?target=$TARGET_URL*u$">

=item Using Both

If you want to use both printf-style formatting and Encoding, you must use in the order as declared above, e.g:   $PERCENT_COMPLETE%07.3f*h$. The reverse order won't work!

=back 4

=item *

Formattable templates

=back 4

=head1 COPYRIGHT

Copyrigh (c) 2000 Szabó, Balázs (dLux)

All rights reserved. This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

dLux (Szabó, Balázs) <dlux@kapu.hu>

=head1 SEE ALSO

perl(1).

=cut

package dTemplate;
use strict;
use vars qw($VERSION);

$VERSION = '0.6';

# Constructors ...

sub define { my $obj=shift; ((ref($obj) || $obj)."::Template")->new(@_); };
sub select { my $obj=shift; ((ref($obj) || $obj)."::Select")->new(@_); };
sub text   { my $obj=shift; ((ref($obj) || $obj)."::Template")->new_raw(@_); };

package dTemplate::Template;
use strict;
use vars qw($ENCODERS);
use HTML::Entities;
use URI::Escape;

$ENCODERS={
  ''  => sub { shift() },
  'u' => sub { URI::Escape::uri_escape($_[0]||"","^a-zA-Z0-9_.!~*'()"); },
  'h' => sub { HTML::Entities::encode($_[0]||"","^\n\t !\#\$%-;=?-~") ; },
};

# Advanced html encoding: \n => <BR> , tabs => spaces
$ENCODERS->{'ha'}=sub {
  my $e=$ENCODERS->{'h'}->($_[0]);
  $e =~ s/\n/<BR>/g;
  $e =~ s/\t/&nbsp;&nbsp;&nbsp;/go;
  $e;
};

sub filename { 0; };
sub text     { 1; };
sub compiled { 2; };

sub new { my ($class,$filename)=@_;
  return undef if ! -r $filename;
  my $s=[$filename];
  bless ($s,$class);
};

sub new_raw { my $class=shift;
  my $s=[undef, shift];
  bless ($s,$class);
};

sub parse { my $s=shift;
  $s->compile;
  my $h= [{}];
  while (my $var_name=shift) {
    if (ref($var_name) eq 'HASH') {
      push @$h,$var_name;
      next;
    };
    $h->[0]->{$var_name}=shift || ""; # undef is not an option...
  };
  my $lookfor= sub { my ($key)=@_;
    return "" if !defined $key;
    for (my $i=0; $i<@$h; $i++) {
      return $h->[$i]->{$key} if exists $h->[$i]->{$key};
    };
    return undef;
  };
  my $ret;
  foreach my $var (@{ $s->[compiled] }) {
    # $var->[0]: text
    # $var->[1]: Original text of the variable substitution
    # $var->[2]: Variable name (or undef if last text)
    # $var->[3]: Formatting characters
    # $var->[4]: Encoding (h: html, u: url)
    my $val_got=$lookfor->($var->[2]);
    my $encoder;
    if (! ref($var->[4])) { # Only one encoder
      $encoder=$ENCODERS->{ $var->[4] } || $ENCODERS->{''};
    } else { # Multiple encoders!
      $encoder=sub { my $x=$_[0]; 
        foreach my $enc (@{$var->[4]}) {
          $x=$ENCODERS->{ $enc }->($x);
        };
      };
    };
    my $value= 
      ! defined $val_got                          ? $var->[1] :
      ref($val_got) eq 'CODE'                     ? $encoder->($val_got->()) :
      ref($val_got) eq 'SCALAR'                   ? $encoder->($$val_got) :
      do { my $r= $encoder->($val_got); ref($r) ? undef : $r };
      # Special case: hash ref, array ref can be passed to the encoder!
    $ret.=$var->[0].($var->[3]?sprintf("%".$var->[3],$value):$value);
  };
  return $ret;
#  return dTemplate::Scalar->new(\$ret);
};

sub style  { return undef };

sub compile { my $s=shift;
  return if $s->[compiled];
  $s->load_file;
  my $last_pos=0;
  my $compiled=$s->[compiled]=[[]];
  ${ $s->[text] } =~ s{ (.*?) ( 
      \$ ( [A-Za-z_0-9]* ) ( %+ (.*?[a-zA-Z]) )? ( \*(.*?) )? \$ | $ 
    ) }{
    my ($pre,$full_matched,$varname,$full_format,$format,
      $full_encoding,$encoding)=($1,$2,$3,$4,$5,$6,$7);
    if ($full_matched eq '$$') { # $$ sign
      $compiled->[-1]->[0].=$pre.'$';
    } else {;
      $compiled->[-1]->[0].=$pre;
      if ($varname) {
        $compiled->[-1]->[1]=$full_matched;
        $compiled->[-1]->[2]=$varname;
        $compiled->[-1]->[3]=$format;
        if ($encoding =~ /\*/) { $encoding=split(/\*+/,$encoding); };
        $compiled->[-1]->[4]=$encoding;
        push @$compiled,[];
      };
    };
    "";
  }gxsce;
};

sub load_file { my $s=shift;
  return if $s->[compiled] || $s->[text] || !defined $s->[filename];
  if (!open(FILE,$s->[filename])) {
    warn "Cannot load template file: ".$s->[filename];
    $s->[text]=\"";
    close (FILE);
    return;
  };
  local $/=undef;
  my $text=<FILE>;
  $s->[text]=\$text;
  close (FILE);
};

package dTemplate::Style;
use strict;

sub style_hash { [ 0 ] };
sub styles     { [ 1 ] };

sub new { my $class=shift;
  my $s=[shift,{}];
  bless($s,$class);
  $s->add(@_);
  $s;
};

sub add { my $s=shift;
  while (my $a=shift) {
    my $b=shift;
    $s->define_style($s->[styles], ref($b) ? $b : \$b ,sort split(/\+/,$a));
  };
  $s;
};

sub define_style { my ($s,$root,$template,@path)=@_;
  if (@path) {
    my $i=shift @path;
    $root->{$i}||={};
    $s->define_style($root->{$i},$template,@path);
  } else {
    $root->{''}=$template;
  };
};

sub parse { my $s=shift;
  my $template=$s->get_template;
  return defined $template ? $template->parse(@_) : undef;
};

sub style { my $s=shift; @_ ? $s->[style_hash]=$_[0] : $s->[style_hash] };

sub get_template { my ($s)=@_;
  my @walk=([ $s->[styles] ]);
  my @svals = sort grep ( { $_ } (values %{ $s->[styles] }));
  # Finds the best-matching template
  foreach my $i (@svals) {
    for (my $depth=$#walk; $depth>=0; $depth--) {
      foreach my $act (@{$walk[$depth]}) {
        push @{ $walk[$depth+1] }, $act->{$i}
          if exists $act->{$i};
      };
    };
  };
  my $retval;
  FINDTEMPLATE:
  for (my $depth=$#walk; $depth>=0; $depth--) {
    foreach my $act (@{$walk[$depth]}) {
      if (exists $act->{''}) {
        $retval=$act->{''};
        last FINDTEMPLATE;
      };
    };
  };
  return ref($retval) eq 'SCALAR' ? $$retval : $retval;
};

# package dTemplate::Scalar;

# sub new { bless ($_[1],ref($_[0]) || $_[0]); };

# sub stringify { $$_[0] };

# use overload '""' => \&stringify;

1;

