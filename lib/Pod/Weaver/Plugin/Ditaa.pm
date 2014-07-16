package Pod::Weaver::Plugin::Ditaa;

# ABSTRACT: include ditaa diagrams in your pod

use Moose;
with 'Pod::Weaver::Role::Dialect';

sub translate_dialect {
   Pod::Elemental::Transformer::Ditaa->new->transform_node($_[1])
}

package Pod::Elemental::Transformer::Ditaa {

   use Moose;
   with 'Pod::Elemental::Transformer';

   use Capture::Tiny 'capture';
   use autodie;
   use File::Temp;
   use Syntax::Keyword::Junction 'any';
   use Moose::Autobox;
   use IPC::System::Simple 'system';
   use IO::All;
   use MIME::Base64;
   use namespace::clean;

   sub transform_node {
      my ($self, $node) = @_;
      my $children = $node->children;

    my $x = 0;

    PASS: for (my $i = 0 ; $i < $children->length ; $i++) {
         my $para = $children->[$i];
         next
           unless $para->isa('Pod::Elemental::Element::Pod5::Region')
           and !$para->is_pod
           and $para->format_name eq 'ditaa';

         my $length = $para->children->length;
         confess 'ditaa transformer expects exec region to contain 1 Data para'
           unless $length == 1
           and $para->children->[0]->isa('Pod::Elemental::Element::Pod5::Data');

         $x++;
         my $text = $para->children->[0]->content;

         my $new_doc = $self->_render_figure(
            figure => $x,
            text => $text,
            b64 => $self->_text_to_b64image($text),
         );

         splice @$children, $i, 1, $new_doc->children->flatten;
      }

      return $node;
   }

   sub _text_to_b64image {
      my ($self, $text) = @_;

      my $tmp_text = tmpnam();
      my $tmp_img  = tmpnam() . '.png';
      open my $fh, '>', $tmp_text;
      print {$fh} $text;
      close $fh;

      capture {
         system "ditaa -o $tmp_text $tmp_img";
      };
      my $image = encode_base64(io->file($tmp_img)->binary->all, '');
      unlink $tmp_text;
      unlink $tmp_img;

      return $image
   }

   sub _render_figure {
      my ($self, %args) = @_;

      my $new_doc = Pod::Elemental->read_string(
         "\n\n=begin text\n\nFigure $args{figure}\n\n" .
         "$args{text}\n\n=end text\n\n" .
          qq(\n\n=begin html\n\n) .
             qq(<p><i>Figure $args{figure}</i>) .
             qq(<img src="data:image/png;base64,$args{b64}"></img></p>\n\n) .
          qq(=end html\n\n)
      );
      Pod::Elemental::Transformer::Pod5->transform_node($new_doc);
      $new_doc->children->shift
        while $new_doc->children->[0]
        ->isa('Pod::Elemental::Element::Pod5::Nonpod');

      return $new_doc
   }

}

1;

__END__

=pod

=head1 SYNOPSIS

In your F<weaver.ini>:

 [@Default]
 [-Ditaa]

In the pod of one of your modules:

 =head1 HOW IT WORKS

 =begin ditaa

    +--------+   +-------+    +-------+
    |        | --+ ditaa +--> |       |
    |  Text  |   +-------+    |diagram|
    |Document|   |!magic!|    |       |
    |     {d}|   |       |    |       |
    +---+----+   +-------+    +-------+
        :                         ^
        |       Lots of work      |
        +-------------------------+

 =end ditaa

=head1 IN ACTION

=begin ditaa

   +--------+   +-------+    +-------+
   |        | --+ ditaa +--> |       |
   |  Text  |   +-------+    |diagram|
   |Document|   |!magic!|    |       |
   |     {d}|   |       |    |       |
   +---+----+   +-------+    +-------+
       :                         ^
       |       Lots of work      |
       +-------------------------+

=end ditaa

=head1 DESCRIPTION

It has often been said that a picture is worth a thousand words.  I find that
sometimes a diagram truly can illuminate your design.  This L<Pod::Weaver>
plugin allows you to put L<ditaa|http://ditaa.sourceforge.net/> diagrams in your
pod and render the image for an html view.  In text mode it merely uses the text
diagram directly.

=head1 PERL SUPPORT POLICY

Because this module is geared towards helping release code, as opposed to
helping run code, I only aim at supporting the last 3 releases of Perl.  So for
example, at the time of writing that would be 5.22, 5.20, and 5.18.  As an
author who is developing against Perl and using this to release modules, you can
use either L<perlbrew|http://perlbrew.pl/> or
L<plenv|https://github.com/tokuhirom/plenv> to get a more recent perl for
building releases.

Don't bother sending patches to support older versions; I could probably support
5.8 if I wanted, but this is more so that I can continue to use new perl
features.
