=head1 NAME

dTemplate - A powerful template handling logic with advanced features.

=head1 SYNOPSIS

  use dTemplate;

  $mail_template = define dTemplate "mail_tmpl.txt";# definition

  $mail = $mail_template->parse(                    # parsing
    TO      => "foo@bar.com",
    SUBJECT => $subject,
    BODY    => 
      sub { $email_type==3 ? $body_for_type_3 : $body_for_others },
    SIGNATURE=> $signature_template->parse( KEY => "value" )
  );

  print "Please send this mail: $mail";

  where mail_tmpl.txt is:

    From    : Me
    To      : $TO$
    Subject : $SUBJECT$

    Message body:
    $BODY$

    $SIGNATURE$

  # Advanced feature: Styling

  $style={lang =>'hungarian',color=>'white'};     # Style definition

  $html_template = choose dTemplate( $style,      # Selector definition
    'hungarian+white' => 
            define dTemplate("hun_white_template.html"),
    'spanish'         => 
            define dTemplate("spanish.html"),
    'black+hungarian' => 
            define dTemplate("hun_black_template.html"),
    'english'         => 
            define dTemplate("english_template.html"),
    'empty'           => 
      "<html>This is a text, $BODY$ is NOT substituted!!!!"</html>",
    ''                => 
            text dTemplate "<html>$BODY$</html>",  # default
  );

  $body_template= choose dTemplate( $style,       # Selector definition
    'hungarian'       => 
            define dTemplate("sziasztok_emberek.html"),
    'spanish'         => 
            define dTemplate("adios_amigos.html"),
    ''                => 
            define dTemplate("bye_bye.html"),
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

This module is aimed to be a simple, general-purpose, lightweight, 
but very powerful templating system.

You can write template-parsing routines in the way the templates are
structured logically. Starting from the biggest to the smallest.
Your program code will be very clear, structured and easy to understand.
This logic can be attained by using inline subroutines as values of template
variables. (Look at the example at the end of the document)

=head1 USAGE

First, you need to know how a template looks like, then you need to know how
to define a template in a perl program, then you can parse it.

After that you can see how to make new encoders.

=head2 How a template looks like

A template is a simple text file, which contains template variable placeholders.

The full format of a placeholder is:

  $Template_Variable%printf_style_format_string*encoder1*encoder2$

Where:

=over 4 

=item Template_Variable

It is a mandatory part of the placeholder. Can contain any (locale-aware) 
alphanumeric characters and '.' .

=item %printf_style_format_string

This is an optional part. Used when you want to format the output. You can
use as many '%' as you want, it can be good to pad the variable, for example
when you parse a table. E.g:  $MONEY%%%%%%011d$ is a valid placeholder.

=item *encoder

There are predefined encoders in the module, which can be used to format 
the input data.
These are:

  - u    : url-encoder
  - h    : HTML-encoder (converts > to &gt;, etc)
  - uc   : convert the string to uppercase
  - lc   : convert the string to lowercase

You can use zero or more of these:

  $TITLE*uc*h$

Read more on encoders (and how to make new encoders) in the Encoders part.

=back

=head2 Definition of a template

There are 3 ways to define a template.

=over 4

=item $template = define dTemplate $filename

This reads the template from a file.

=item $template = text dTemplate $scalar

This creates a template from a scalar

=item $template = choose dTemplate $hash, "style1" => $template1, "style2" => ...

It is the definition of the template chooser. It is the way how you can
create styled templates.

=back

=head2 Parsing

Parsing means substituting the variables which are defined in the template.
It can be done by simply calling the "parse" method of a dTemplate object.

The parameters of the "parse" method are the substitution definitions.

You can provide substitution parameters in two form: 

  - list of name => value pairs
  - with a hash reference

You can mix them if you want:

  $template->parse(
    name => $value,
    { name2 => $value2, name3 => $value3 },
    name4 => $value4,
    { name5 => $value5 },
    ...
  )

The "value" can be:

=over 4

=item scalar or scalar ref.

If a value is scalar, it will be substituted. Scalar refs can be used to save
some memory if you use them more than one time.

=item code reference ( sub { }, or \&subroutine )

The sub will be evaluated at each occurence of the template variable.

=item hash

You can assign a hash to a template variable if you want.
In this way, you can use structured data in the
templates, e.g you assign a { name => "Greg", "zip" => 111 } to the template
variable "person", and if you use "person.name" in the template, you will
get "Greg" back. Nesting (more "."-s) will also work.

=back

You can use %dTemplate::parse hash to assign global parse parameters.

The return value of the parse method is a dTemplate::Scalar object, which can
be used as a simple scalar, but really it is a scalar reference to save some
memory. It is useful if you use large templates.

=head2 Encoders

The global hash, %dTemplate::ENCODERS contains the defined encoders.

The hash keys are the names, the values are subroutine references. These subs
get the encodable data as the first parameter and returns the encoded value.

=head2 $dTemplate::parse{''}

$dTemplate::parse{''} is a special hash key in the %dTemplate::parse hash. 
This value is parsed into the place of the unassigned variable.

By default, it is an empty scalar, so you won't even notice if you forget to
assign a variable.

If you want to be warned if a variable is not assigned, you can use the
following code reference:

  use Carp qw(cluck);
  $dTemplate::parse{''} = sub {
      cluck "$_[0] is not assigned";
      return "";
  }

By this, the output of the further "parse" calls will call this sub if a
variable is not assigned.

=head2 Magical (tied) hashes

You can use magical hashes everywhere in the "parse" method parameter list, 
where you can to use normal hashes, but because I redesign the "parse" method 
with the speed with the first priority, it works quite a bit different than
the older ( <= 2.0 ) versions. 

At template-compile time, the "compile" method collects the variable names, 
which are found in that template, and the "parse" method knows which 
variables are required for processing this template.

When the "parse" method realizes that the given parameter is a hash reference, 
then it always tries all the remaining template variables (which are not 
assigned in the preceding part of the parameter list) in that hash reference.

Imagine the following situation:

  $template->parse( name => "blow", \%hash);

... where %hash is a magical hash, and the $template contains the "name",
"address" and "method.type" variables. When the parse method meets with the
\%hash, the "name" is already assigned, so it olny tries to read the
$hash{address} and $hash{method} variables.

This is not a problem with normal hashes, but if you use magical hashes, you
may have a very expensive FETCH function, and this effect can cause problems.

There are two way to work around it:

=over 4

=item *

Use qualified variable names. If you use the following form of parse:

  $template->parse( name => "blow", data => \%hash);

... then the %hash is called only when the template parser finds the
"data.address" and "data.method.type" variable references in the template. Of
course, you have to change the template variable names also.

=item *

Use the hash instead of a hash reference:

  $template->parse( name => "blow", %hash);

In this case, the magical hash is iterated through when the parameter list
is assembled. This is better only if you are afraid of random
key retrieval, but it can be also slow, if the FIRSTKEY, NEXTKEY and FETCH
operations are slow.

But if the random-key retrieval is not a problem for your magical hash, 
then use the default form instead of this, because that requires less
operation (only one FETCH).

=back

=head1 HINTS

=over 4

=item *

In the first parse of every template, the templates will be compiled. 
It is used to speed up parsing.

=item *

Don't forget that %dTemplate::parse can be localized. This means you can 
define local-only variable assignments in a subroutine:

  local %dTemplate::parse=( 
    %dTemplate::parse, 
    local_name => $value 
  );

=item *

You don't need to use text as the input value of an encoder, you can
use any scalar, even referenes! If you want (for example) print a date by a 
date encoder, which
expects the date to be an array ref of [ year, month, day ], then you can do
this, e.g:

   $dTemplate::ENCODERS{date}=sub {
     return "" if ref($_[0]) ne 'ARRAY';
     return $_[0]->[0]."-".$_[0]->[1]."-".$_[0]->[2];
   }

Then, when you put $START_DATE*date$ to a template, you can parse this template:

  $template->parse(
    START_DATE => [2000,11,13],
    ...
  );

=back

=head1 ALL-IN-ONE EXAMPLE

It is an example, which contains most of the features this module has. It is not
intended to be a real-world example, but it can show the usage of this module.

This example consists of one program, and some template modules.

The executable version of this program can be found in the example
directory of the module distribution.

  use dTemplate;

  ### definition of the standard templates

  my @TEMPLATE_LIST=qw(page table_row table_cell);
  my $templates={};
  foreach my $template (@TEMPLATE_LIST) {
    $templates->{$template} = 
      define dTemplate("templates/$template.htm");
  }

  ### definition of the styled templates (styles = languages)

  my @STYLES=qw(eng hun);
  my @STYLED_TEMPLATE_LIST=qw(table_title);

  my $style_select={ lang => 'hun' }; 

  foreach my $template (@STYLED_TEMPLATE_LIST) {
    my @array=();
    foreach my $style (@STYLES) {
      push @array, $style => 
        define dTemplate("text/$style/$template.txt");
    }
    $templates->{$template} = 
      choose dTemplate $style_select, @array;
  }

  ### setting up input data

  my $table_to_print=[
    [ "Buwam",   3, 6, 9 ],
    [ "Greg",    8, 4, 2 ],
    [ "You're",  8, 3, 4 ],
    [ "HTML chars: <>", 3],
  ];

  ### setting up the global parse hash with parse parameters;

  $dTemplate::parse{PAGENO}=7;

  ### settings up a hash with personal data.

  my $person_hash={
    name => { first_name => "Greg" },
    zip  => "9971",
  };

  ### this hash is simply added to other parse parameters

  my $parse_hash={
    "unknown" => { data => 157 },
  };

  ### the main page parse routine

  print $templates->{page}->parse(
    TABLE_TITLE =>             # name => value pair
      $templates->{table_title}->parse(),
    TABLE => sub {             # name => value pair. value is a sub
      my $ret="";
      foreach my $row (@$table_to_print) {
        $ret .= $templates->{table_row}->parse(
          BODY => sub {
            my $ret="";
            foreach my $cell (@$row) {
              $ret .= $templates->{table_cell}->parse(
                TEXT => $cell,
              )
            }
            return $ret;
          }
        )
      }
      return $ret;
    },
    "person" => $person_hash,  # name => value pair. value is a href
    $parse_hash,               # only a hash with parse parameters
  );

And the templates:

=over 4

=item templates/page.htm:

  <html>
  <body>

  <h1>$TABLE_TITLE*h$</h1>

  <table>
  $TABLE$
  </table>

  <br>
  Person name: $person.name*h$, zip code: $person.zip*h$
  <br>

  Unknown data: $unknown.data*h$
  <br>

  Page: $PAGENO%02d*h$

  </body>
  </html>

=item templates/table_row.htm:

  <tr>$BODY$</tr>

=item templates/table_cell.htm:

  <td>$TEXT*h$</td>

=item text/eng/table_title.txt:

  Table 1

=item text/hun/table_title.txt:

  1. táblázat

=back

=head1 COPYRIGHT

Copyrigh (c) 2000-2001 Szabó, Balázs (dLux)

All rights reserved. This program is free software; you can redistribute it 
and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

dLux (Szabó, Balázs) <dlux@kapu.hu>

=head1 SEE ALSO

perl(1), HTML::Template, Text::Template, CGI::FastTemplate, Template.

=cut

package dTemplate;
use strict;
use DynaLoader;
use vars qw($VERSION @ISA %ENCODERS %parse);

@ISA = qw(DynaLoader);

$VERSION = '2.1.1';
dTemplate->bootstrap($VERSION);

# Constructors ...

sub define { my $obj=shift; ((ref($obj) || $obj)."::Template")->new(@_); };
sub choose { my $obj=shift; ((ref($obj) || $obj)."::Choose")->new(@_); };
*select=*choose;
sub text   { my $obj=shift; ((ref($obj) || $obj)."::Template")->new_raw(@_); };
sub encode { 
  my $encoder=shift();
  return $ENCODERS{$encoder}->(shift());
};

$parse{''} = sub { shift };

package dTemplate::Template;
use strict;
use vars qw(%ENCODERS $ENCODERS);
use locale;

$ENCODERS{''}   = sub { shift() };

sub spf {
    my $format = shift;
    return sprintf $format,@_;
}

$ENCODERS{u}  = sub { 
    require URI::Escape;     # autoload URI::Escape module
    $ENCODERS{u} = sub {
        URI::Escape::uri_escape($_[0]||"","^a-zA-Z0-9_.!~*'()"); 
    };
    $ENCODERS{u}->(shift);
};

$ENCODERS{h} = sub { 
    require HTML::Entities;  # autoload HTML::Entities module
    $ENCODERS{h}=sub {
        HTML::Entities::encode($_[0]||"","^\n\t !\#\$%-;=?-~") ; 
    };
    $ENCODERS{h}->(shift);
};

$ENCODERS{uc} = sub { uc($_[0]) };

$ENCODERS{lc} = sub { lc($_[0]) };

$ENCODERS{ha} = sub { # Advanced html encoding: \n => <BR> , tabs => spaces
    my $e=$ENCODERS->{'h'}->($_[0]);
    $e =~ s/\n/<BR>/g;
    $e =~ s/\t/&nbsp;&nbsp;&nbsp;/go;
    $e;
};

$ENCODERS=\%ENCODERS; # for compatibility of older versions

*dTemplate::ENCODERS = *ENCODERS;

sub filename { 0; };
sub text     { 1; };
sub compiled { 2; };

sub new { my ($class,$filename)=@_;
  return undef if ! -r $filename;
  my $s=[$filename];
  bless ($s,$class);
};

sub new_raw { my $class=shift;
  my $txt=shift;
  my $s=[undef, ref($txt) ? $txt : \$txt];
  bless ($s,$class);
};

sub style  { return undef };

sub compile { my $s=shift;
    return if $s->[compiled];
    $s->load_file;

    # template parsing 

    my %varhash;
    my @comp=({});
    ${ $s->[text] } =~ s{ (.*?) ( 
        \$ ( [\w\.]* ) ( %+ (.*?[\w]) )? ( \*(.*?) )? \$ | $ 
    ) }{
        my ($pre,$full_matched,$varname,$full_format,$format,
            $full_encoding,$encoding) = ($1,$2,$3,$4,$5,$6,$7);
        my $clast = $comp[-1] ||= {};
        if ($full_matched eq '$$') { # $$ sign
            $clast->{text} .= $pre.'$';
        } else {
            $clast->{text} .= $pre;
            if ($varname) {
                $clast->{full_matched} = $full_matched;
                my ($varn, @varp) = split (/\./, $varname);
                $clast->{varn} = $varn;
                $varhash{$varn}++;
                $clast->{varp} = \@varp;
                $clast->{format} = defined $format ? "%".$format : "";
                $clast->{encoding}=$encoding;
                push @comp,{};
            };
        };
        "";
    }gxsce;

    # assigning ID-s for variables

    my @variables = sort { 
        $varhash{$b} <=> $varhash{$a} || length($a) <=> length($b) 
    } keys %varhash;
    my %varids;
    for (my $i=0; $i<@variables; $i++) {
        $varids{$variables[$i]} = $i;
    }

    # settings up the compiled scalar:
    # variable parameter hash + inverted index

    my ($var_list, $var_index) = ("","");
    foreach my $varname (@variables) {
        my $varlen = length($varname);
        my $addspc = $varlen >= 4 ? 0 : 4 - $varlen;
        my $var_list_add = " ".$varname.(" " x $addspc);
        $var_list  .= $var_list_add;
        my $var_index_add = "\0" x length($var_list_add);
        substr($var_index_add,0,4) = pack("L", $varids{$varname});
        $var_index .= $var_index_add;
    }
    my $compiled = pack("L",scalar(@variables)). $var_list. " \0". $var_index."";

    # chunks

    foreach my $chunk (@comp) {
        $compiled .= pack("L", length($chunk->{text})).$chunk->{text};
        if ($chunk->{full_matched}) {
            $compiled .= $chunk->{full_matched}."\0". # full matched string
                pack("L",$varids{ $chunk->{varn} }).  # variable ID
                join("",map { $_."\0" } @{ $chunk->{varp}})."\0". 
                                                      # variable path in hash
                join("",map { $_."\0" } (split(/\*+/, $chunk->{encoding} || "")))."\0".
                                                      # encoding
                $chunk->{format}."\0"

        } else {
            $compiled .= "\0";
        }
    }

    $s->[compiled] = $compiled;
    $s->[text]=undef; # free up some memory
};

sub load_file { my $s=shift;
  return if $s->[compiled] || defined $s->[text] || !defined $s->[filename];
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

package dTemplate::Choose;
use strict;

sub style_hash { 0 };
sub styles     { 1 };

sub new { my $class=shift;
  my $s=[shift,{}];
  bless($s,$class);
  $s->add(@_);
  $s;
};

sub add { my $s=shift;
  while (@_) {
    my $a=shift;
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
  return undef if !$s->[styles];
  my @walk=([ $s->[styles] ]);
  my @svals = sort (grep ( { $_ } values %{ $s->[style_hash] } ));
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

1;

